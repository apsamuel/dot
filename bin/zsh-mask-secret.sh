#!/usr/bin/env zsh
# shellcheck shell=bash
# shellcheck disable=SC2016,SC2039,SC2154,SC2296,SC2048,SC2086
#
# mask-secret.sh — secret masking and detection utility
#
# Two runtime modes when executed directly:
#   mask    Replace secret values with a safe-word in text from stdin, a file,
#           or positional arguments.  (default)
#   check   Exit 1 if secret values are detected; exit 0 if the input is clean.
#
# Two setup modes:
#   zle     Print sourceable ZSH code that hooks into ZLE, preexec, and
#           zshaddhistory to mask secrets in terminal display and shell history.
#           Usage:  source <(mask-secret.sh -Z)
#   hook    Install a git pre-commit hook that runs check mode on staged content,
#           preventing secrets from reaching a repository.
#           Usage:  mask-secret.sh -G <repo_path>
#
#% description: mask, detect, and prevent secrets in text, terminal, and git
#% usage:
#%   mask-secret.sh [options] [string ...]           mask / check positional args
#%   echo "text" | mask-secret.sh [options]          mask / check stdin
#%   mask-secret.sh -i <file> [options]              mask / check a file
#%   source <(mask-secret.sh -Z)                     activate ZLE + history hooks
#%   mask-secret.sh -G <repo_path>                   install git pre-commit hook
#%
#% modes (mutually exclusive):
#%   -m              mask mode — replace secrets with safe-word  (default)
#%   -c              check mode — exit 1 if secrets found, 0 if clean
#%   -Z              print sourceable ZSH ZLE integration to stdout
#%   -G <path>       install git pre-commit hook at <path>  (use . for cwd)
#%
#% input (mask / check modes):
#%   string ...      positional arguments processed line-by-line
#%   -i <file>       read input from file
#%   (stdin)         used when no args and no -i are given
#%
#% configuration:
#%   -f <file>       secrets JSON  (default: $MASK_SECRETS_FILE,
#%                   then $ICLOUD/dot/secrets.json)
#%   -w <word>       replacement token  (default: $MASK_SAFE_WORD,
#%                   then ***MASKED***)
#%   -x <w1,w2,...>  extra literal words to mask (comma-separated)
#%   -v              verbose — report matched pattern names on stderr
#%   -h              print this help
#%
#% environment:
#%   MASK_SECRETS_FILE   path to JSON secrets file
#%   MASK_SAFE_WORD      replacement token written in place of secrets
#%   ICLOUD              base path prefix for default secrets file
#%
#% secrets file format (flat JSON object, string values only):
#%   { "GITHUB_TOKEN": "ghp_...", "OPENAI_KEY": "sk-..." }
#%
#% examples:
#%   mask-secret.sh "my api key is ghp_xxxx"
#%   env | mask-secret.sh
#%   mask-secret.sh -i /var/log/app.log > /tmp/safe_log.txt
#%   mask-secret.sh -c -i report.txt && echo "file is clean"
#%   mask-secret.sh -G .                         # install pre-commit hook in cwd
#%   source <(mask-secret.sh -Z)                 # add hooks to current zsh session

set -uo pipefail

# ── constants ──────────────────────────────────────────────────────────────────
readonly _MASK_MIN_LEN=4    # skip secret values shorter than this (reduces false positives)
# Capture the real script path now — inside functions $0 becomes the function name.
# ${0:A} is zsh-specific: expand $0 to its absolute, symlink-resolved path.
readonly _MASK_SELF="${0:A}"

# ── runtime state (defaults) ──────────────────────────────────────────────────
_safe_word="${MASK_SAFE_WORD:-***MASKED***}"
_secrets_file="${MASK_SECRETS_FILE:-${ICLOUD:-$HOME}/dot/secrets.json}"
_mode="mask"            # mask | check | zle | hook
_input_file=""
_hook_path=""
_verbose=false
_extra_words=()
_input_args=()

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

info()  { printf '%b\n' "${CYAN}ℹ  $*${RESET}" >&2; }
ok()    { printf '%b\n' "${GREEN}✔  $*${RESET}" >&2; }
warn()  { printf '%b\n' "${YELLOW}⚠  $*${RESET}" >&2; }
fail()  { printf '%b\n' "${RED}✘  $*${RESET}" >&2; exit 1; }
vlog()  { [[ "$_verbose" == "true" ]] && printf '%b\n' "${DIM}   ▸ $*${RESET}" >&2 || true; }

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
    grep '^#%' "$_MASK_SELF" | sed 's/^#% \{0,1\}//'
    exit 0
}

# ── prerequisites ──────────────────────────────────────────────────────────────
check_prereqs() {
    local missing=()
    for cmd in jq python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing required tools: ${missing[*]}"
    fi
}

# ── load_secret_values ─────────────────────────────────────────────────────────
# Read a secrets JSON file and print one secret value per line.
# Values shorter than _MASK_MIN_LEN are skipped (reduces false positives).
load_secret_values() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        warn "Secrets file not found: ${file}"
        return 1
    fi
    jq -r --argjson minlen "$_MASK_MIN_LEN" \
        '.[] | select(type == "string" and length >= $minlen)' \
        "$file" 2>/dev/null
}

# ── build_secrets_raw ──────────────────────────────────────────────────────────
# Combine secrets from the JSON file and any extra words into a newline-
# separated string suitable for MASK_SECRETS_RAW.
build_secrets_raw() {
    local file="$1"; shift
    local -a extras=("$@")
    local values=""

    if [[ -f "$file" ]]; then
        values=$(load_secret_values "$file") || true
    fi

    local word
    for word in "${extras[@]}"; do
        [[ ${#word} -ge $_MASK_MIN_LEN ]] || continue
        values+=$'\n'"$word"
    done

    printf '%s' "$values"
}

# ── _run_python_masker ─────────────────────────────────────────────────────────
# Core masking engine.  Reads text from stdin and either:
#   - outputs masked text (MASK_CHECK_ONLY=0), or
#   - exits 1 silently if any secret is found (MASK_CHECK_ONLY=1).
#
# Secrets are passed via the environment (not argv) to avoid ps visibility.
# Uses python3 -c so stdin remains available for the data to be masked
# (a heredoc would consume stdin for the script itself, leaving no data to read).
# Required env vars: MASK_SAFE_WORD, MASK_SECRETS_RAW, MASK_CHECK_ONLY
_run_python_masker() {
    # shellcheck disable=SC2016
    python3 -c '
import sys, os

safe_word  = os.environ.get("MASK_SAFE_WORD", "***MASKED***")
raw        = os.environ.get("MASK_SECRETS_RAW", "")
check_only = os.environ.get("MASK_CHECK_ONLY", "0") == "1"
values     = [v for v in raw.split("\n") if v]

found = False
lines = []

for line in sys.stdin:
    masked = line
    for val in values:
        if val in masked:
            found  = True
            masked = masked.replace(val, safe_word)
    lines.append(masked)

if not check_only:
    sys.stdout.write("".join(lines))

sys.exit(1 if (check_only and found) else 0)
'
}

# ── _dispatch_input ────────────────────────────────────────────────────────────
# Route input to _run_python_masker from a file, positional args, or stdin.
# Callers must have MASK_SAFE_WORD, MASK_SECRETS_RAW, MASK_CHECK_ONLY exported.
_dispatch_input() {
    if [[ -n "$_input_file" ]]; then
        [[ -f "$_input_file" ]] || fail "Input file not found: ${_input_file}"
        _run_python_masker < "$_input_file"
    elif [[ ${#_input_args[@]} -gt 0 ]]; then
        printf '%s\n' "${_input_args[@]}" | _run_python_masker
    elif [[ -p /dev/stdin ]]; then
        _run_python_masker
    else
        warn "No input provided. Pass a string, -i <file>, or pipe stdin."
        usage
    fi
}

# ── run_mask ───────────────────────────────────────────────────────────────────
run_mask() {
    local secrets_raw
    secrets_raw=$(build_secrets_raw "$_secrets_file" "${_extra_words[@]}")

    vlog "Secrets file: ${_secrets_file}"
    vlog "Safe word:    ${_safe_word}"

    # 'local -x' exports the variable only for the lifetime of this function
    # and its callees (including the python3 subprocess).
    local -x MASK_SAFE_WORD="$_safe_word"
    local -x MASK_SECRETS_RAW="$secrets_raw"
    local -x MASK_CHECK_ONLY=0

    _dispatch_input
}

# ── run_check ──────────────────────────────────────────────────────────────────
run_check() {
    local secrets_raw
    secrets_raw=$(build_secrets_raw "$_secrets_file" "${_extra_words[@]}")

    vlog "Secrets file: ${_secrets_file}"

    local -x MASK_SAFE_WORD="$_safe_word"
    local -x MASK_SECRETS_RAW="$secrets_raw"
    local -x MASK_CHECK_ONLY=1

    local rc=0
    _dispatch_input || rc=$?

    if [[ $rc -ne 0 ]]; then
        warn "Secrets detected in input."
    else
        vlog "Input is clean — no secrets detected."
    fi
    return $rc
}

# ── install_git_hook ───────────────────────────────────────────────────────────
install_git_hook() {
    local repo_path="${_hook_path:-$PWD}"
    local hook_dir="${repo_path}/.git/hooks"
    local hook_file="${hook_dir}/pre-commit"
    local mask_script="$_MASK_SELF"

    [[ -d "${repo_path}/.git" ]] || fail "Not a git repository: ${repo_path}"

    mkdir -p "$hook_dir"

    # Idempotency guard — don't install the same block twice
    if [[ -f "$hook_file" ]] && grep -q "mask-secret.sh secret check" "$hook_file" 2>/dev/null; then
        warn "mask-secret.sh pre-commit block already present in ${hook_file} — skipping."
        return 0
    fi

    # The hook block references _secrets_file at install time so the same file
    # is used even if MASK_SECRETS_FILE is not set in a CI environment.
    # shellcheck disable=SC2089
    local hook_block
    hook_block=$(cat <<HOOKEOF

# ── mask-secret.sh secret check ───────────────────────────────────────────────────────
# Installed by: mask-secret.sh -G
_MASK_SCRIPT="${mask_script}"
_MASK_SECRETS_FILE="\${MASK_SECRETS_FILE:-${_secrets_file}}"

if [[ ! -x "\$_MASK_SCRIPT" ]]; then
    printf '⚠  mask-secret.sh not found at %s — secret scanning skipped\n' "\$_MASK_SCRIPT" >&2
elif [[ ! -f "\$_MASK_SECRETS_FILE" ]]; then
    printf '⚠  secrets file not found at %s — secret scanning skipped\n' "\$_MASK_SECRETS_FILE" >&2
else
    if ! git diff --cached --unified=0 \
            | "\$_MASK_SCRIPT" -f "\$_MASK_SECRETS_FILE" -c; then
        printf '\n❌  Commit blocked: staged changes contain one or more secrets.\n' >&2
        printf '   Review:  git diff --cached | "%s" -f "%s"\n' \
            "\$_MASK_SCRIPT" "\$_MASK_SECRETS_FILE" >&2
        printf '   Bypass (use with care):  git commit --no-verify\n' >&2
        exit 1
    fi
fi
# ── end mask-secret.sh secret check ───────────────────────────────────────────────────
HOOKEOF
)

    if [[ -f "$hook_file" ]]; then
        # shellcheck disable=SC2090
        printf '%s\n' "$hook_block" >> "$hook_file"
        ok "Appended secret-check block to existing hook: ${hook_file}"
    else
        {
            printf '#!/usr/bin/env bash\nset -uo pipefail\n'
            printf '%s\n' "$hook_block"
        } > "$hook_file"
        chmod 755 "$hook_file"
        ok "Installed pre-commit hook: ${hook_file}"
    fi
}

# ── print_zle_setup ────────────────────────────────────────────────────────────
# Emit sourceable ZSH code that wires up masking hooks for the current session.
# The heredoc delimiter is unquoted so $var expands at generation time;
# runtime zsh variables are escaped as \$var to survive into the sourced code.
print_zle_setup() {
    local mask_script secrets_file safe_word
    mask_script="$_MASK_SELF"
    secrets_file="$_secrets_file"
    safe_word="$_safe_word"

    cat <<ZSHEOF
# ── mask-secret.sh ZLE integration ────────────────────────────────────────────────────
# Generated by: ${mask_script} -Z
# Source in .zshrc with:  source <(mask-secret.sh -Z)
# shellcheck shell=zsh

autoload -Uz add-zsh-hook

# ── configuration (override before sourcing if desired) ───────────────────────
typeset -g _MASK_SCRIPT="${mask_script}"
typeset -g _MASK_SECRETS_FILE="\${MASK_SECRETS_FILE:-${secrets_file}}"
typeset -g _MASK_SAFE_WORD="\${MASK_SAFE_WORD:-${safe_word}}"

# ── pattern cache (invalidated automatically when secrets file mtime changes) ─
typeset -g  _MASK_CACHE_FILE=""
typeset -g  _MASK_CACHE_MTIME=0
typeset -ga _MASK_CACHE_VALUES=()

# Reload the in-memory cache when the secrets file has changed on disk.
function _mask_refresh_cache() {
    local sf="\${MASK_SECRETS_FILE:-\$_MASK_SECRETS_FILE}"
    [[ -f "\$sf" ]] || return 0

    local mtime
    mtime=\$(stat -f '%m' "\$sf" 2>/dev/null) || mtime=0

    # Return early if nothing has changed
    if [[ "\$mtime" == "\$_MASK_CACHE_MTIME" && "\$sf" == "\$_MASK_CACHE_FILE" ]]; then
        return 0
    fi

    _MASK_CACHE_FILE="\$sf"
    _MASK_CACHE_MTIME="\$mtime"
    _MASK_CACHE_VALUES=()

    local v
    while IFS= read -r v; do
        [[ \${#v} -ge 4 ]] || continue
        _MASK_CACHE_VALUES+=("\$v")
    done < <(jq -r '.[] | select(type == "string" and length > 0)' "\$sf" 2>/dev/null)
}

# Apply masking to a string; prints the result to stdout.
# Uses Python so all characters (including regex/glob metacharacters) are safe.
function _mask_apply() {
    local input="\$1"
    [[ \${#_MASK_CACHE_VALUES[@]} -eq 0 ]] && { printf '%s' "\$input"; return 0; }

    local sw="\${MASK_SAFE_WORD:-\$_MASK_SAFE_WORD}"
    local values_nl
    printf -v values_nl '%s\n' "\${_MASK_CACHE_VALUES[@]}"

    # Secrets are passed via env (not argv) to keep them out of ps output
    MASK_SAFE_WORD="\$sw" MASK_SECRETS_RAW="\$values_nl" MASK_CHECK_ONLY=0 \
    python3 -c '
import sys, os
sw   = os.environ.get("MASK_SAFE_WORD", "***MASKED***")
vals = [v for v in os.environ.get("MASK_SECRETS_RAW", "").split("\n") if v]
text = sys.stdin.read()
for v in vals:
    text = text.replace(v, sw)
sys.stdout.write(text)
' <<< "\$input"
}

# preexec hook — warn when a command about to run contains a known secret value.
function _mask_preexec() {
    _mask_refresh_cache
    [[ \${#_MASK_CACHE_VALUES[@]} -eq 0 ]] && return 0

    local cmd="\$1" v
    for v in "\${_MASK_CACHE_VALUES[@]}"; do
        if [[ "\$cmd" == *"\$v"* ]]; then
            printf '\e[33m⚠  secret detected in command — history entry will be masked\e[0m\n' >&2
            break
        fi
    done
}

# zshaddhistory hook — save the masked version of a command to history and
# suppress the original entry (by returning 1).
function _mask_zshaddhistory() {
    _mask_refresh_cache
    [[ \${#_MASK_CACHE_VALUES[@]} -eq 0 ]] && return 0

    local cmd="\$1" masked
    masked=\$(_mask_apply "\$cmd")

    if [[ "\$masked" != "\$cmd" ]]; then
        print -s -- "\${masked%\$'\n'}"  # save masked version
        return 1                          # suppress original entry
    fi
    return 0
}

# ZLE widget — mask the current command-line buffer in-place.
# Default binding: Alt-m  (rebind after sourcing with: bindkey '^[M' ...)
function _mask_buffer_widget() {
    _mask_refresh_cache
    [[ \${#_MASK_CACHE_VALUES[@]} -eq 0 ]] && return 0

    local masked
    masked=\$(_mask_apply "\$BUFFER")
    if [[ "\$masked" != "\$BUFFER" ]]; then
        BUFFER="\$masked"
        zle redisplay
    fi
}
zle -N _mask_buffer_widget

# maskSecrets — (re)activate all hooks for the current session.
# Call this any time after loading a new secrets file to refresh the cache.
function maskSecrets() {
    add-zsh-hook preexec       _mask_preexec
    add-zsh-hook zshaddhistory _mask_zshaddhistory
    bindkey '^[m' _mask_buffer_widget   # Alt-m: mask current buffer in-place
    _mask_refresh_cache
    local sw="\${MASK_SAFE_WORD:-\$_MASK_SAFE_WORD}"
    printf '\e[32m✔  mask-secret.sh hooks active  (Alt-m masks buffer · safe-word: %s)\e[0m\n' "\$sw" >&2
}

# unmaskSecrets — deactivate all mask hooks for this session.
function unmaskSecrets() {
    add-zsh-hook -d preexec       _mask_preexec       2>/dev/null || true
    add-zsh-hook -d zshaddhistory _mask_zshaddhistory 2>/dev/null || true
    printf '\e[33m⚠  mask-secret.sh hooks deactivated\e[0m\n' >&2
}

# Auto-activate on source
maskSecrets
# ── end mask-secret.sh ZLE integration ───────────────────────────────────────────────
ZSHEOF
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
    if [[ "${1:-}" == "--help" ]]; then
        usage
    fi

    check_prereqs

    local opt OPTIND OPTARG
    while getopts ':mcZG:f:i:w:x:vh' opt; do
        case "$opt" in
            m) _mode="mask"  ;;
            c) _mode="check" ;;
            Z) _mode="zle"   ;;
            G) _mode="hook";  _hook_path="$OPTARG" ;;
            f) _secrets_file="$OPTARG" ;;
            i) _input_file="$OPTARG"   ;;
            w) _safe_word="$OPTARG"    ;;
            x)
                # shellcheck disable=SC2162
                IFS=',' read -r -A _extra_words <<< "$OPTARG"
                ;;
            v) _verbose=true ;;
            h) usage         ;;
            :) fail "Option -${OPTARG} requires an argument." ;;
           \?) fail "Unknown option: -${OPTARG}" ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    _input_args=("$@")

    case "$_mode" in
        mask)  run_mask         ;;
        check) run_check        ;;
        zle)   print_zle_setup  ;;
        hook)  install_git_hook ;;
    esac
}

main "$@"
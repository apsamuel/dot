#!/usr/bin/env bash
#% author: github.com/apsamuel
#% description: report which dot system dependencies are present / missing
#% usage: ./dot-deps-report.sh [OPTIONS]
#
# Options:
#   --tier <N>    Only audit a single tier (0-4)
#   -q | --quiet  Print only missing items
#   --json        Emit machine-readable JSON to stdout
#   --list        Dump the in-script tier table and exit
#   -h | --help   Show this help
#
# Exit codes:
#   0  All Tier 0 tools present (regardless of higher-tier gaps)
#   1  At least one Tier 0 required tool is missing
#   2  Bad usage
#
# See docs/details/DEPENDENCIES.md for the prose reference.

set -uo pipefail

# ── option parsing ───────────────────────────────────────────────────────────

TIER_FILTER=""
QUIET=0
JSON=0
LIST=0

usage() {
    grep '^#[%]' "$0" | sed 's/^#[%] \{0,1\}//'
    sed -n '/^# Options:/,/^# See/p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier)   TIER_FILTER="${2:-}"; shift 2 ;;
        -q|--quiet) QUIET=1; shift ;;
        --json)   JSON=1; shift ;;
        --list)   LIST=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -n "${TIER_FILTER}" && ! "${TIER_FILTER}" =~ ^[0-4]$ ]]; then
    printf '--tier must be 0-4 (got %q)\n' "${TIER_FILTER}" >&2
    exit 2
fi

# ── say_* helpers (emoji palette mirrors scripts/dot-bootstrap.sh) ───────────────

say_step() { printf '🔎 %s\n' "$*"; }
say_ok()   { printf '🟢 %s\n' "$*"; }
say_skip() { printf '🟠 %s\n' "$*"; }
say_err()  { printf '🔴 %s\n' "$*"; }
say_done() { printf '✅ %s\n' "$*"; }

# ── tier table — single source of truth ──────────────────────────────────────
# Format (pipe-delimited, no embedded pipes): tier|tool|required|category|note|install
#   tier      0 = bootstrap essentials, 1 = language toolchain,
#             2 = daily CLI, 3 = domain module, 4 = vendor framework runtime
#   required  yes | no  (only "yes" rows in tier 0 affect exit code)
#   category  short label for grouping in human output
#   note      one-line role description
#   install   one-line install hint (or "—")

TIERS=(
  # Tier 0 — bootstrap essentials
  "0|bash|yes|shell|bootstrap interpreter|brew install bash (macOS ships 3.2)"
  "0|zsh|yes|shell|login shell dot configures|brew install zsh"
  "0|git|yes|vcs|submodule sync, fugitive, secrets|xcode-select --install or brew install git"
  "0|curl|yes|net|brew installer, dot::node::get, fzf, secrets|ships on macOS"
  "0|jq|yes|data|JSON parsing in modules and brew helpers|brew install jq"
  "0|yq|yes|data|reads data/zsh.yaml at every shell start|brew install yq"
  "0|brew|yes|pkg|host for tier 1+ installs|bash bin/brew-bootstrap.sh install"
  "0|tmux|yes|tui|TPM plugin install in bootstrap|brew install tmux"

  # Tier 1 — language toolchains
  "1|uv|no|python|venv manager (~/.venv/<ver>-<arch>-base)|brew install uv"
  "1|python3|no|python|default venv interpreter and bin/*.py scripts|xcode-select --install"
  "1|n|no|node|node version manager (reads zsh.yaml)|brew install n"
  "1|node|no|node|JS runtime|installed by n"
  "1|npm|no|node|installs @google/gemini-cli, @openai/codex|installed by n"
  "1|cargo|no|rust|builds turtle/ and rust crates|brew install rustup-init && rustup-init"
  "1|rustup|no|rust|toolchain manager for cargo|brew install rustup-init"
  "1|jenv|no|java|JAVA_HOME resolution / JDK switch|brew install jenv"
  "1|java|no|java|JDK runtime|brew install openjdk"
  "1|swift|no|apple|builds bin/apple-vm-helper|xcode-select --install"

  # Tier 2 — daily-use CLI
  "2|fzf|no|tui|key-bindings, completion widgets, fzf-git|brew install fzf"
  "2|figlet|no|output|dot::output::term-quote / splash banners|brew install figlet"
  "2|lolcat|no|output|colorized quote pipe|brew install lolcat"
  "2|jp2a|no|output|dot::output::logo iCloud splash images|brew install jp2a"
  "2|kitty|no|term|dot::output::image helper|brew install --cask kitty"
  "2|shuf|no|util|splash + quote selection (gshuf on macOS)|brew install coreutils"
  "2|thefuck|no|util|fuck alias (DOT_DISABLE_THEFUCK opt-out)|brew install thefuck"
  "2|direnv|no|env|oh-my-zsh direnv plugin|brew install direnv"
  "2|z|no|nav|directory autojump (DOT_DISABLE_Z opt-out)|brew install z"
  "2|gh|no|git|GitHub CLI + bin/git-import-org.sh|brew install gh"
  "2|kubectl|no|k8s|oh-my-zsh kubectl plugin|brew install kubectl"
  "2|docker|no|container|oh-my-zsh docker plugins|brew install --cask docker"
  "2|nmap|no|net|oh-my-zsh nmap plugin|brew install nmap"
  "2|ansible|no|iac|oh-my-zsh ansible plugin|brew install ansible"
  "2|deno|no|js|oh-my-zsh deno plugin|brew install deno"
  "2|pygmentize|no|output|oh-my-zsh colorize plugin|brew install pygments"
  "2|bat|no|output|cless pager helper|brew install bat"
  "2|podman|no|container|modules/000-d-podman.sh|brew install podman"

  # Tier 3 — domain modules
  "3|terraform|no|sre|modules/002-a-sre.sh (placeholder today)|brew install terraform"
  "3|helm|no|sre|kubernetes package manager|brew install helm"
  "3|ffmpeg|no|av|modules/999-audio-video-tools.sh|brew install ffmpeg"
  "3|magick|no|av|imagemagick (often 'magick' or 'convert')|brew install imagemagick"
  "3|blender|no|av|bin/blender-render.sh|brew install --cask blender"
  "3|qemu-system-x86_64|no|vm|bin/ivm.py qemu backend|brew install qemu"
  "3|utmctl|no|vm|bin/ivm.py utm backend|UTM.app from utmapp.com"
  "3|vz|no|vm|bin/ivm.py apple fallback backend|brew install Code-Hex/tap/vz"

  # Tier 4 — vendor framework runtime
  "4|defaults|no|apple|macOS preference writes (bootstrap)|ships on macOS"
  "4|dscl|no|apple|preflight login-shell lookup|ships on macOS"
  "4|sw_vers|no|apple|macOS version banner|ships on macOS"
  "4|arch|no|apple|spawnArm / spawnIntel multi-arch shells|ships on macOS"
  "4|pbcopy|no|apple|tmux-yank / oh-my-zsh copypath|ships on macOS"
)

# ── operations ───────────────────────────────────────────────────────────────

if [[ "${LIST}" -eq 1 ]]; then
    printf 'tier|tool|required|category|note|install\n'
    printf '%s\n' "${TIERS[@]}"
    exit 0
fi

# Counters
total=0; ok=0; missing_required=0; missing_optional=0
json_first=1

if [[ "${JSON}" -eq 1 ]]; then
    printf '{"results":['
fi

current_tier=""

for row in "${TIERS[@]}"; do
    IFS='|' read -r tier tool required category note install <<<"${row}"

    if [[ -n "${TIER_FILTER}" && "${tier}" != "${TIER_FILTER}" ]]; then
        continue
    fi

    total=$((total + 1))

    # human-readable tier banners
    if [[ "${JSON}" -eq 0 && "${tier}" != "${current_tier}" ]]; then
        current_tier="${tier}"
        case "${tier}" in
            0) say_step "Tier 0 — bootstrap essentials" ;;
            1) say_step "Tier 1 — language toolchains" ;;
            2) say_step "Tier 2 — daily-use CLI tools" ;;
            3) say_step "Tier 3 — domain modules" ;;
            4) say_step "Tier 4 — vendor framework runtime" ;;
        esac
    fi

    if command -v "${tool}" >/dev/null 2>&1; then
        status="ok"
        ok=$((ok + 1))
    else
        if [[ "${tier}" == "0" && "${required}" == "yes" ]]; then
            status="missing-required"
            missing_required=$((missing_required + 1))
        else
            status="missing-optional"
            missing_optional=$((missing_optional + 1))
        fi
    fi

    if [[ "${JSON}" -eq 1 ]]; then
        if [[ "${json_first}" -eq 0 ]]; then
            printf ','
        fi
        json_first=0
        # JSON-escape only what we control: install hints may contain quotes,
        # but our table doesn't — keep escaping minimal but correct.
        esc_note="${note//\"/\\\"}"
        esc_install="${install//\"/\\\"}"
        printf '{"tier":%s,"tool":"%s","required":"%s","category":"%s","status":"%s","note":"%s","install":"%s"}' \
            "${tier}" "${tool}" "${required}" "${category}" "${status}" "${esc_note}" "${esc_install}"
        continue
    fi

    case "${status}" in
        ok)
            [[ "${QUIET}" -eq 0 ]] && say_ok "${tool} (${category}) — ${note}"
            ;;
        missing-required)
            say_err "${tool} (${category}) — REQUIRED — ${note}"
            printf '   ↳ install: %s\n' "${install}"
            ;;
        missing-optional)
            say_skip "${tool} (${category}) — optional — ${note}"
            [[ "${QUIET}" -eq 0 ]] && printf '   ↳ install: %s\n' "${install}"
            ;;
    esac
done

if [[ "${JSON}" -eq 1 ]]; then
    printf '],"summary":{"total":%d,"ok":%d,"missing_required":%d,"missing_optional":%d}}\n' \
        "${total}" "${ok}" "${missing_required}" "${missing_optional}"
else
    echo
    say_done "checked ${total} tools — ${ok} ok, ${missing_required} required missing, ${missing_optional} optional missing"
fi

if [[ "${missing_required}" -gt 0 ]]; then
    exit 1
fi
exit 0

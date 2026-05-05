#!/usr/bin/env bash
#% description: scrub secrets from git history — and report on exposure
#% usage:   bin/secret-scrub.sh [options]
#%
#% ── scrub options (default mode) ────────────────────────────────────────────
#%   -s <secret>           literal secret string to remove (repeatable)
#%   -f <file>             file of replacement rules (one per line)
#%                         each line: literal:<value>==>REPLACEMENT
#%                                or: regex:<pattern>==>REPLACEMENT
#%   -r <replacement>      replacement token written in place of the secret
#%                         (default: ***REMOVED***)
#%   -m                    also scrub all registered git submodules
#%   -n                    dry run — grep history for matches, no rewrites
#%   -v                    verbose — print step-by-step progress details
#%   --push                force-push all branches + tags to origin after scrubbing
#%                         (requires re-added remote; filter-repo removes it)
#%   --trufflehog          run trufflehog via container (docker or podman) and
#%                         add any discovered secrets to the scrub list;
#%                         equivalent to: trufflehog git file://.
#%                         can be combined with -s/-f for extra literals
#%
#% ── report options (--report mode) ─────────────────────────────────────────
#%   --report              run a full secret-exposure report (no rewrites)
#%                         requires at least one of: -s, --secrets-json, --trufflehog
#%   --secrets-json <file> JSON file of named secrets {"KEY": "value", ...}
#%                         works in both modes: values are scrubbed (scrub mode)
#%                         or used as the authoritative key/value map (report mode)
#%                         e.g. $ICLOUD/dot/secrets.json
#%   -o <fmt>              report output format: pretty|json  (default: pretty)
#%   -u                    fetch all remotes before scanning
#%   --depth <n>           limit history scan to last N commits per ref
#%                         (omit for full history)
#%   -d                    debug — verbose scan tracing to stderr
#%
#%   report severity levels:
#%     HIGH   — secret value found in a commit diff (any ref, local or remote)
#%     HIGH   — secret value present in the current working tree
#%     MEDIUM — secret key referenced in a commit message
#%     LOW    — secret key present in the working tree
#%
#% ── shared options ──────────────────────────────────────────────────────────
#%   -m                    also scan/scrub all registered git submodules
#%   -h                    print this help
#%
#% examples:
#%   bin/secret-scrub.sh -s "ghp_MyToken123"
#%   bin/secret-scrub.sh -s "API_KEY=abc123" -s "ANOTHER_SECRET" -m
#%   bin/secret-scrub.sh -f my-replacements.txt --push
#%   bin/secret-scrub.sh -s "ghp_MyToken123" -n              # quick dry run
#%   bin/secret-scrub.sh --trufflehog                        # trufflehog → scrub
#%   bin/secret-scrub.sh --trufflehog -n                     # trufflehog dry run
#%   bin/secret-scrub.sh --secrets-json "$ICLOUD/dot/secrets.json"           # JSON → scrub
#%   bin/secret-scrub.sh --secrets-json "$ICLOUD/dot/secrets.json" --trufflehog  # both
#%   bin/secret-scrub.sh --report -s "ghp_Tok123"            # report on one secret
#%   bin/secret-scrub.sh --report --secrets-json sec.json    # report from JSON file
#%   bin/secret-scrub.sh --report --trufflehog -o json       # trufflehog JSON report
#%   bin/secret-scrub.sh --report --secrets-json sec.json -u # fetch remotes first
#%   bin/secret-scrub.sh --report --secrets-json sec.json --depth 200 -m
#%
#% ⚠️  BEFORE running this script:
#%   1. Rotate / revoke the exposed secret immediately — cleaning history
#%      does NOT un-expose a secret that has already been pushed.
#%   2. Notify any collaborators: their local clones will diverge after
#%      the rewrite and must be re-cloned or hard-reset.
#%   3. This rewrites commit SHAs across all branches. CI/CD pipelines,
#%      open PRs, and protected-branch rules may all be affected.

set -euo pipefail

# ── colours & helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

VERBOSE=false

# When --report -o json is active, status messages are routed to stderr so
# stdout carries only the JSON payload.
_status_dest() { [[ "${REPORT_JSON_MODE:-false}" == "true" ]] && echo "err" || echo "out"; }

info()    { if [[ "$(_status_dest)" == "err" ]]; then echo -e "${CYAN}ℹ️  $*${RESET}" >&2;    else echo -e "${CYAN}ℹ️  $*${RESET}";    fi; }
ok()      { if [[ "$(_status_dest)" == "err" ]]; then echo -e "${GREEN}✅  $*${RESET}" >&2;   else echo -e "${GREEN}✅  $*${RESET}";   fi; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}" >&2; }
fail()    { echo -e "${RED}❌  $*${RESET}" >&2; exit 1; }
heading() { if [[ "$(_status_dest)" == "err" ]]; then echo -e "\n${BOLD}── $* ──${RESET}" >&2; else echo -e "\n${BOLD}── $* ──${RESET}"; fi; }
verbose() { [[ "$VERBOSE" == "true" ]] && echo -e "    ${DIM}▸ $*${RESET}" >&2 || true; }
debug()   { [[ "$VERBOSE" == "true" ]] && printf '%b\n' "${DIM}🔍 debug: $*${RESET}" >&2 || true; }

# ── usage ────────────────────────────────────────────────────────────────────
usage() {
    grep '^#%' "$0" | sed 's/^#% \{0,1\}//'
    exit 0
}

# ── prerequisites ────────────────────────────────────────────────────────────
check_prerequisites() {
    if ! command -v git-filter-repo &>/dev/null; then
        fail "git-filter-repo is required but not found.\n   Install: brew install git-filter-repo"
    fi

    if ! git rev-parse --git-dir &>/dev/null; then
        fail "Not inside a git repository."
    fi

    # Warn if there are uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        warn "You have uncommitted changes. Consider stashing or committing first."
        read -r -p "Continue anyway? [y/N] " confirm
        [[ "${confirm,,}" == "y" ]] || { info "Aborted."; exit 0; }
    fi
}

# ── report mode globals ──────────────────────────────────────────────────────
REPORT_MODE=false
REPORT_OUTPUT_FMT="pretty"
REPORT_DO_FETCH=false
REPORT_DEPTH=""          # empty = full history; set via --depth <n>
REPORT_SECRETS_JSON_FILE=""
REPORT_JSON_MODE=false   # derived: true when --report + -o json
REPORT_FINDINGS_FILE=""  # temp file; set at runtime

# ── report prerequisites ─────────────────────────────────────────────────────
check_report_prerequisites() {
    if ! command -v jq &>/dev/null; then
        fail "--report mode requires 'jq' but it was not found.\n   Install: brew install jq"
    fi
}

# ── report: git helpers ───────────────────────────────────────────────────────
_commit_field() { git -C "$1" log -1 --format="$3" "$2" 2>/dev/null || true; }

_files_in_diff() {
    local repo_path="$1" sha="$2" value="$3"
    local current_file=""
    while IFS= read -r line; do
        case "$line" in
            "+++ b/"*) current_file="${line#+++ b/}" ;;
            *)
                if [[ -n "$current_file" ]] && \
                   printf '%s' "$line" | grep -qF "$value" 2>/dev/null; then
                    printf '%s\n' "$current_file"
                fi
                ;;
        esac
    done < <(git -C "$repo_path" show "$sha" 2>/dev/null) | sort -u
}

_branches_for() {
    git -C "$1" branch -a --contains "$2" 2>/dev/null \
        | sed 's/^[[:space:]]*\*\?[[:space:]]*//' \
        | grep -v '^$' | sort | tr '\n' ',' | sed 's/,$//'
}

_commit_on_remote() {
    git -C "$1" branch -r --contains "$2" 2>/dev/null \
        | grep -q . && echo "true" || echo "false"
}

_append_finding() { jq -cn "$@" >> "$REPORT_FINDINGS_FILE"; }

# ── report: scan 1 — secret value in commit diffs (pickaxe) ─────────────────
_scan_value_in_history() {
    local repo_path="$1" key="$2" value="$3"
    debug "  _scan_value_in_history: key=${key}"

    local found=0
    while IFS= read -r sha; do
        [[ -z "$sha" ]] && continue
        found=$((found + 1))
        debug "    → commit ${sha:0:8}"

        local ts author message files branches is_remote
        ts="$(     _commit_field "$repo_path" "$sha" '%aI')"
        author="$( _commit_field "$repo_path" "$sha" '%ae')"
        message="$(_commit_field "$repo_path" "$sha" '%s')"
        files="$(  _files_in_diff "$repo_path" "$sha" "$value" | tr '\n' ',' | sed 's/,$//')"
        branches="$(_branches_for "$repo_path" "$sha")"
        is_remote="$(_commit_on_remote "$repo_path" "$sha")"

        _append_finding \
            --arg  type      "value_in_history" \
            --arg  severity  "high" \
            --arg  repo      "$repo_path" \
            --arg  key       "$key" \
            --arg  commit    "$sha" \
            --arg  timestamp "$ts" \
            --arg  author    "$author" \
            --arg  message   "$message" \
            --arg  files     "$files" \
            --arg  branches  "$branches" \
            --arg  is_remote "$is_remote" \
            '{
              type:      $type,
              severity:  $severity,
              repo:      $repo,
              key:       $key,
              commit:    $commit,
              short:     $commit[:8],
              timestamp: $timestamp,
              author:    $author,
              message:   $message,
              files:     ($files    | split(",") | map(select(length > 0))),
              branches:  ($branches | split(",") | map(select(length > 0))),
              is_remote: ($is_remote == "true")
            }'
    done < <(
        git -C "$repo_path" log --all \
            ${REPORT_DEPTH:+--max-count="$REPORT_DEPTH"} \
            -S "$value" --format="%H" -- 2>/dev/null || true
    )

    debug "    ✓ ${found} commit(s)"
}

# ── report: scan 2 — secret key in commit messages ───────────────────────────
_scan_key_in_messages() {
    local repo_path="$1" key="$2"
    debug "  _scan_key_in_messages: key=${key}"

    local found=0
    while IFS= read -r sha; do
        [[ -z "$sha" ]] && continue
        found=$((found + 1))
        debug "    → commit ${sha:0:8}"

        local ts author message branches is_remote
        ts="$(      _commit_field "$repo_path" "$sha" '%aI')"
        author="$(  _commit_field "$repo_path" "$sha" '%ae')"
        message="$( _commit_field "$repo_path" "$sha" '%s')"
        branches="$(_branches_for "$repo_path" "$sha")"
        is_remote="$(_commit_on_remote "$repo_path" "$sha")"

        _append_finding \
            --arg  type      "key_in_message" \
            --arg  severity  "medium" \
            --arg  repo      "$repo_path" \
            --arg  key       "$key" \
            --arg  commit    "$sha" \
            --arg  timestamp "$ts" \
            --arg  author    "$author" \
            --arg  message   "$message" \
            --arg  branches  "$branches" \
            --arg  is_remote "$is_remote" \
            '{
              type:      $type,
              severity:  $severity,
              repo:      $repo,
              key:       $key,
              commit:    $commit,
              short:     $commit[:8],
              timestamp: $timestamp,
              author:    $author,
              message:   $message,
              branches:  ($branches | split(",") | map(select(length > 0))),
              is_remote: ($is_remote == "true")
            }'
    done < <(
        git -C "$repo_path" log --all \
            ${REPORT_DEPTH:+--max-count="$REPORT_DEPTH"} \
            --fixed-strings --grep="$key" --format="%H" 2>/dev/null || true
    )

    debug "    ✓ ${found} commit message(s)"
}

# ── report: scan 3 — secret value/key in working tree ────────────────────────
_scan_tree() {
    local repo_path="$1" key="$2" value="$3"
    debug "  _scan_tree: key=${key}"

    _parse_grep_line() {
        local gline="$1"
        local file="${gline%%:*}"
        local rest="${gline#*:}"
        local line_num="${rest%%:*}"
        printf '%s\t%s' "$file" "$line_num"
    }

    # HIGH — value in working tree
    local vfound=0
    while IFS= read -r grepline; do
        [[ -z "$grepline" ]] && continue
        vfound=$((vfound + 1))
        local parsed; parsed="$(_parse_grep_line "$grepline")"
        local file line_num
        file="${parsed%%$'\t'*}"; line_num="${parsed##*$'\t'}"
        debug "    → value in tree: ${file}:${line_num}"
        _append_finding \
            --arg  type     "value_in_tree" \
            --arg  severity "high" \
            --arg  repo     "$repo_path" \
            --arg  key      "$key" \
            --arg  file     "$file" \
            --argjson line  "${line_num:-0}" \
            '{type:$type, severity:$severity, repo:$repo, key:$key, file:$file, line:$line}'
    done < <(git -C "$repo_path" grep -nF "$value" 2>/dev/null || true)

    # LOW — key name in working tree
    local kfound=0
    while IFS= read -r grepline; do
        [[ -z "$grepline" ]] && continue
        kfound=$((kfound + 1))
        local parsed; parsed="$(_parse_grep_line "$grepline")"
        local file line_num
        file="${parsed%%$'\t'*}"; line_num="${parsed##*$'\t'}"
        debug "    → key in tree: ${file}:${line_num}"
        _append_finding \
            --arg  type     "key_in_tree" \
            --arg  severity "low" \
            --arg  repo     "$repo_path" \
            --arg  key      "$key" \
            --arg  file     "$file" \
            --argjson line  "${line_num:-0}" \
            '{type:$type, severity:$severity, repo:$repo, key:$key, file:$file, line:$line}'
    done < <(git -C "$repo_path" grep -nF "$key" 2>/dev/null || true)

    debug "    ✓ tree: ${vfound} value hit(s), ${kfound} key hit(s)"
}

# ── report: scan one repo ─────────────────────────────────────────────────────
_scan_repo_report() {
    local repo_path="$1" secrets_json="$2"

    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        fail "Not a git repository: ${repo_path}"
    fi

    if [[ "$REPORT_DO_FETCH" == "true" ]]; then
        info "Fetching remotes: ${repo_path}"
        git -C "$repo_path" fetch --all --quiet 2>/dev/null \
            || warn "Could not fetch remotes for ${repo_path}"
    fi

    local keys=()
    mapfile -t keys < <(jq -r 'keys[]' <<< "$secrets_json" 2>/dev/null)

    for key in "${keys[@]}"; do
        local value
        value="$(jq -r --arg k "$key" '.[$k]' <<< "$secrets_json")"
        debug "Scanning key='${key}' value='${value:0:4}…'"

        _scan_value_in_history "$repo_path" "$key" "$value"
        _scan_key_in_messages  "$repo_path" "$key"
        _scan_tree             "$repo_path" "$key" "$value"
    done
}

# ── report: recurse into submodules ──────────────────────────────────────────
_scan_submodules_report() {
    local repo_root="$1" secrets_json="$2"
    local sm_paths=()

    while IFS= read -r line; do
        local sm
        sm="$(echo "$line" | sed "s/Entering '//;s'/'//")"
        sm_paths+=("${repo_root}/${sm}")
    done < <(
        git -C "$repo_root" submodule foreach --quiet \
            'echo "Entering '"'"'$displaypath'"'"'"' 2>/dev/null || true
    )

    if [[ ${#sm_paths[@]} -eq 0 ]]; then
        debug "No submodules found in ${repo_root}"
        return
    fi

    for sm_path in "${sm_paths[@]}"; do
        if [[ -d "${sm_path}/.git" || -f "${sm_path}/.git" ]]; then
            info "Scanning submodule: ${sm_path}"
            _scan_repo_report "$sm_path" "$secrets_json"
        else
            warn "Submodule not initialized — skipping: ${sm_path}"
        fi
    done
}

# ── report: render helpers ────────────────────────────────────────────────────
_severity_icon() {
    case "$1" in
        high)   printf '🔴' ;;
        medium) printf '🟡' ;;
        low)    printf '🔵' ;;
        *)      printf '⚪' ;;
    esac
}

_type_label() {
    case "$1" in
        value_in_history) printf 'Secret value found in commit history' ;;
        key_in_message)   printf 'Secret key referenced in commit message' ;;
        value_in_tree)    printf 'Secret value present in working tree' ;;
        key_in_tree)      printf 'Secret key present in working tree' ;;
        *)                printf '%s' "$1" ;;
    esac
}

# ── report: pretty renderer ───────────────────────────────────────────────────
_render_pretty_report() {
    local total
    total="$(wc -l < "$REPORT_FINDINGS_FILE" | tr -d '[:space:]')"

    if [[ "$total" -eq 0 ]]; then
        printf '\n'
        ok "No secrets found. All scanned repositories appear clean."
        return 0
    fi

    local counts
    counts="$(jq -s '{
      high:   (map(select(.severity=="high"))   | length),
      medium: (map(select(.severity=="medium")) | length),
      low:    (map(select(.severity=="low"))    | length)
    }' "$REPORT_FINDINGS_FILE")"

    local high medium low
    high=$(   jq -r '.high'   <<< "$counts")
    medium=$( jq -r '.medium' <<< "$counts")
    low=$(    jq -r '.low'    <<< "$counts")

    printf '\n%b\n'  "${BOLD}Secret Exposure Report${RESET}"
    printf '%b\n'    "${DIM}Generated : $(date -u '+%Y-%m-%dT%H:%M:%SZ')${RESET}"
    printf '\n'
    printf '  %-18s %b%s%b\n' "Total findings:" "${BOLD}"   "$total"  "${RESET}"
    printf '  %-18s %b%s%b\n' "🔴 High:"        "${RED}"    "$high"   "${RESET}"
    printf '  %-18s %b%s%b\n' "🟡 Medium:"      "${YELLOW}" "$medium" "${RESET}"
    printf '  %-18s %b%s%b\n' "🔵 Low:"         "${CYAN}"   "$low"    "${RESET}"
    printf '\n%b\n' "${BOLD}Findings${RESET}"
    printf '%b\n'   "${DIM}──────────────────────────────────────────────────────────────────${RESET}"

    local i=0
    while IFS= read -r finding; do
        [[ -z "$finding" ]] && continue
        i=$((i + 1))

        local type severity key repo icon label
        type=$(     jq -r '.type'     <<< "$finding")
        severity=$( jq -r '.severity' <<< "$finding")
        key=$(      jq -r '.key'      <<< "$finding")
        repo=$(     jq -r '.repo'     <<< "$finding")
        icon="$(  _severity_icon "$severity")"
        label="$( _type_label   "$type")"

        printf '\n%s %b[%d] %s%b  %b(%s)%b\n' \
            "$icon" "${BOLD}" "$i" "$label" "${RESET}" "${DIM}" "$severity" "${RESET}"
        printf '   %b%-12s%b %s\n' "${MAGENTA}" "Key:"  "${RESET}" "$key"
        printf '   %b%-12s%b %s\n' "${MAGENTA}" "Repo:" "${RESET}" "$repo"

        case "$type" in
            value_in_history|key_in_message)
                local short timestamp author message branches is_remote
                short=$(      jq -r '.short'                 <<< "$finding")
                timestamp=$(  jq -r '.timestamp'             <<< "$finding")
                author=$(     jq -r '.author'                <<< "$finding")
                message=$(    jq -r '.message'               <<< "$finding")
                branches=$(   jq -r '.branches | join(", ")' <<< "$finding")
                is_remote=$(  jq -r '.is_remote'             <<< "$finding")

                printf '   %b%-12s%b %s  %b(%s)%b\n' \
                    "${MAGENTA}" "Commit:" "${RESET}" "$short" "${DIM}" "$timestamp" "${RESET}"
                printf '   %b%-12s%b %s\n' "${MAGENTA}" "Author:"   "${RESET}" "$author"
                printf '   %b%-12s%b %s\n' "${MAGENTA}" "Message:"  "${RESET}" "$message"
                printf '   %b%-12s%b %s\n' "${MAGENTA}" "Branches:" "${RESET}" "$branches"

                if [[ "$type" == "value_in_history" ]]; then
                    local files
                    files=$(jq -r '.files | join(", ")' <<< "$finding")
                    printf '   %b%-12s%b %s\n' "${MAGENTA}" "Files:" "${RESET}" "${files:-<diff only>}"
                fi

                if [[ "$is_remote" == "true" ]]; then
                    printf '   %b⚠️  Also reachable from remote tracking branches!%b\n' "${RED}" "${RESET}"
                fi
                ;;
            value_in_tree|key_in_tree)
                local file line
                file=$(jq -r '.file' <<< "$finding")
                line=$(jq -r '.line' <<< "$finding")
                printf '   %b%-12s%b %s\n' "${MAGENTA}" "File:" "${RESET}" "$file"
                printf '   %b%-12s%b %s\n' "${MAGENTA}" "Line:" "${RESET}" "$line"
                ;;
        esac
    done < "$REPORT_FINDINGS_FILE"

    printf '\n%b\n\n' "${DIM}──────────────────────────────────────────────────────────────────${RESET}"

    if [[ "$high" -gt 0 ]]; then
        printf '%b\n' "${RED}${BOLD}Action required:${RESET}"
        printf '  1. Rotate any exposed secrets immediately.\n'
        printf '  2. Use bin/secret-scrub.sh to rewrite history and force-push.\n'
        printf '  3. Run this report again after scrubbing to confirm clean.\n'
        printf '\n'
    fi
}

# ── report: JSON renderer ─────────────────────────────────────────────────────
_render_json_report() {
    jq -s \
        --arg scanned_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        '{
          scanned_at: $scanned_at,
          summary: {
            total:  length,
            high:   (map(select(.severity=="high"))   | length),
            medium: (map(select(.severity=="medium")) | length),
            low:    (map(select(.severity=="low"))    | length)
          },
          findings: .
        }' < "$REPORT_FINDINGS_FILE"
}

# ── report: build secrets JSON from -s literals and/or --secrets-json file ────
# Produces a {"key": "value"} map: named from JSON file; unnamed from -s args.
_build_secrets_json() {
    local secrets_json_file="$1"; shift
    local literals=("$@")

    local combined="{}"

    # Merge named key/value pairs from --secrets-json file
    if [[ -n "$secrets_json_file" ]]; then
        [[ -f "$secrets_json_file" ]] \
            || fail "--secrets-json file not found: ${secrets_json_file}"
        local file_json
        file_json="$(jq '.' "$secrets_json_file" 2>/dev/null)" \
            || fail "Invalid JSON in --secrets-json file: ${secrets_json_file}"
        combined="$(jq -s '.[0] * .[1]' <<< "${combined}"$'\n'"${file_json}")"
    fi

    # Append -s literals: key name is the masked value for display purposes
    for val in "${literals[@]}"; do
        local masked="${val:0:4}$(printf '*%.0s' {1..8})"
        combined="$(jq --arg k "$masked" --arg v "$val" '. + {($k): $v}' <<< "$combined")"
    done

    printf '%s' "$combined"
}

# ── report: main orchestrator ─────────────────────────────────────────────────
run_report() {
    local repo_root="$1" secrets_json="$2" do_submodules="$3"

    [[ "$(jq 'length' <<< "$secrets_json")" -gt 0 ]] \
        || fail "No secrets to scan. Use -s, --secrets-json, or --trufflehog with --report."

    REPORT_FINDINGS_FILE="$(mktemp /tmp/secret-report.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '${REPORT_FINDINGS_FILE}'" EXIT

    heading "Secret Exposure Scan"
    info "Repo       : ${repo_root}"
    info "Secrets    : $(jq 'length' <<< "$secrets_json") key(s)"
    info "Upstream   : $( [[ "$REPORT_DO_FETCH" == "true" ]] && echo "fetch enabled (-u)" || echo "local refs only (use -u to fetch first)" )"
    info "Depth      : $( [[ -n "$REPORT_DEPTH" ]] && echo "last ${REPORT_DEPTH} commits (--depth)" || echo "full history" )"
    [[ "$do_submodules" == "true" ]] && info "Submodules : enabled (-m)"
    [[ "$VERBOSE" == "true" ]]       && info "Debug      : enabled (-d / -v)"
    info "Scanning..."

    _scan_repo_report "$repo_root" "$secrets_json"

    if [[ "$do_submodules" == "true" ]]; then
        _scan_submodules_report "$repo_root" "$secrets_json"
    fi

    case "$REPORT_OUTPUT_FMT" in
        pretty) _render_pretty_report ;;
        json)   _render_json_report   ;;
    esac
}

# ── trufflehog container scan ────────────────────────────────────────────────
# Runs: trufflehog git file://. (+ --json for machine-readable output)
# Prints one discovered secret value per line to stdout; all other output goes
# to stderr so the caller can capture just the secrets with mapfile/readarray.
run_trufflehog() {
    local repo_root="$1"

    # Detect available container runtime
    local runtime=""
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        runtime="docker"
    elif command -v podman &>/dev/null; then
        runtime="podman"
    else
        fail "--trufflehog requires docker or podman; neither is available."
    fi

    heading "TruffleHog scan" >&2
    info  "Runtime : ${runtime}" >&2
    info  "Running : trufflehog git file://. (--json --no-update)" >&2

    local raw_json=""
    # trufflehog exits non-zero when findings exist — suppress so set -e doesn't kill us
    raw_json="$(
        "${runtime}" run --rm \
            -v "${repo_root}:/repo:ro" \
            trufflesecurity/trufflehog:latest \
            git file:///repo \
            --json \
            --no-update \
            2>/dev/null
    )" || true

    if [[ -z "${raw_json}" ]]; then
        info "TruffleHog found no secrets." >&2
        return
    fi

    # Parse NDJSON (one JSON object per line); prefer jq, fall back to grep
    local found=()
    if command -v jq &>/dev/null; then
        while IFS= read -r val; do
            [[ -n "${val}" ]] && found+=("${val}")
        done < <(
            echo "${raw_json}" \
                | jq -r '(.Raw // ""), (.RawV2 // "")' 2>/dev/null \
                | grep -v '^$'
        )
    else
        # grep-based fallback — sufficient for well-formed trufflehog JSON
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            local raw rawv2
            raw="$(  echo "${line}" | grep -o '"Raw":"[^"]*"'   | head -1 | sed 's/"Raw":"//;s/"$//')"
            rawv2="$(echo "${line}" | grep -o '"RawV2":"[^"]*"' | head -1 | sed 's/"RawV2":"//;s/"$//')"
            [[ -n "${raw}"   ]] && found+=("${raw}")
            [[ -n "${rawv2}" ]] && found+=("${rawv2}")
        done <<< "${raw_json}"
    fi

    if [[ ${#found[@]} -eq 0 ]]; then
        warn "TruffleHog returned output but no secret values could be extracted." >&2
        return
    fi

    # Deduplicate while preserving order
    declare -A _th_seen
    local deduped=()
    for s in "${found[@]}"; do
        if [[ -n "${s}" && -z "${_th_seen[${s}]+_}" ]]; then
            _th_seen["${s}"]=1
            deduped+=("${s}")
        fi
    done

    ok "TruffleHog: ${#deduped[@]} unique secret value(s) queued for scrubbing." >&2
    printf '%s\n' "${deduped[@]}"
}

# ── build replacements file ───────────────────────────────────────────────────
# git filter-repo --replace-text format:
#   literal:<value>==>REPLACEMENT
#   regex:<pattern>==>REPLACEMENT
#   glob:<pattern>==>REPLACEMENT
build_replacements_file() {
    local outfile="$1"; shift
    local replacement="$1"; shift
    local secrets=("$@")

    # Start fresh
    : > "${outfile}"

    for secret in "${secrets[@]}"; do
        printf 'literal:%s==>%s\n' "${secret}" "${replacement}" >> "${outfile}"
        verbose "rule: literal:${secret:0:4}*** ==> ${replacement}"
    done
}

# ── dry run: grep history for matches ────────────────────────────────────────
dry_run() {
    local secrets=("$@")
    heading "Dry Run — searching history for secrets"

    local found=0
    for secret in "${secrets[@]}"; do
        info "Scanning for: ${secret:0:4}$(printf '*%.0s' {1..8})${secret: -2} ..."
        # Search commit diffs
        verbose "git log --all -p --diff-filter=ACMR | grep -F <value>"
        if git log --all -p --diff-filter=ACMR -- | grep -qF "${secret}" 2>/dev/null; then
            warn "Found in commit history (diffs/blobs)"
            if [[ "$VERBOSE" == "true" ]]; then
                git log --all -S "${secret}" --oneline 2>/dev/null | sed 's/^/    /'
            fi
            found=1
        fi
        # Search all trees (filenames and content via git grep)
        verbose "git grep -l --all-targets <value>"
        if git grep -l --all-targets "${secret}" 2>/dev/null | grep -q .; then
            warn "Found in tracked files:"
            git grep -l --all-targets "${secret}" 2>/dev/null | sed 's/^/    /'
            found=1
        fi
        # Search commit messages
        verbose "git log --all --grep=<key> --oneline"
        if git log --all --grep="${secret}" --oneline | grep -q .; then
            warn "Found in commit messages:"
            git log --all --grep="${secret}" --oneline | sed 's/^/    /'
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        ok "No matches found. Nothing to scrub."
    else
        warn "Matches found. Re-run without -n to rewrite history."
    fi
}

# ── scrub a single repo ───────────────────────────────────────────────────────
scrub_repo() {
    local repo_path="$1"
    local replacements_file="$2"
    local do_push="${3:-false}"

    heading "Scrubbing: ${repo_path}"
    pushd "${repo_path}" > /dev/null

    # Capture remote URL before filter-repo removes it
    local remote_url=""
    if git remote get-url origin &>/dev/null; then
        remote_url="$(git remote get-url origin)"
        info "Captured remote URL: ${remote_url}"
    fi

    # Snapshot all current commit SHAs so we can verify something actually changed
    local pre_head
    pre_head="$(git rev-parse HEAD)"
    verbose "HEAD before rewrite : ${pre_head}"

    info "Rewriting history with git-filter-repo..."
    verbose "git filter-repo --replace-text ${replacements_file} --force"
    # --force is required when the repo has an origin (it's a safety guard)
    git filter-repo \
        --replace-text "${replacements_file}" \
        --force \
        2>&1 | sed 's/^/  /'

    # ── verify the rewrite actually changed something ────────────────────────
    local post_head
    post_head="$(git rev-parse HEAD)"
    if [[ "${pre_head}" == "${post_head}" ]]; then
        warn "HEAD SHA is unchanged after filter-repo — the replacement pattern"
        warn "likely did not match any blobs. Double-check the secret value."
        warn "No history was modified in: ${repo_path}"
    else
        ok "History rewritten. HEAD changed: ${pre_head:0:12} → ${post_head:0:12}"
    fi

    # ── post-rewrite cleanup ─────────────────────────────────────────────────
    heading "Post-rewrite cleanup: ${repo_path}"

    info "Expiring reflog..."
    verbose "git reflog expire --expire=now --all"
    git reflog expire --expire=now --all

    info "Running aggressive gc to prune orphaned objects..."
    verbose "git gc --prune=now --aggressive"
    git gc --prune=now --aggressive 2>&1 | sed 's/^/  /'

    # Clean up the backup refs that filter-repo may leave
    if git show-ref | grep -q 'refs/filter-repo'; then
        info "Removing filter-repo backup refs..."
        verbose "git for-each-ref --format='delete %(refname)' refs/filter-repo | git update-ref --stdin"
        git for-each-ref --format='delete %(refname)' refs/filter-repo | \
            git update-ref --stdin
    fi

    ok "Cleanup complete."

    # ── restore remote & optionally push ────────────────────────────────────
    if [[ -n "${remote_url}" ]]; then
        info "Re-adding remote origin: ${remote_url}"
        git remote add origin "${remote_url}"

        if [[ "${do_push}" == "true" ]]; then
            heading "Force-pushing to origin"
            warn "This is irreversible. All collaborators MUST re-clone."
            read -r -p "Force-push ${repo_path} to origin? [y/N] " confirm
            if [[ "${confirm,,}" == "y" ]]; then
                verbose "git push origin --force --all"
                git push origin --force --all
                verbose "git push origin --force --tags"
                git push origin --force --tags
                ok "Force-pushed all branches and tags."
            else
                info "Skipped push. When ready, run:"
                echo "  cd ${repo_path} && git push origin --force --all && git push origin --force --tags"
            fi
        else
            info "Remote restored. When ready to publish the rewrite, run:"
            echo "  cd ${repo_path} && git push origin --force --all && git push origin --force --tags"
            warn "⚠️  Do NOT run 'git pull' before force-pushing — it will re-introduce"
            warn "   the old commits from the remote, undoing the rewrite."
        fi
    fi

    popd > /dev/null
}

# ── submodule handling ────────────────────────────────────────────────────────
scrub_submodules() {
    local repo_root="$1"
    local replacements_file="$2"
    local do_push="$3"

    heading "Scrubbing submodules"

    local submodule_paths=()
    while IFS= read -r line; do
        # git submodule foreach outputs: Entering 'vendor/ohmyzsh'
        local sm_path
        sm_path="$(echo "${line}" | sed "s/Entering '//;s/'//")"
        submodule_paths+=("${repo_root}/${sm_path}")
    done < <(git -C "${repo_root}" submodule foreach --quiet 'echo "Entering '"'"'$displaypath'"'"'"')

    if [[ ${#submodule_paths[@]} -eq 0 ]]; then
        info "No submodules found."
        return
    fi

    for sm_path in "${submodule_paths[@]}"; do
        info "Processing submodule: ${sm_path}"
        if [[ -d "${sm_path}/.git" || -f "${sm_path}/.git" ]]; then
            # Submodules always prompt for push — leaving a submodule unpushed
            # is the most common failure mode (secret stays on remote).
            scrub_repo "${sm_path}" "${replacements_file}" "true"
        else
            warn "Skipping ${sm_path} — not a git repo (may not be initialized)"
        fi
    done
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    local secrets=()
    local rules_file=""
    local replacement="***REMOVED***"
    local do_submodules=false
    local dry=false
    local do_push=false
    local do_trufflehog=false

    # parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)             [[ -n "${2:-}" ]] || fail "-s requires a value"; secrets+=("$2"); shift 2 ;;
            -f)             [[ -n "${2:-}" ]] || fail "-f requires a file path"; rules_file="$2"; shift 2 ;;
            -r)             [[ -n "${2:-}" ]] || fail "-r requires a value"; replacement="$2"; shift 2 ;;
            -m)             do_submodules=true; shift ;;
            -n)             dry=true; shift ;;
            -v|-d)          VERBOSE=true; shift ;;
            --push)         do_push=true; shift ;;
            --trufflehog)   do_trufflehog=true; shift ;;
            --report)       REPORT_MODE=true; shift ;;
            --secrets-json) [[ -n "${2:-}" ]] || fail "--secrets-json requires a file path"
                            REPORT_SECRETS_JSON_FILE="$2"; shift 2 ;;
            -o)             [[ -n "${2:-}" ]] || fail "-o requires pretty or json"
                            REPORT_OUTPUT_FMT="$2"; shift 2 ;;
            -u)             REPORT_DO_FETCH=true; shift ;;
            --depth)        [[ -n "${2:-}" ]] || fail "--depth requires a positive integer"
                            [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] \
                                || fail "--depth must be a positive integer, got: $2"
                            REPORT_DEPTH="$2"; shift 2 ;;
            -h|--help)      usage ;;
            *)              fail "Unknown option: $1\nRun with -h for help." ;;
        esac
    done

    # Validate report output format if specified
    if [[ "$REPORT_OUTPUT_FMT" != "pretty" && "$REPORT_OUTPUT_FMT" != "json" ]]; then
        fail "-o must be 'pretty' or 'json', got: ${REPORT_OUTPUT_FMT}"
    fi
    [[ "$REPORT_MODE" == "true" && "$REPORT_OUTPUT_FMT" == "json" ]] && REPORT_JSON_MODE=true

    # must have at least one source of secrets
    if [[ ${#secrets[@]} -eq 0 && -z "${rules_file}" && "${do_trufflehog}" != "true" \
          && -z "${REPORT_SECRETS_JSON_FILE}" ]]; then
        fail "Provide at least one secret via -s, -f, --secrets-json, or --trufflehog.\nRun with -h for help."
    fi

    check_prerequisites
    [[ "$REPORT_MODE" == "true" || -n "$REPORT_SECRETS_JSON_FILE" ]] && check_report_prerequisites

    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"

    # ── trufflehog mode ───────────────────────────────────────────────────────
    if [[ "${do_trufflehog}" == "true" ]]; then
        local th_secrets=()
        mapfile -t th_secrets < <(run_trufflehog "${repo_root}")
        if [[ ${#th_secrets[@]} -gt 0 ]]; then
            secrets+=("${th_secrets[@]}")
        else
            # If trufflehog found nothing and there are no other secrets, bail early
            if [[ ${#secrets[@]} -eq 0 && -z "${rules_file}" && -z "${REPORT_SECRETS_JSON_FILE}" ]]; then
                info "TruffleHog found no secrets and no other secrets were provided — nothing to do."
                exit 0
            fi
        fi
    fi

    # ── report mode — run full exposure report, then exit ────────────────────
    if [[ "$REPORT_MODE" == "true" ]]; then
        local report_secrets_json
        report_secrets_json="$(_build_secrets_json "${REPORT_SECRETS_JSON_FILE}" "${secrets[@]+"${secrets[@]}"}")"
        run_report "${repo_root}" "${report_secrets_json}" "${do_submodules}"
        exit 0
    fi

    # ── load secrets from JSON file into scrub list ─────────────────────────
    if [[ -n "$REPORT_SECRETS_JSON_FILE" ]]; then
        [[ ! -f "$REPORT_SECRETS_JSON_FILE" ]] \
            && fail "Secrets JSON file not found: ${REPORT_SECRETS_JSON_FILE}"
        local json_secrets=()
        mapfile -t json_secrets < <(jq -r 'to_entries[] | .value | select(. != null and . != "")' \
            "$REPORT_SECRETS_JSON_FILE" 2>/dev/null)
        if [[ ${#json_secrets[@]} -gt 0 ]]; then
            info "Loaded ${#json_secrets[@]} secret(s) from ${REPORT_SECRETS_JSON_FILE}"
            secrets+=("${json_secrets[@]}")
        else
            warn "No secret values found in ${REPORT_SECRETS_JSON_FILE}"
        fi
    fi

    # ── build the replacements file ──────────────────────────────────────────
    local tmp_replacements
    tmp_replacements="$(mktemp /tmp/secret-scrub-rules.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_replacements}'" EXIT

    if [[ ${#secrets[@]} -gt 0 ]]; then
        build_replacements_file "${tmp_replacements}" "${replacement}" "${secrets[@]}"
    fi

    # append any user-supplied rules file
    if [[ -n "${rules_file}" ]]; then
        if [[ ! -f "${rules_file}" ]]; then
            fail "Rules file not found: ${rules_file}"
        fi
        cat "${rules_file}" >> "${tmp_replacements}"
    fi

    [[ "$VERBOSE" == "true" ]] && info "Verbose    : enabled (-v)"
    info "Replacement rules:"
    # Print rules but mask any secret values in output
    sed 's/\(literal:\|regex:\|glob:\)\(.\{4\}\).*/\1\2***/' "${tmp_replacements}" | sed 's/^/  /'

    # ── dry run mode ─────────────────────────────────────────────────────────
    if [[ "${dry}" == "true" ]]; then
        dry_run "${secrets[@]}"
        exit 0
    fi

    # ── confirm before rewriting ─────────────────────────────────────────────
    heading "Pre-flight confirmation"
    warn "This will permanently rewrite git history in: ${repo_root}"
    [[ "${do_submodules}" == "true" ]] && warn "…and all submodules."
    warn "Commit SHAs will change. Collaborators must re-clone after you force-push."
    echo ""
    read -r -p "Proceed with rewriting history? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { info "Aborted. No changes made."; exit 0; }

    # ── scrub main repo ───────────────────────────────────────────────────────
    scrub_repo "${repo_root}" "${tmp_replacements}" "${do_push}"

    # ── optionally scrub submodules ───────────────────────────────────────────
    if [[ "${do_submodules}" == "true" ]]; then
        scrub_submodules "${repo_root}" "${tmp_replacements}" "${do_push}"
    fi

    # ── final reminders ───────────────────────────────────────────────────────
    heading "Done — next steps"
    echo -e "${YELLOW}1. Rotate the exposed secret immediately if you haven't already.${RESET}"
    echo -e "${YELLOW}2. Force-push to origin (if not done above):${RESET}"
    echo    "     git push origin --force --all"
    echo    "     git push origin --force --tags"
    echo -e "${YELLOW}3. Ask all collaborators to re-clone the repository.${RESET}"
    echo -e "${YELLOW}4. Check GitHub/GitLab secret scanning alerts and mark them resolved.${RESET}"
    echo -e "${YELLOW}5. Review dependent CI/CD pipelines for cached secrets or credentials.${RESET}"
    echo ""
    ok "Secret scrub complete."
}

main "$@"

#!/usr/bin/env bash
#% description: report on secrets exposed in git history (local and upstream refs)
#% usage:   bin/secret-report.sh [options]
#%
#% options:
#%   -f <file>      JSON secrets file (required)
#%                  format: {"KEY": "value", "KEY2": "value2"}
#%   -r <path>      git repo path (default: current directory)
#%   -m             also scan all registered submodules
#%   -u             fetch remotes before scanning (ensures upstream refs are current)
#%   -n <count>      limit history search to the last N commits per ref
#%                  (omit for full history — can be slow on large repos)
#%   -o <fmt>       output format: pretty|json  (default: pretty)
#%   -d             debug mode — verbose scan tracing to stderr
#%   -h             print this help
#%
#% what is scanned:
#%   HIGH   — secret value found in a commit's diff (all refs: local + remotes)
#%   HIGH   — secret value found in the current working tree
#%   MEDIUM — secret key found in a commit message (subject or body)
#%   LOW    — secret key found in the current working tree
#%
#% examples:
#%   bin/secret-report.sh -f /tmp/secrets.json
#%   bin/secret-report.sh -f /tmp/secrets.json -r /path/to/repo -m
#%   bin/secret-report.sh -f /tmp/secrets.json -u -o json | jq '.findings'
#%   bin/secret-report.sh -f /tmp/secrets.json -n 100          # last 100 commits only
#%   bin/secret-report.sh -f /tmp/secrets.json -r vendor/oh-my-zsh -d

set -uo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── globals ────────────────────────────────────────────────────────────────────
FINDINGS_FILE=""
DEBUG=false
OUTPUT_FMT="pretty"
DO_SUBMODULES=false
DO_FETCH=false
DEPTH=""          # empty = full history; set via -n <count>

# ── logging ────────────────────────────────────────────────────────────────────
debug()   { [[ "$DEBUG" == "true" ]] && printf '%b\n' "${DIM}🔍 debug: $*${RESET}" >&2 || true; }
info()    { [[ "$OUTPUT_FMT" == "pretty" ]] && printf '%b\n' "${CYAN}ℹ️  $*${RESET}" || true; }
ok()      { [[ "$OUTPUT_FMT" == "pretty" ]] && printf '%b\n' "${GREEN}✅ $*${RESET}" || true; }
warn()    { [[ "$OUTPUT_FMT" == "pretty" ]] && printf '%b\n' "${YELLOW}⚠️  $*${RESET}" >&2 || true; }
fail()    { printf '%b\n' "${RED}❌ $*${RESET}" >&2; exit 1; }
heading() { [[ "$OUTPUT_FMT" == "pretty" ]] && printf '\n%b\n' "${BOLD}── $* ──${RESET}" || true; }

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#%' "$0" | sed 's/^#% \{0,1\}//'
  exit 0
}

# ── prerequisites ──────────────────────────────────────────────────────────────
check_prereqs() {
  for cmd in git jq; do
    command -v "$cmd" &>/dev/null || fail "'${cmd}' is required but not installed."
  done
}

# ── validate a git repo path ───────────────────────────────────────────────────
validate_repo() {
  local path="$1"
  [[ -d "$path" ]] || fail "Path does not exist: ${path}"
  git -C "$path" rev-parse --git-dir &>/dev/null \
    || fail "Not a git repository: ${path}\n   (run 'git init' or provide a valid path with -r)"
}

# ── get a single field from a commit ──────────────────────────────────────────
# Usage: commit_field <repo> <sha> <format>
commit_field() {
  git -C "$1" log -1 --format="$3" "$2" 2>/dev/null || true
}

# ── list files in a commit's diff that contain a fixed string ─────────────────
# Parses unified diff: tracks "+++ b/<file>" headers, matches added/removed lines
files_in_diff() {
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

# ── list all branches (local + remote) containing a commit ────────────────────
branches_for() {
  git -C "$1" branch -a --contains "$2" 2>/dev/null \
    | sed 's/^[[:space:]]*\*\?[[:space:]]*//' \
    | grep -v '^$' | sort | tr '\n' ',' | sed 's/,$//'
}

# ── append one JSON finding to FINDINGS_FILE ──────────────────────────────────
append_finding() {
  jq -cn "$@" >> "$FINDINGS_FILE"
}

# ── helper: is a commit reachable from any remote tracking branch? ─────────────
commit_on_remote() {
  local repo_path="$1" sha="$2"
  git -C "$repo_path" branch -r --contains "$sha" 2>/dev/null | grep -q . && echo "true" || echo "false"
}

# ══════════════════════════════════════════════════════════════════════════════
# SCAN 1 — secret value found in a commit's diff (pickaxe search)
# Covers all refs: local branches, tags, and remote tracking branches
# ══════════════════════════════════════════════════════════════════════════════
scan_value_in_history() {
  local repo_path="$1" key="$2" value="$3"
  debug "  scan_value_in_history: key=${key}"

  local found=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    found=$((found + 1))
    debug "    → commit ${sha:0:8}"

    local ts author message files branches is_remote
    ts="$(commit_field "$repo_path" "$sha" '%aI')"
    author="$(commit_field "$repo_path" "$sha" '%ae')"
    message="$(commit_field "$repo_path" "$sha" '%s')"
    files="$(files_in_diff "$repo_path" "$sha" "$value" | tr '\n' ',' | sed 's/,$//')"
    branches="$(branches_for "$repo_path" "$sha")"
    is_remote="$(commit_on_remote "$repo_path" "$sha")"

    append_finding \
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
  done < <(git -C "$repo_path" log --all ${DEPTH:+--max-count="$DEPTH"} -S "$value" --format="%H" -- 2>/dev/null || true)

  debug "    ✓ ${found} commit(s)"
}

# ══════════════════════════════════════════════════════════════════════════════
# SCAN 2 — secret key referenced in commit messages (subject + body)
# ══════════════════════════════════════════════════════════════════════════════
scan_key_in_messages() {
  local repo_path="$1" key="$2"
  debug "  scan_key_in_messages: key=${key}"

  # git log --fixed-strings --grep does fixed-string matching against subject+body
  local found=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    found=$((found + 1))
    debug "    → commit ${sha:0:8}"

    local ts author message branches is_remote
    ts="$(commit_field "$repo_path" "$sha" '%aI')"
    author="$(commit_field "$repo_path" "$sha" '%ae')"
    message="$(commit_field "$repo_path" "$sha" '%s')"
    branches="$(branches_for "$repo_path" "$sha")"
    is_remote="$(commit_on_remote "$repo_path" "$sha")"

    append_finding \
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
    git -C "$repo_path" log --all ${DEPTH:+--max-count="$DEPTH"} --fixed-strings --grep="$key" --format="%H" 2>/dev/null || true
  )

  debug "    ✓ ${found} commit message(s)"
}

# ══════════════════════════════════════════════════════════════════════════════
# SCAN 3 — secret value / key found in the current working tree
# ══════════════════════════════════════════════════════════════════════════════
scan_tree() {
  local repo_path="$1" key="$2" value="$3"
  debug "  scan_tree: key=${key}"

  # git grep output format: <file>:<line_num>:<content>
  # Content may contain colons — split only on first two
  _parse_grep_line() {
    local gline="$1"
    local file="${gline%%:*}"
    local rest="${gline#*:}"
    local line_num="${rest%%:*}"
    printf '%s\t%s' "$file" "$line_num"
  }

  # High — value in working tree
  local vfound=0
  while IFS= read -r grepline; do
    [[ -z "$grepline" ]] && continue
    vfound=$((vfound + 1))
    local parsed; parsed="$(_parse_grep_line "$grepline")"
    local file line_num
    file="${parsed%%$'\t'*}"; line_num="${parsed##*$'\t'}"
    debug "    → value in tree: ${file}:${line_num}"
    append_finding \
      --arg  type     "value_in_tree" \
      --arg  severity "high" \
      --arg  repo     "$repo_path" \
      --arg  key      "$key" \
      --arg  file     "$file" \
      --argjson line  "${line_num:-0}" \
      '{type:$type, severity:$severity, repo:$repo, key:$key, file:$file, line:$line}'
  done < <(git -C "$repo_path" grep -nF "$value" 2>/dev/null || true)

  # Low — key name in working tree (may indicate an unset or future exposure)
  local kfound=0
  while IFS= read -r grepline; do
    [[ -z "$grepline" ]] && continue
    kfound=$((kfound + 1))
    local parsed; parsed="$(_parse_grep_line "$grepline")"
    local file line_num
    file="${parsed%%$'\t'*}"; line_num="${parsed##*$'\t'}"
    debug "    → key in tree: ${file}:${line_num}"
    append_finding \
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

# ══════════════════════════════════════════════════════════════════════════════
# Run all scans for a single repo
# ══════════════════════════════════════════════════════════════════════════════
scan_repo() {
  local repo_path="$1" secrets_json="$2"
  validate_repo "$repo_path"

  if [[ "$DO_FETCH" == "true" ]]; then
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

    scan_value_in_history "$repo_path" "$key" "$value"
    scan_key_in_messages  "$repo_path" "$key"
    scan_tree             "$repo_path" "$key" "$value"
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# Recurse into submodules
# ══════════════════════════════════════════════════════════════════════════════
scan_submodules() {
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
      scan_repo "$sm_path" "$secrets_json"
    else
      warn "Submodule not initialized — skipping: ${sm_path}"
    fi
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# RENDER: pretty (coloured, emoji)
# ══════════════════════════════════════════════════════════════════════════════
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

render_pretty() {
  local total
  total="$(wc -l < "$FINDINGS_FILE" | tr -d '[:space:]')"

  if [[ "$total" -eq 0 ]]; then
    printf '\n'
    ok "No secrets found. All scanned repositories appear clean."
    return 0
  fi

  # Count by severity in one jq pass
  local counts
  counts="$(jq -s '{
    high:   (map(select(.severity=="high"))   | length),
    medium: (map(select(.severity=="medium")) | length),
    low:    (map(select(.severity=="low"))    | length)
  }' "$FINDINGS_FILE")"

  local high medium low
  high=$(jq -r '.high'   <<< "$counts")
  medium=$(jq -r '.medium' <<< "$counts")
  low=$(jq -r '.low'    <<< "$counts")

  printf '\n%b\n' "${BOLD}Secret Exposure Report${RESET}"
  printf '%b\n'   "${DIM}Generated : $(date -u '+%Y-%m-%dT%H:%M:%SZ')${RESET}"
  printf '\n'
  printf '  %-18s %b%s%b\n' "Total findings:" "${BOLD}" "$total" "${RESET}"
  printf '  %-18s %b%s%b\n' "🔴 High:"        "${RED}"    "$high"   "${RESET}"
  printf '  %-18s %b%s%b\n' "🟡 Medium:"      "${YELLOW}" "$medium" "${RESET}"
  printf '  %-18s %b%s%b\n' "🔵 Low:"         "${CYAN}"   "$low"    "${RESET}"
  printf '\n%b\n' "${BOLD}Findings${RESET}"
  printf '%b\n'   "${DIM}──────────────────────────────────────────────────────────────────${RESET}"

  local i=0
  while IFS= read -r finding; do
    [[ -z "$finding" ]] && continue
    i=$((i + 1))

    local type severity key repo
    type=$(     jq -r '.type'     <<< "$finding")
    severity=$( jq -r '.severity' <<< "$finding")
    key=$(      jq -r '.key'      <<< "$finding")
    repo=$(     jq -r '.repo'     <<< "$finding")

    local icon label
    icon="$(_severity_icon "$severity")"
    label="$(_type_label   "$type")"

    printf '\n%s %b[%d] %s%b  %b(%s)%b\n' \
      "$icon" "${BOLD}" "$i" "$label" "${RESET}" "${DIM}" "$severity" "${RESET}"
    printf '   %b%-12s%b %s\n' "${MAGENTA}" "Key:"    "${RESET}" "$key"
    printf '   %b%-12s%b %s\n' "${MAGENTA}" "Repo:"   "${RESET}" "$repo"

    case "$type" in
      value_in_history|key_in_message)
        local short timestamp author message branches is_remote
        short=$(     jq -r '.short'           <<< "$finding")
        timestamp=$( jq -r '.timestamp'       <<< "$finding")
        author=$(    jq -r '.author'          <<< "$finding")
        message=$(   jq -r '.message'         <<< "$finding")
        branches=$(  jq -r '.branches | join(", ")' <<< "$finding")
        is_remote=$( jq -r '.is_remote'       <<< "$finding")

        printf '   %b%-12s%b %s  %b(%s)%b\n' \
          "${MAGENTA}" "Commit:"  "${RESET}" "$short" "${DIM}" "$timestamp" "${RESET}"
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
  done < "$FINDINGS_FILE"

  printf '\n%b\n\n' "${DIM}──────────────────────────────────────────────────────────────────${RESET}"

  if [[ "$high" -gt 0 ]]; then
    printf '%b\n' "${RED}${BOLD}Action required:${RESET}"
    printf '  1. Rotate any exposed secrets immediately.\n'
    printf '  2. Use bin/git-secret.sh to rewrite history and force-push.\n'
    printf '  3. Run this report again after scrubbing to confirm clean.\n'
    printf '\n'
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# RENDER: JSON
# ══════════════════════════════════════════════════════════════════════════════
render_json() {
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
    }' < "$FINDINGS_FILE"
}

# ══════════════════════════════════════════════════════════════════════════════
# main
# ══════════════════════════════════════════════════════════════════════════════
main() {
  local secrets_file=""
  local repo_path="$PWD"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f)       [[ -n "${2:-}" ]] || fail "-f requires a file path"; secrets_file="$2"; shift 2 ;;
      -r)       [[ -n "${2:-}" ]] || fail "-r requires a path";      repo_path="$2";   shift 2 ;;
      -m)       DO_SUBMODULES=true; shift ;;
      -n)       [[ -n "${2:-}" ]] || fail "-n requires a count"
                [[ "$2" =~ ^[0-9]+$ && "$2" -gt 0 ]] || fail "-n must be a positive integer, got: $2"
                DEPTH="$2"; shift 2 ;;
      -u)       DO_FETCH=true;      shift ;;
      -d)       DEBUG=true;         shift ;;
      -o)       [[ -n "${2:-}" ]] || fail "-o requires pretty or json"; OUTPUT_FMT="$2"; shift 2 ;;
      -h|--help) usage ;;
      *) fail "Unknown option: $1\nRun with -h for help." ;;
    esac
  done

  [[ -n "$secrets_file" ]] \
    || fail "A secrets JSON file is required.\n   Usage: $0 -f <file>\n   Run with -h for help."
  [[ -f "$secrets_file" ]] \
    || fail "Secrets file not found: ${secrets_file}"
  [[ "$OUTPUT_FMT" == "pretty" || "$OUTPUT_FMT" == "json" ]] \
    || fail "Output format must be 'pretty' or 'json', got: ${OUTPUT_FMT}"

  check_prereqs

  local secrets_json
  secrets_json="$(jq '.' "$secrets_file" 2>/dev/null)" \
    || fail "Invalid JSON in secrets file: ${secrets_file}"

  local key_count
  key_count="$(jq 'length' <<< "$secrets_json")"
  [[ "$key_count" -gt 0 ]] \
    || fail "Secrets file contains no key/value pairs: ${secrets_file}"

  validate_repo "$repo_path"

  FINDINGS_FILE="$(mktemp /tmp/secret-report.XXXXXX)"
  trap 'rm -f "$FINDINGS_FILE"' EXIT

  heading "Secret Exposure Scan"
  info "Repo       : ${repo_path}"
  info "Secrets    : ${key_count} key(s) from ${secrets_file}"
  info "Upstream   : $( [[ "$DO_FETCH" == "true" ]] && echo "fetch enabled (-u)" || echo "local refs only — add -u to fetch first" )"
  info "Depth      : $( [[ -n "$DEPTH" ]] && echo "last ${DEPTH} commits per ref (-n)" || echo "full history" )"
  [[ "$DO_SUBMODULES" == "true" ]] && info "Submodules : enabled (-m)"
  [[ "$DEBUG"         == "true" ]] && info "Debug      : enabled (-d)"

  info "Scanning..."

  scan_repo "$repo_path" "$secrets_json"

  if [[ "$DO_SUBMODULES" == "true" ]]; then
    scan_submodules "$repo_path" "$secrets_json"
  fi

  case "$OUTPUT_FMT" in
    pretty) render_pretty ;;
    json)   render_json   ;;
  esac
}

main "$@"

#!/usr/bin/env bash
# shellcheck shell=bash
#
#% description: report lines of code written since a given date/time in a git repository
#% usage: git-loc-since.sh [OPTIONS] <since>
#%
#% arguments:
#%   <since>   A git-compatible date/time string. Supported formats:
#%               "2 weeks ago"          relative
#%               "2026-01-01"           ISO date
#%               "2026-01-01T00:00:00"  ISO datetime
#%               "yesterday"            relative alias
#%               "last monday"          relative alias
#%               "@1700000000"          unix timestamp
#%
#% options:
#%   -a, --author <name>    Filter commits by author name or email (default: all authors)
#%   -b, --branch <branch>  Branch to inspect (default: current branch)
#%   -p, --path <path>      Limit stats to a subdirectory or file pattern
#%   -x, --extensions <ext> Comma-separated file extensions to include, e.g. "py,go,rs"
#%   -s, --summary          Print only the totals (no per-file breakdown)
#%   -j, --json             Output results as JSON
#%   -v, --verbose          Show each commit and its stats
#%   -h, --help             Show this help message and exit

set -euo pipefail

# ─── defaults ────────────────────────────────────────────────────────────────
SINCE=""
AUTHOR=""
BRANCH=""
PATH_FILTER=""
EXTENSIONS=""
SUMMARY_ONLY=0
JSON_OUTPUT=0
VERBOSE=0

# ─── helpers ─────────────────────────────────────────────────────────────────
usage() {
  grep '^#%' "$0" | sed 's/^#% \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    die "not inside a git repository"
  fi
}

# Check that 'since' is non-empty and accepted by git
validate_since() {
  local since="$1"
  [[ -z "$since" ]] && die "<since> argument is required"
  # git log will emit an error for an unrecognised date; we surface that here
  if ! git log --after="$since" --oneline -1 &>/dev/null 2>&1; then
    die "git does not recognise the date format: \"$since\""
  fi
}

# ─── argument parsing ─────────────────────────────────────────────────────────
parse_args() {
  local positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--author)
        [[ -z "${2-}" ]] && die "--author requires a value"
        AUTHOR="$2"; shift 2 ;;
      -b|--branch)
        [[ -z "${2-}" ]] && die "--branch requires a value"
        BRANCH="$2"; shift 2 ;;
      -p|--path)
        [[ -z "${2-}" ]] && die "--path requires a value"
        PATH_FILTER="$2"; shift 2 ;;
      -x|--extensions)
        [[ -z "${2-}" ]] && die "--extensions requires a value"
        EXTENSIONS="$2"; shift 2 ;;
      -s|--summary)
        SUMMARY_ONLY=1; shift ;;
      -j|--json)
        JSON_OUTPUT=1; shift ;;
      -v|--verbose)
        VERBOSE=1; shift ;;
      -h|--help)
        usage; exit 0 ;;
      --)
        shift; positional+=("$@"); break ;;
      -*)
        die "unknown option: $1" ;;
      *)
        positional+=("$1"); shift ;;
    esac
  done

  if [[ ${#positional[@]} -gt 0 ]]; then
    SINCE="${positional[0]}"
  fi
}

# ─── build extension filter (--  pathspec) ───────────────────────────────────
build_pathspec() {
  local -a specs=()

  if [[ -n "$PATH_FILTER" ]]; then
    specs+=("$PATH_FILTER")
  fi

  if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra exts <<< "$EXTENSIONS"
    for ext in "${exts[@]}"; do
      ext="${ext#.}"   # strip leading dot if provided
      ext="${ext// /}" # strip accidental spaces
      [[ -n "$ext" ]] && specs+=("*.${ext}")
    done
  fi

  echo "${specs[@]+"${specs[@]}"}"
}

# ─── collect stats ────────────────────────────────────────────────────────────
collect_stats() {
  local -a git_cmd=(git log --after="$SINCE" --pretty=tformat: --numstat)

  [[ -n "$AUTHOR"   ]] && git_cmd+=(--author="$AUTHOR")
  [[ -n "$BRANCH"   ]] && git_cmd+=("$BRANCH")

  local -a pathspec
  mapfile -t pathspec < <(build_pathspec | tr ' ' '\n')
  [[ ${#pathspec[@]} -gt 0 ]] && git_cmd+=(-- "${pathspec[@]}")

  "${git_cmd[@]}"
}

collect_verbose() {
  local -a git_cmd=(git log --after="$SINCE" --stat --no-merges)

  [[ -n "$AUTHOR" ]] && git_cmd+=(--author="$AUTHOR")
  [[ -n "$BRANCH" ]] && git_cmd+=("$BRANCH")

  local -a pathspec
  mapfile -t pathspec < <(build_pathspec | tr ' ' '\n')
  [[ ${#pathspec[@]} -gt 0 ]] && git_cmd+=(-- "${pathspec[@]}")

  "${git_cmd[@]}"
}

# ─── aggregate numstat output (tab-separated: added deleted filename) ─────────
aggregate() {
  local raw="$1"
  local total_added=0
  local total_deleted=0
  local total_net=0
  declare -A file_added file_deleted

  while IFS=$'\t' read -r added deleted file; do
    # skip binary files (git reports '-' for binary diffs)
    [[ "$added" == "-" || "$deleted" == "-" ]] && continue
    [[ -z "$file" ]] && continue

    total_added=$(( total_added + added ))
    total_deleted=$(( total_deleted + deleted ))
    file_added["$file"]=$(( ${file_added["$file"]:-0} + added ))
    file_deleted["$file"]=$(( ${file_deleted["$file"]:-0} + deleted ))
  done <<< "$raw"

  total_net=$(( total_added - total_deleted ))

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    output_json "$total_added" "$total_deleted" "$total_net" file_added file_deleted
  else
    output_text "$total_added" "$total_deleted" "$total_net" file_added file_deleted
  fi
}

output_text() {
  local total_added="$1" total_deleted="$2" total_net="$3"
  local -n _fa="$4" _fd="$5"

  if [[ "$SUMMARY_ONLY" -eq 0 ]]; then
    printf "%-60s  %8s  %8s  %8s\n" "file" "+added" "-deleted" "net"
    printf '%s\n' "$(printf '─%.0s' {1..95})"
    for file in $(printf '%s\n' "${!_fa[@]}" | sort); do
      local a="${_fa[$file]:-0}"
      local d="${_fd[$file]:-0}"
      local n=$(( a - d ))
      printf "%-60s  %+8d  %+8d  %+8d\n" "$file" "$a" "$(( -d ))" "$n"
    done
    printf '%s\n' "$(printf '─%.0s' {1..95})"
  fi

  printf "%-60s  %+8d  %+8d  %+8d\n" "TOTAL" "$total_added" "$(( -total_deleted ))" "$total_net"
}

output_json() {
  local total_added="$1" total_deleted="$2" total_net="$3"
  local -n __fa="$4" __fd="$5"

  echo "{"
  printf '  "since": "%s",\n' "$SINCE"
  [[ -n "$AUTHOR" ]] && printf '  "author": "%s",\n' "$AUTHOR"
  printf '  "total_added": %d,\n'   "$total_added"
  printf '  "total_deleted": %d,\n' "$total_deleted"
  printf '  "total_net": %d,\n'     "$total_net"

  if [[ "$SUMMARY_ONLY" -eq 0 ]]; then
    echo '  "files": {'
    local first=1
    for file in $(printf '%s\n' "${!__fa[@]}" | sort); do
      local a="${__fa[$file]:-0}"
      local d="${__fd[$file]:-0}"
      local n=$(( a - d ))
      [[ "$first" -eq 0 ]] && echo ","
      printf '    "%s": {"added": %d, "deleted": %d, "net": %d}' \
        "$file" "$a" "$d" "$n"
      first=0
    done
    printf '\n  }\n'
  fi

  echo "}"
}

# ─── main ─────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  require_git_repo
  validate_since "$SINCE"

  if [[ "$VERBOSE" -eq 1 ]]; then
    collect_verbose
    echo ""
  fi

  local raw
  raw="$(collect_stats)"

  if [[ -z "$raw" ]]; then
    echo "no commits found since \"$SINCE\"" >&2
    exit 0
  fi

  aggregate "$raw"
}

main "$@"

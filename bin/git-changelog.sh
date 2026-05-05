#!/usr/bin/env bash
# shellcheck shell=bash

##############################
# CHANGELOG SCRIPT CONSTANTS #
##############################

# Holds the list of valid types recognized in a commit subject
# and the display string of such type
declare -A TYPES
TYPES=(
  [build]="Build system"
  [chore]="Chore"
  [ci]="CI"
  [docs]="Documentation"
  [feat]="Features"
  [fix]="Bug fixes"
  [perf]="Performance"
  [refactor]="Refactor"
  [style]="Style"
  [test]="Testing"
)

# Types that will be displayed in their own section, in the order specified here.
MAIN_TYPES=(feat fix perf docs)

# Types that will be displayed under the category of other changes
OTHER_TYPES=(refactor style other)

# Commit types that don't appear in MAIN_TYPES nor OTHER_TYPES
# will not be displayed and will simply be ignored.
IGNORED_TYPES=()
_compute_ignored_types() {
  local key skip t
  for key in "${!TYPES[@]}"; do
    skip=0
    for t in "${MAIN_TYPES[@]}" "${OTHER_TYPES[@]}"; do
      if [[ "$key" == "$t" ]]; then
        skip=1
        break
      fi
    done
    if (( skip == 0 )); then
      IGNORED_TYPES+=("$key")
    fi
  done
}
_compute_ignored_types
unset -f _compute_ignored_types

############################
# COMMIT PARSING UTILITIES #
############################

# Repeat a character N times
_repeat_char() {
  local char="$1" n="$2" result="" i
  for (( i = 0; i < n; i++ )); do
    result+="$char"
  done
  printf '%s' "$result"
}

# Check if a key exists in TYPES
_type_exists() {
  [[ -n "${TYPES[$1]+set}" ]]
}

commit_type() {
  local subject="$1" type=""

  if [[ "$subject" =~ ^([a-zA-Z_-]+)(\(.+\))?!?:[[:space:]].+$ ]]; then
    type="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$type" ]] && _type_exists "$type"; then
    printf '%s' "$type"
  else
    printf 'other'
  fi
}

commit_scope() {
  local subject="$1" scope=""

  # Try to find scope in "type(<scope>):" format
  if [[ "$subject" =~ ^[a-zA-Z_-]+\((.+)\)!?:[[:space:]].+$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return
  fi

  # If no scope found, try to find it in "<scope>:" format
  if [[ "$subject" =~ ^([a-zA-Z_-]+):[[:space:]].+$ ]]; then
    scope="${BASH_REMATCH[1]}"
    if ! _type_exists "$scope"; then
      printf '%s' "$scope"
    fi
  fi
}

commit_subject() {
  local subject="$1"
  if [[ "$subject" =~ ^[a-zA-Z_-]+(\(.+\))?!?:[[:space:]](.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
  else
    printf '%s' "$subject"
  fi
}

# Sets _IS_BREAKING_MSG; returns 0 on match, 1 otherwise
commit_is_breaking() {
  local subject="$1" body="$2" message=""

  if [[ "$body" =~ BREAKING\ CHANGE:[[:space:]](.*) ]]; then
    message="${BASH_REMATCH[1]}"
  elif [[ "$subject" =~ ^[^\ :\)]+\)?!:[[:space:]](.*)$ ]]; then
    message="${BASH_REMATCH[1]}"
  else
    return 1
  fi

  message="${message//$'\r'/}"
  message="${message%%$'\n\n'*}"
  message="${message//$'\n'/ }"
  _IS_BREAKING_MSG="$message"
  return 0
}

# Sets _IS_REVERT_HASH; returns 0 on match, 1 otherwise
commit_is_revert() {
  local subject="$1" body="$2"

  if [[ "$subject" == Revert* ]] && \
     [[ "$body" =~ This\ reverts\ commit\ ([^.]+)\. ]]; then
    _IS_REVERT_HASH="${BASH_REMATCH[1]:0:7}"
    return 0
  fi
  return 1
}

parse_commit() {
  local hash="$1" subject="$2" body="$3"

  _types["$hash"]="$(commit_type "$subject")"
  _scopes["$hash"]="$(commit_scope "$subject")"
  _subjects["$hash"]="$(commit_subject "$subject")"

  _IS_BREAKING_MSG=""
  if commit_is_breaking "$subject" "$body"; then
    _breaking["$hash"]="$_IS_BREAKING_MSG"
  fi

  _IS_REVERT_HASH=""
  if commit_is_revert "$subject" "$body"; then
    _reverts["$hash"]="$_IS_REVERT_HASH"
  fi
}

#############################
# RELEASE CHANGELOG DISPLAY #
#############################

display_release() {
  local hash rhash

  # Remove commits that were reverted
  for hash in "${!_reverts[@]}"; do
    rhash="${_reverts[$hash]}"
    if [[ -n "${_types[$rhash]+set}" ]]; then
      unset "_types[$hash]" "_subjects[$hash]" "_scopes[$hash]" "_breaking[$hash]"
      unset "_types[$rhash]" "_subjects[$rhash]" "_scopes[$rhash]" "_breaking[$rhash]"
    fi
  done

  # Remove commits from ignored types unless they have breaking change info
  local ig is_ignored
  for hash in "${!_types[@]}"; do
    local t="${_types[$hash]}"
    is_ignored=0
    for ig in "${IGNORED_TYPES[@]}"; do
      if [[ "$t" == "$ig" ]]; then
        is_ignored=1
        break
      fi
    done
    if (( is_ignored )) && [[ -z "${_breaking[$hash]+set}" ]]; then
      unset "_types[$hash]" "_subjects[$hash]" "_scopes[$hash]"
    fi
  done

  if (( ${#_types[@]} == 0 )); then
    return
  fi

  # Get length of longest scope for padding
  local max_scope=0 slen
  for hash in "${!_scopes[@]}"; do
    slen="${#_scopes[$hash]}"
    (( slen > max_scope )) && max_scope=$slen
  done

  fmt_hash() {
    local h="${1:-$hash}"
    case "$output" in
    raw)  printf '%s' "$h" ;;
    text) printf '\e[33m%s\e[0m' "$h" ;;
    md)   printf '[`%s`](https://github.com/apsamuel/dot/commit/%s)' "$h" "$h" ;;
    esac
  }

  fmt_header() {
    local header="$1" level="$2" hlen="${#1}"
    case "$output" in
    raw)
      case "$level" in
      1) printf '%s\n%s\n\n' "$header" "$(_repeat_char '=' "$hlen")" ;;
      2) printf '%s\n%s\n\n' "$header" "$(_repeat_char '-' "$hlen")" ;;
      *) printf '%s:\n\n' "$header" ;;
      esac ;;
    text)
      case "$level" in
      1|2) printf '\e[1;4m%s\e[0m\n\n' "$header" ;;
      *)   printf '\e[1m%s:\e[0m\n\n' "$header" ;;
      esac ;;
    md)
      printf '%s %s\n\n' "$(_repeat_char '#' "$level")" "$header" ;;
    esac
  }

  fmt_scope() {
    local scope="${1:-${_scopes[$hash]}}"
    if (( max_scope == 0 )); then
      return
    fi
    local padding_n=$(( max_scope > ${#scope} ? max_scope - ${#scope} : 0 ))
    local padding
    padding="$(_repeat_char ' ' "$padding_n")"
    if [[ -z "$scope" ]]; then
      printf '%s   ' "$padding"
      return
    fi
    case "$output" in
    raw|md) printf '[%s]%s ' "$scope" "$padding" ;;
    text)   printf '[\e[38;5;9m%s\e[0m]%s ' "$scope" "$padding" ;;
    esac
  }

  fmt_subject() {
    local subject="${1:-${_subjects[$hash]}}"
    local first rest
    first="$(printf '%s' "${subject:0:1}" | tr '[:lower:]' '[:upper:]')"
    rest="${subject:1}"
    subject="${first}${rest}"
    case "$output" in
    raw)  printf '%s' "$subject" ;;
    text) printf '%s' "$subject" \
            | sed -E $'s|#([0-9]+)|\e[32m#\\1\e[0m|g;s|`([^`]+)`|`\e[2m\\1\e[0m`|g' ;;
    md)   printf '%s' "$subject" \
            | sed -E 's|#([0-9]+)|[#\1](https://github.com/apsamuel/dot/issues/\1)|g' ;;
    esac
  }

  fmt_type() {
    local t="${1:-$type}"
    local display
    if [[ -n "${TYPES[$t]+set}" ]]; then
      display="${TYPES[$t]}"
    else
      local first rest
      first="$(printf '%s' "${t:0:1}" | tr '[:lower:]' '[:upper:]')"
      rest="${t:1}"
      display="${first}${rest}"
    fi
    [[ -z "$display" ]] && return 0
    case "$output" in
    raw|md) printf '%s: ' "$display" ;;
    text)   printf '\e[4m%s\e[24m: ' "$display" ;;
    esac
  }

  display_version() {
    fmt_header "$version" 2
  }

  display_breaking() {
    (( ${#_breaking[@]} != 0 )) || return 0
    local cols="${COLUMNS:-80}"
    local wrap_width=$(( cols < 100 ? cols : 100 ))
    (( wrap_width -= 3 ))
    case "$output" in
    text) printf '\e[31m'; fmt_header "BREAKING CHANGES" 3 ;;
    raw)  fmt_header "BREAKING CHANGES" 3 ;;
    md)   fmt_header "BREAKING CHANGES ⚠" 3 ;;
    esac
    local h message
    for h in "${!_breaking[@]}"; do
      hash="$h"
      message="${_breaking[$h]}"
      message="$(printf '%s' "$message" | fmt -w "$wrap_width")"
      printf ' - %s %s\n\n%s\n\n' \
        "$(fmt_hash)" \
        "$(fmt_scope)" \
        "$(fmt_subject "$message" | sed 's/^/   /')"
    done
  }

  display_type() {
    local dtype="$1" h
    local -a hashes=()
    for h in "${!_types[@]}"; do
      [[ "${_types[$h]}" == "$dtype" ]] && hashes+=("$h")
    done
    (( ${#hashes[@]} != 0 )) || return 0
    fmt_header "${TYPES[$dtype]}" 3
    local lines=()
    for h in "${hashes[@]}"; do
      hash="$h"
      lines+=(" - $(fmt_hash) $(fmt_scope)$(fmt_subject)")
    done
    printf '%s\n' "${lines[@]}" | sort -k3
    echo
  }

  display_others() {
    local h ot is_other
    local -a other_hashes=()
    for h in "${!_types[@]}"; do
      local t="${_types[$h]}"
      is_other=0
      for ot in "${OTHER_TYPES[@]}"; do
        if [[ "$t" == "$ot" ]]; then
          is_other=1
          break
        fi
      done
      (( is_other )) && other_hashes+=("$h")
    done
    (( ${#other_hashes[@]} != 0 )) || return 0
    fmt_header "Other changes" 3
    local lines=()
    for h in "${other_hashes[@]}"; do
      hash="$h"
      local t="${_types[$h]}"
      if [[ "$t" == "other" ]]; then
        lines+=(" - $(fmt_hash) $(fmt_scope)$(fmt_subject)")
      else
        type="$t"
        lines+=(" - $(fmt_hash) $(fmt_scope)$(fmt_type)$(fmt_subject)")
      fi
    done
    printf '%s\n' "${lines[@]}" | sort -k3
    echo
  }

  display_version
  display_breaking

  local type
  for type in "${MAIN_TYPES[@]}"; do
    display_type "$type"
  done

  display_others
}

main() {
  local until="$1" since="$2"
  local raw_output="${3:---text}"
  local output="${raw_output#--}"

  [[ -z "$until" ]] && until=HEAD

  if [[ -z "$since" ]]; then
    since=$(command git config --get oh-my-zsh.lastVersion 2>/dev/null) \
      || since=$(command git describe --abbrev=0 --tags "${until}^" 2>/dev/null) \
      || since=""
  elif [[ "$since" == "--all" ]]; then
    since=""
  fi

  declare -A _types _subjects _scopes _breaking _reverts
  local truncate=0 read_commits=0
  local version tag hash refs subject body

  version=$(command git describe --tags "$until" 2>/dev/null) \
    || version=$(command git symbolic-ref --quiet --short "$until" 2>/dev/null) \
    || version=$(command git name-rev --no-undefined --name-only --exclude="remotes/*" "$until" 2>/dev/null) \
    || version=$(command git rev-parse --short "$until" 2>/dev/null)

  local range
  if [[ -n "$since" ]]; then
    range="${since}..${until}"
  else
    range="$until"
  fi

  local SEP="0mZmAgIcSeP"
  local -a raw_commits=()
  local raw_commit

  while IFS= read -r -d '' raw_commit; do
    raw_commits+=("$raw_commit")
  done < <(command git -c log.showSignature=false log -z \
    --format="%h${SEP}%D${SEP}%s${SEP}%b" --abbrev=7 \
    --no-merges --first-parent "$range")

  for raw_commit in "${raw_commits[@]}"; do
    if [[ -z "$since" ]] && (( ++read_commits > 35 )); then
      truncate=1
      break
    fi

    # Split raw_commit on SEP
    local -a raw_fields=()
    local remaining="$raw_commit"
    while [[ "$remaining" == *"$SEP"* ]]; do
      raw_fields+=("${remaining%%"$SEP"*}")
      remaining="${remaining#*"$SEP"}"
    done
    raw_fields+=("$remaining")

    hash="${raw_fields[0]}"
    refs="${raw_fields[1]}"
    subject="${raw_fields[2]}"
    body="${raw_fields[3]}"

    if [[ "$refs" == *"tag: "* ]]; then
      tag="${refs##*tag: }"
      tag="${tag%%,*}"
      tag="${tag%% *}"

      display_release
      unset _types _subjects _scopes _breaking _reverts
      declare -A _types _subjects _scopes _breaking _reverts
      version="$tag"
      read_commits=1
    fi

    parse_commit "$hash" "$subject" "$body"
  done

  display_release

  if (( truncate )); then
    echo " ...more commits omitted"
    echo
  fi
}

# Use raw output if stdout is not a tty
if [[ ! -t 1 && -z "$3" ]]; then
  main "$1" "$2" --raw
else
  main "$@"
fi

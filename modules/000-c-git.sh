#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_GIT}" -eq 1 ]]; then
    dot::static::logging::skip "git" "disabled"
    return
fi

DOT_GIT_DEFAULT_MERGE_BRANCH=1
DOT_GIT_DEFAULT_REBASE_BRANCH=0
DOT_GIT_DEFAULT_STASH_COMMITS=0
DOT_GIT_DEFAULT_SOURCE_BRANCH="main"
DOT_GIT_DEFAULT_DESTINATION_BRANCH="staging"
DOT_GIT_DEFAULT_USER="apsamuel"
DOT_GIT_DEFAULT_EMAIL="aaron.psamuel@gmail.com"

dot::git::help() {
    local usage="" purpose=""
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::git <command> [args]' 'Commands: auth, config, changes, diff, preview, log' 'Use dot::git help <command> for details.'; return ;;
        auth) purpose='Authenticate gh using GH_TOKEN when set, otherwise gh interactive login. Writes authentication state; no retry.' ;;
        config) usage='[-g] [-u user] [-e email]'; purpose='Write git identity configuration (local by default; -g selects global). Uses module defaults when omitted.' ;;
        changes) purpose='Print a compact, dated git log.' ;;
        diff) usage='[git-diff-args...]'; purpose='Select changed paths with fzf. Arguments are forwarded to git diff.' ;;
        preview) purpose='Preview stdin commit entries with fzf; bat is optional.' ;;
        log) purpose='Browse git log with fzf previews.' ;;
        *) printf 'dot::git: unknown help topic: %s\n' "$1" >&2; return 1 ;;
    esac
    printf '%s\n' "${purpose}"
    printf 'Usage: dot::git %s %s\n       dot::git::%s %s\n' "$1" "${usage}" "$1" "${usage}"
    printf '%s\n' 'Options: -h, --help. Requires git; auth requires gh; selectors require fzf.' 'Help never reads tokens or changes state. Invalid input returns 1; backend failures are nonzero.'
    printf 'Example: dot::git help %s\n' "$1"
}

dot::git() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::git::help "$@" ;;
        auth) dot::git::auth "$@" ;;
        config) dot::git::config "$@" ;;
        changes) dot::git::changes "$@" ;;
        diff) dot::git::diff "$@" ;;
        preview) dot::git::preview "$@" ;;
        log) dot::git::log "$@" ;;
        *) printf 'dot::git: unknown command: %s\n' "${action}" >&2; return 1 ;;
    esac
}

dot::git::_require() {
    local tool=""
    for tool in "$@"; do
        command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::git: %s is required\n' "${tool}" >&2; return 1; }
    done
}

dot::git::auth() {
    case "${1:-}" in -h|--help) dot::git::help auth; return ;; esac
    [[ $# -eq 0 ]] || { dot::git::help auth >&2; return 1; }
    dot::git::_require gh || return $?
    # If GH_TOKEN is set (from secrets), inject it; otherwise fall back to interactive
    if [[ -n "${GH_TOKEN:-}" ]]; then
        printf '%s\n' "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || return $?
        echo "gh: authenticated via GH_TOKEN"
    else
        gh auth login
    fi
}

dot::git::config() {
    case "${1:-}" in -h|--help) dot::git::help config; return ;; esac

    # use getops to parse arguments to this function
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    local global=0 OPTIND=1 OPTARG="" opt=""
    local user="${DOT_GIT_DEFAULT_USER}" email="${DOT_GIT_DEFAULT_EMAIL}"
    while getopts ":gu:e:h" opt; do
        case ${opt} in
            u ) # process option u
                user=$OPTARG
                ;;
            e ) # process option e
                email=$OPTARG
                ;;
            g ) # process option g
                global=1
                ;;
            h) dot::git::help config; return ;;
            *) dot::git::help config >&2; return 1 ;;
        esac
    done

    shift $((OPTIND - 1))
    [[ $# -eq 0 && -n "${user}" && -n "${email}" ]] || { dot::git::help config >&2; return 1; }
    dot::git::_require git || return $?
    DOT_GIT_DEFAULT_USER="${user}"
    DOT_GIT_DEFAULT_EMAIL="${email}"
    if [[ $global -eq 1 ]]; then
        echo "git config --global user.name $DOT_GIT_DEFAULT_USER"
        git config --global user.name "$DOT_GIT_DEFAULT_USER" || return $?
        echo "git config --global user.DOT_GIT_DEFAULT_EMAIL $DOT_GIT_DEFAULT_EMAIL"
        git config --global user.DOT_GIT_DEFAULT_EMAIL "$DOT_GIT_DEFAULT_EMAIL"
    else
        echo "git config user.name $DOT_GIT_DEFAULT_USER"
        git config user.name "$DOT_GIT_DEFAULT_USER" || return $?
        echo "git config user.DOT_GIT_DEFAULT_EMAIL $DOT_GIT_DEFAULT_EMAIL"
        git config user.DOT_GIT_DEFAULT_EMAIL "$DOT_GIT_DEFAULT_EMAIL"
    fi
}

dot::git::changes() {
    case "${1:-}" in -h|--help) dot::git::help changes; return ;; esac
    [[ $# -eq 0 ]] || { dot::git::help changes >&2; return 1; }
    dot::git::_require git || return $?
    git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --date=short
}

dot::git::diff() {
    case "${1:-}" in -h|--help) dot::git::help diff; return ;; esac
    dot::git::_require git fzf || return $?
    local preview='git diff --color=always' argument=""
    for argument in "$@"; do
        [[ "${argument}" != -- ]] || break
        preview+=" $(printf '%q' "${argument}")"
    done
    preview+=' -- {}'
    (set -o pipefail; git diff --name-only "$@" | fzf -m --ansi --preview "$preview" --preview-window=right:70%:wrap)
}

dot::git::preview() {
    case "${1:-}" in -h|--help) dot::git::help preview; return ;; esac
    [[ $# -eq 0 ]] || { dot::git::help preview >&2; return 1; }
    dot::git::_require git fzf || return $?
    local preview='git show {1}'
    command -v bat >/dev/null 2>&1 && preview+=' | bat --color=always'
    fzf --preview "${preview}"
}

dot::git::log() {
    case "${1:-}" in -h|--help) dot::git::help log; return ;; esac
    [[ $# -eq 0 ]] || { dot::git::help log >&2; return 1; }
    dot::git::_require git fzf || return $?
    (set -o pipefail; git log --color=always --pretty=format:"%C(yellow)%h %C(reset)%ad (%C(green)%cr%C(reset))%x09%C(cyan)%an%C(reset): %s" --date=short | fzf --ansi --preview "echo {} | cut -d' ' -f1 | xargs git show --color=always" --preview-window=up:30%:wrap)
}


export DOT_GIT_DEFAULT_MERGE_BRANCH DOT_GIT_DEFAULT_REBASE_BRANCH DOT_GIT_DEFAULT_STASH_COMMITS DOT_GIT_DEFAULT_SOURCE_BRANCH DOT_GIT_DEFAULT_DESTINATION_BRANCH DOT_GIT_DEFAULT_USER DOT_GIT_DEFAULT_EMAIL

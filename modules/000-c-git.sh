#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

dot::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_GIT}" -eq 1 ]]; then
    dot::skip "git" "disabled"
    return
fi

DOT_GIT_DEFAULT_MERGE_BRANCH=1
DOT_GIT_DEFAULT_REBASE_BRANCH=0
DOT_GIT_DEFAULT_STASH_COMMITS=0
DOT_GIT_DEFAULT_SOURCE_BRANCH="main"
DOT_GIT_DEFAULT_DESTINATION_BRANCH="staging"
DOT_GIT_DEFAULT_USER="apsamuel"
DOT_GIT_DEFAULT_EMAIL="aaron.psamuel@gmail.com"

ghAuth() {
    # If GH_TOKEN is set (from secrets), inject it; otherwise fall back to interactive
    if [[ -n "${GH_TOKEN}" ]]; then
        echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null \
            && echo "gh: authenticated via GH_TOKEN" \
            || echo "gh: already authenticated"
    else
        gh auth login
    fi
}

gitConfig() {

    # use getops to parse arguments to this function
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    export global=0
    while getopts ":g:u:e:" opt; do
        case ${opt} in
            u ) # process option u
                DOT_GIT_DEFAULT_USER=$OPTARG
                echo "DOT_GIT_DEFAULT_USER: $DOT_GIT_DEFAULT_USER"
                ;;
            e ) # process option e
                DOT_GIT_DEFAULT_EMAIL=$OPTARG
                echo "DOT_GIT_DEFAULT_EMAIL: $DOT_GIT_DEFAULT_EMAIL"
                ;;
            g ) # process option g
                global=1
                echo "global mode"
                ;;
            \? ) echo "Usage: cmd [-g] [-f filename]" 1>&2
                ;;
        esac
    done

    if [[ $global -eq 1 ]]; then
        echo "git config --global user.name $DOT_GIT_DEFAULT_USER"
        git config --global user.name "$DOT_GIT_DEFAULT_USER"
        echo "git config --global user.DOT_GIT_DEFAULT_EMAIL $DOT_GIT_DEFAULT_EMAIL"
        git config --global user.DOT_GIT_DEFAULT_EMAIL "$DOT_GIT_DEFAULT_EMAIL"
    else
        echo "git config user.name $DOT_GIT_DEFAULT_USER"
        git config user.name "$DOT_GIT_DEFAULT_USER"
        echo "git config user.DOT_GIT_DEFAULT_EMAIL $DOT_GIT_DEFAULT_EMAIL"
        git config user.DOT_GIT_DEFAULT_EMAIL "$DOT_GIT_DEFAULT_EMAIL"
    fi
}

gitChanges() {
    git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s" --date=short
}

gitDiff() {
    preview="git diff $* --color=always -- {-1}"
    git diff --name-only | fzf -m --ansi --preview "$preview"
}

gitPreview() {
    fzf --preview "git show {1} | bat --color=always"
}

gitLog() {
    git log --color=always --pretty=format:"%C(yellow)%h %C(reset)%ad (%C(green)%cr%C(reset))%x09%C(cyan)%an%C(reset): %s" --date=short | fzf --ansi --preview "echo {} | cut -d' ' -f1 | xargs git show --color=always" --preview-window=up:30%:wrap
}


export DOT_GIT_DEFAULT_MERGE_BRANCH DOT_GIT_DEFAULT_REBASE_BRANCH DOT_GIT_DEFAULT_STASH_COMMITS DOT_GIT_DEFAULT_SOURCE_BRANCH DOT_GIT_DEFAULT_DESTINATION_BRANCH DOT_GIT_DEFAULT_USER DOT_GIT_DEFAULT_EMAIL

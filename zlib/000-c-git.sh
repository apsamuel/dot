#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
if [[ "${DOT_CONFIGURE_GIT}" -eq 0 ]]; then
    return
fi

DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

DOT_GIT_DEFAULT_MERGE_BRANCH=1
DOT_GIT_DEFAULT_REBASE_BRANCH=0
DOT_GIT_DEFAULT_STASH_COMMITS=0
DOT_GIT_DEFAULT_SOURCE_BRANCH="main"
DOT_GIT_DEFAULT_DESTINATION_BRANCH="staging"
DOT_GIT_DEFAULT_USER="apsamuel"
DOT_GIT_DEFAULT_EMAIL="aaron.psamuel@gmail.com"

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

# git::noop::sync() {
#     remote="origin"
#     DOT_GIT_DEFAULT_SOURCE_BRANCH="main"
#     DOT_GIT_DEFAULT_DESTINATION_BRANCH="staging"
#     DOT_GIT_DEFAULT_MERGE_BRANCH=1
#     DOT_GIT_DEFAULT_REBASE_BRANCH=0
#     current_branch=$(git branch --show-current)
#     # use getops to merge or DOT_GIT_DEFAULT_REBASE_BRANCH
#     while getopts ":mrS:s:d:R:" opt; do
#         case ${opt} in
#             m ) # process option m
#                 #echo "merging"
#                 DOT_GIT_DEFAULT_MERGE_BRANCH=1
#                 ;;
#             r ) # process option r
#                 #echo "rebasing"
#                 DOT_GIT_DEFAULT_REBASE_BRANCH=1
#                 ;;
#             #stash
#             S ) # process option S
#                 echo "stash: $OPTARG"
#                 DOT_GIT_DEFAULT_STASH_COMMITS=1
#                 ;;
#             s ) # process option s
#                 echo "source branch: $OPTARG"
#                 DOT_GIT_DEFAULT_SOURCE_BRANCH=$OPTARG
#                 ;;
#             d ) # process option d
#                 echo "destination branch: $OPTARG"
#                 DOT_GIT_DEFAULT_DESTINATION_BRANCH=$OPTARG
#                 ;;
#             R ) # process option R
#                 echo "remote: $OPTARG"
#                 remote=$OPTARG
#                 ;;
#             \? ) echo "Usage: cmd [-m] [-r]" 1>&2
#                 ;;
#         esac
#     done

#     # do not operate on main directly
#     if [[ "$current_branch" == "$DOT_GIT_DEFAULT_SOURCE_BRANCH" ]]; then
#         echo "please checkout an active development branch before using this command"
#         return 1
#     fi

#     # check in or stash changes if there are any
#     if [[ $(git status --porcelain) ]]; then
#         echo "there are changes in the working directory"
#         if [[ $DOT_GIT_DEFAULT_STASH_COMMITS -eq 1 ]]; then
#             git stash
#         else
#             commit_message="chore: sync $DOT_GIT_DEFAULT_SOURCE_BRANCH to $DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#             git add .
#             git commit -m "$commit_message"
#             return 1
#         fi
#     else
#         echo "there are no changes in the working directory"
#     fi



#     if [[ $DOT_GIT_DEFAULT_MERGE_BRANCH -eq 1 ]]; then
#         echo "merging $DOT_GIT_DEFAULT_SOURCE_BRANCH $DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#         git checkout "$DOT_GIT_DEFAULT_SOURCE_BRANCH"
#         git pull
#         git checkout "$DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#         git merge "$remote"/"$DOT_GIT_DEFAULT_SOURCE_BRANCH"
#         git merge "$DOT_GIT_DEFAULT_SOURCE_BRANCH" "$DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#     elif [[ $DOT_GIT_DEFAULT_REBASE_BRANCH -eq 1 ]]; then
#         echo "git rebasing $DOT_GIT_DEFAULT_SOURCE_BRANCH $DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#         git checkout "$DOT_GIT_DEFAULT_SOURCE_BRANCH"
#         git pull
#         git checkout "$DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#         git rebase "$remote"/"$DOT_GIT_DEFAULT_SOURCE_BRANCH"
#         git DOT_GIT_DEFAULT_REBASE_BRANCH "$DOT_GIT_DEFAULT_SOURCE_BRANCH" "$DOT_GIT_DEFAULT_DESTINATION_BRANCH"
#     fi
# }


export DOT_GIT_DEFAULT_MERGE_BRANCH DOT_GIT_DEFAULT_REBASE_BRANCH DOT_GIT_DEFAULT_STASH_COMMITS DOT_GIT_DEFAULT_SOURCE_BRANCH DOT_GIT_DEFAULT_DESTINATION_BRANCH DOT_GIT_DEFAULT_USER DOT_GIT_DEFAULT_EMAIL
# export -f git::config git::changelog
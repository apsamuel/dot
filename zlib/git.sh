#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

merge_branch=1
rebase_branch=0
stash_commit=0
source_branch="main"
destination_branch="staging"
username="apsamuel"
email="aaron.psamuel@gmail.com"

git::config() {

    # use getops to parse arguments to this function
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    export global=0
    while getopts ":g:u:e:" opt; do
        case ${opt} in
            u ) # process option u
                username=$OPTARG
                echo "username: $username"
                ;;
            e ) # process option e
                email=$OPTARG
                echo "email: $email"
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
        echo "git config --global user.name $username"
        git config --global user.name "$username"
        echo "git config --global user.email $email"
        git config --global user.email "$email"
    else
        echo "git config user.name $username"
        git config user.name "$username"
        echo "git config user.email $email"
        git config user.email "$email"
    fi
}

git::noop::sync-dev() {

    remote="origin"
    source_branch="main"
    destination_branch="staging"
    merge_branch=1
    rebase_branch=0
    # use getops to merge or rebase_branch
    while getopts ":mrS:s:d:R:" opt; do
        case ${opt} in
            m ) # process option m
                #echo "merging"
                merge_branch=1
                ;;
            r ) # process option r
                #echo "rebasing"
                rebase_branch=1
                ;;
            #stash
            S ) # process option S
                echo "stash: $OPTARG"
                stash_commit=1
                ;;
            s ) # process option s
                echo "source branch: $OPTARG"
                source_branch=$OPTARG
                ;;
            d ) # process option d
                echo "destination branch: $OPTARG"
                destination_branch=$OPTARG
                ;;
            R ) # process option R
                echo "remote: $OPTARG"
                remote=$OPTARG
                ;;
            \? ) echo "Usage: cmd [-m] [-r]" 1>&2
                ;;
        esac
    done

    if [[ $merge_branch -eq 1 ]]; then
        echo "merging $source_branch $destination_branch"
        # check if the branch is currently dirty, if so, stash it
        git checkout "$source_branch"
        git pull
        git checkout "$destination_branch"
        #git merge "$remote"/"$source_branch"
        #git merge "$source_branch" "$destination_branch"
    elif [[ $rebase_branch -eq 1 ]]; then
        echo "git rebasing $source_branch $destination_branch"
        git checkout "$source_branch"
        git pull
        git checkout "$destination_branch"
        #git rebase "$remote"/"$source_branch"
        #git rebase_branch "$source_branch" "$destination_branch"
    fi
}
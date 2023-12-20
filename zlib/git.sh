#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

username="apsamuel"
email="aaron.psamuel@gmail.com"

git::config() {

    # use getops to parse arguments to this function
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    export git_global_config=0
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
                git_global_config=1
                echo "global mode"
                ;;
            \? ) echo "Usage: cmd [-g] [-f filename]" 1>&2
                ;;
        esac
    done

    if [[ $git_global_config -eq 1 ]]; then
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

git::noop::sync() {
    remote="origin"
    source_branch="main"
    destination_branch="staging"
    merge=1
    rebase=0
    # use getops to merge or rebase
    while getopts ":mr:s:d:R:" opt; do
        case ${opt} in
            m ) # process option m
                #echo "merging"
                merge=1
                ;;
            r ) # process option r
                #echo "rebasing"
                rebase=1
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

    if [[ $merge -eq 1 ]]; then
        echo "git merge $source_branch $destination_branch"
        git checkout "$source_branch"
        git pull
        git checkout "$destination_branch"
        git merge "$remote"/"$source_branch"
        #git merge "$source_branch" "$destination_branch"
    elif [[ $rebase -eq 1 ]]; then
        echo "git rebase $source_branch $destination_branch"
        git checkout "$source_branch"
        git pull
        git checkout "$destination_branch"
        git rebase "$remote"/"$source_branch"
        #git rebase "$source_branch" "$destination_branch"
    fi
}
#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi


# enable zsh completions
autoload -U +X bashcompinit && bashcompinit

# ensure that brew is a function so we can use it to find completions
if type brew &>/dev/null; then

    # load zsh completions
    if [ -d "$(brew --prefix)/share/zsh-completions" ]; then
        FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
        autoload -Uz compinit
        compinit
    fi


    if command -v git-extras &>/dev/null; then
        if [ -f "$(brew --prefix git-extras)/share/git-extras/git-extras-completion.zsh" ]; then
            source "$(brew --prefix git-extras)/share/git-extras/git-extras-completion.zsh"
        fi
    fi
fi

# ngrok completions
if command -v ngrok &>/dev/null; then
    eval "$(ngrok completion)"
fi

# # load launchctl completions
if [ -f "${HOMEBREW_CELLAR}"/launchctl-completion/1.0/etc/bash_completion.d/launchctl ]; then
    # shellcheck source=/dev/null
    source "${HOMEBREW_CELLAR}"/launchctl-completion/1.0/etc/bash_completion.d/launchctl
fi

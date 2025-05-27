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

# load zsh completions
if type brew &>/dev/null; then
    if [ -d "$(brew --prefix)/share/zsh-completions" ]; then
        FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
        autoload -Uz compinit
        compinit
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

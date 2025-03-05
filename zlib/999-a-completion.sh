#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi


# enable zsh completions
autoload -U +X bashcompinit && bashcompinit

# load zsh completions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

if command -v ngrok &>/dev/null; then
    eval "$(ngrok completion)"
fi

# # load launchctl completions
source /usr/local/Cellar/launchctl-completion/1.0/etc/bash_completion.d/launchctl

# load twilio cli completions
TWILIO_AC_ZSH_SETUP_PATH=/Users/aaronsamuel/.twilio-cli/autocomplete/zsh_setup
test -f "$TWILIO_AC_ZSH_SETUP_PATH" && source "$TWILIO_AC_ZSH_SETUP_PATH"; # twilio autocomplete setup
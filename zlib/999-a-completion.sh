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
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
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


# conditionally load twilio cli completions
TWILIO_AC_ZSH_SETUP_PATH="${HOME}/.twilio-cli/autocomplete/zsh_setup"
if [[ -f "$TWILIO_AC_ZSH_SETUP_PATH" ]]; then
    source "$TWILIO_AC_ZSH_SETUP_PATH" # twilio autocomplete setup
fi
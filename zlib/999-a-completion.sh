#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null

# enable zsh completions
autoload -U +X bashcompinit && bashcompinit

# load zsh completions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

# # load launchctl completions
source /usr/local/Cellar/launchctl-completion/1.0/etc/bash_completion.d/launchctl

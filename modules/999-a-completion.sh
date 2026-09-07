#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"


# Initialize the zsh completion system FIRST — loads zsh/computil (comptags,
# comptry, ...) so completion helpers like _tags work. Must run before
# bashcompinit, which assumes compinit has already run.
autoload -Uz compinit
compinit

# bash-style completion shims (complete/compgen) — require compinit first
autoload -U +X bashcompinit && bashcompinit

# ensure that brew is a function so we can use it to find completions
if type brew &>/dev/null; then

    # add brew's extra completions to FPATH and re-scan
    if [ -d "$(brew --prefix)/share/zsh-completions" ]; then
        FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
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

# shellcheck shell=bash
# shellcheck source=/dev/null



# if [[ "${DOT_CONFIGURE_POWERLEVEL}" -eq 0 ]]; then
#     return
# fi

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

if [[ "${DOT_DISABLE_P10K}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "powerlevel10k is disabled"
    fi
    return
fi

export POWERLEVEL9K_INSTANT_PROMPT=quiet
export POWERLEVEL9K_INSTANT_PROMPT=off
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f "$HOME"/.p10k.zsh ]] || source "$HOME"/.p10k.zsh


# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

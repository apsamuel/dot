# shellcheck shell=bash
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::loading "${library}" "${directory}"


if [[ "${DOT_DISABLE_P10K}" -eq 1 ]]; then
    dot::skip "powerlevel10k" "disabled"
    return
fi

# check if powerlevel10k is instlled as a ZSH theme ZSH_CUSTOM/themes/powerlevel10k
if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
    dot::debug "powerlevel10k is not installed"
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

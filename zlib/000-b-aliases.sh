# shellcheck shell=bash
#% description: define aliases

if [[ "${DOT_CONFIGURE_ALIASES}" -eq 0 ]]; then
    return
fi

alias cat='bat'
alias ls='ls --color=always'
alias less='bat --paging=always'
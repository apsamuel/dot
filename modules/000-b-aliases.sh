# shellcheck shell=bash
#% description: define aliases


alias ls='ls --color=always'

# Opt-in syntax highlighting — use these interactively; never set as defaults
# because bat-as-cat/less breaks piped automation and pager detection.
alias ccat='bat --paging=never'   # syntax-highlighted cat (no pager)
alias cless='bat --paging=always' # syntax-highlighted pager

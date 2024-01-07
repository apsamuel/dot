#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")



if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi
source "${directory}"/mac.sh
FOO=bar
BAR=baz


## alias definitions
alias cat='bat'
alias ls='ls --color=always'
alias less='bat --paging=always'

export FOO BAR

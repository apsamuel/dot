#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

# source fzf-git shell integration from vendor
if [[ -n "${DOT_ROOT}" && -f "${DOT_ROOT}/vendor/fzf-git/fzf-git.sh" ]]; then
    source "${DOT_ROOT}/vendor/fzf-git/fzf-git.sh"
fi
#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

# source fzf-git shell integration from the vendored submodule, if it exists
if [[ -n "${DOT_ROOT}" && -f "${DOT_ROOT}/vendor/fzf-git/fzf-git.sh" ]]; then
    source "${DOT_ROOT}/vendor/fzf-git/fzf-git.sh"
fi

# source bash-commons from the vendored submodule, if it exists
if [[ -n "${DOT_ROOT}" && -f "${DOT_ROOT}/vendor/bash-commons/src" ]]; then
    # source "${DOT_ROOT}/vendor/bash-commons/modules/install.sh"
    source "${DOT_ROOT}/vendor/bash-commons/src/log.sh"
    source "${DOT_ROOT}/vendor/bash-commons/src/assert.sh"
    source "${DOT_ROOT}/vendor/bash-commons/src/os.sh"
    source "${DOT_ROOT}/vendor/bash-commons/src/string.sh"
fi

# The next line updates PATH for the Google Cloud SDK.
#source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
# The next line enables shell command completion for gcloud.
#source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

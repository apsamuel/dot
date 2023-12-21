# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

ANACONDA_DIR=/usr/local/anaconda3
# conditionally set the anaconda directory based on architecture

if [[ $(uname -m) == "x86_64" ]]; then
    export ANACONDA_DIR=/usr/local/anaconda3
else
    export ANACONDA_DIR=/opt/homebrew/anaconda3
fi


__conda_setup="$($ANACONDA_DIR/bin/conda 'shell.zsh' 'hook' 2>/dev/null)"
if $ANACONDA_DIR/bin/conda 'shell.zsh' 'hook' >/dev/null 2>&1 ; then
    eval "$__conda_setup" >/dev/null 2>&1
else
    if [ -f "${ANACONDA_DIR}/etc/profile.d/conda.sh" ]; then
        . "${ANACONDA_DIR}/etc/profile.d/conda.sh"
    else
        export PATH="${ANACONDA_DIR}/bin:$PATH"
    fi
fi
unset __conda_setup

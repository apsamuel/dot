# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# DOT_DEBUG="${DOT_DEBUG:-0}"
# DOT_DIRECTORY=$(dirname "$0")
# DOT_LIBRARY=$(basename "$0")

# if [[ "${DOT_CONFIGURE_ANACONDA}" -eq 0 ]]; then
#     return
# fi

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi


if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

# ANACONDA_DIR=/usr/local/anaconda3
# conditionally set the anaconda DOT_DIRECTORY based on architecture
if [[ $(uname -m) == "x86_64" ]]; then
    export ANACONDA_DIR=/usr/local/anaconda3
else
    export ANACONDA_DIR=/opt/homebrew/anaconda3
fi

## allow disabling anaconda
if [[ "${DOT_DISABLE_ANACONDA}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "anaconda is disabled"
    fi
else

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

    # activate base conda environment
    conda activate base
fi
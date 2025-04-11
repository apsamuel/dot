# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
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

    # TODO: conditionally exit if anaconda is not installed
    if [ ! -d "${ANACONDA_DIR}" ]; then
        echo "Anaconda is not installed at ${ANACONDA_DIR}. Exiting."
        # exit 1
        return
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

    # activate base conda environment
    conda activate base
fi
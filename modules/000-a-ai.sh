#shellcheck shell=bash
#% description: base variables and functions

## configures lmstudio CLI if it exists
# check if ~/.lmsstudio/bin exists and add it to the PATH
if [[ -d "${HOME}/.lmstudio/bin" ]]; then
    export PATH="${PATH}:${HOME}/.lmstudio/bin"
fi

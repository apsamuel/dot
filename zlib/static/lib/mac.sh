#shellcheck shell=bash
#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

getProcessorCores() {
    sysctl -n machdep.cpu.core_count
}

getProcessorBrand() {
    sysctl -n machdep.cpu.brand_string
}
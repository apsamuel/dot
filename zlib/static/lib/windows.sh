#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

getProcessorCores() {
    sysctl -n machdep.cpu.core_count
}

getProcessorBrand() {
    sysctl -n machdep.cpu.brand_string
}
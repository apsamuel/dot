#shellcheck shell=bash
#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

dot::static::foundation::cpu-cores() {
    sysctl -n machdep.cpu.core_count
}

dot::static::foundation::cpu-brand() {
    sysctl -n machdep.cpu.brand_string
}
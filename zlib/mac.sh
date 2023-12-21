#shellcheck shell=bash
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

osx::cpu::cores() {
    sysctl -n machdep.cpu.core_count
}

osx::cpu::brand() {
    sysctl -n machdep.cpu.brand_string
}
#shellcheck shell=bash
# DOT_DEBUG="${DOT_DEBUG:-0}"
# DOT_DIRECTORY=$(dirname "$0")
# DOT_LIBRARY=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

osx::cpu::cores() {
    sysctl -n machdep.cpu.core_count
}

osx::cpu::brand() {
    sysctl -n machdep.cpu.brand_string
}
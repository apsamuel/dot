#shellcheck shell=bash


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi


if [[ "${DOT_DISABLE_MAC}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "mac is disabled"
    fi
    return
fi

osx::cpu::cores() {
    sysctl -n machdep.cpu.core_count
}

osx::cpu::brand() {
    sysctl -n machdep.cpu.brand_string
}
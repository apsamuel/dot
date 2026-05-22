#shellcheck shell=bash


directory=$(dirname "$0")
library=$(basename "$0")

dot::loading "${library}" "${directory}"


if [[ "${DOT_DISABLE_MAC}" -eq 1 ]]; then
    dot::skip "mac" "disabled"
    return
fi

osCpuCores() {
    sysctl -n machdep.cpu.core_count
}

osCpuBrand() {
    sysctl -n machdep.cpu.brand_string
}

# blah
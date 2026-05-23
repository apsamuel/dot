#shellcheck shell=bash


directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"


if [[ "${DOT_DISABLE_MAC}" -eq 1 ]]; then
    dot::static::logging::skip "mac" "disabled"
    return
fi

dot::mac::cpu-cores() {
    sysctl -n machdep.cpu.core_count
}

dot::mac::cpu-brand() {
    sysctl -n machdep.cpu.brand_string
}

# blah
#shellcheck shell=bash

# these values are exported early and available to shells and scripts
CPU_BRAND="$(sysctl -n machdep.cpu.brand_string)"
CPU_FEATURES="$(sysctl -n machdep.cpu.features)"
CPU_CORES="$(sysctl -n machdep.cpu.core_count)"
OPERATING_SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
CPU_ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')

export CPU_ARCHITECTURE OPERATING_SYSTEM CPU_BRAND CPU_FEATURES CPU_CORES
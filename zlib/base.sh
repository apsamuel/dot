#shellcheck shell=bash

# these values are exported early and available to shells and scripts
CPU_BRAND="$(sysctl -n machdep.cpu.brand_string)"
CPU_FEATURES="$(sysctl -n machdep.cpu.features)"
CPU_CORES="$(sysctl -n machdep.cpu.core_count)"
OPERATING_SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
CPU_ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')
BASH_RELEASE="$(command bash --version |head -1 | cut -d' ' -f4)"
ZSH_RELEASE="$(command zsh --version | cut -d' ' -f2)"
export CPU_ARCHITECTURE OPERATING_SYSTEM CPU_BRAND CPU_FEATURES CPU_CORES BASH_RELEASE ZSH_RELEASE
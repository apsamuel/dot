#shellcheck shell=bash
#% description: base variables and functions


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

# System information
CPU_BRAND="$(sysctl -n machdep.cpu.brand_string)"
CPU_FEATURES="$(sysctl -n machdep.cpu.features)"
CPU_CORES="$(sysctl -n machdep.cpu.core_count)"
OPERATING_SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
CPU_ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')

# Shell information
BASH_RELEASE="$(command bash --version |head -1 | cut -d' ' -f4)"
ZSH_RELEASE="$(command zsh --version | cut -d' ' -f2)"
GIT_RELEASE="$(command git --version | cut -d' ' -f3)"

export CPU_ARCHITECTURE OPERATING_SYSTEM CPU_BRAND CPU_FEATURES CPU_CORES
export BASH_RELEASE ZSH_RELEASE GIT_RELEASE

#shellcheck shell=bash
#% description: base variables and functions


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

ZSH="$HOME/.dot/vendor/oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"
ZSH_HISTFILE="$HOME/.zsh_history"
ZSH_HISTSIZE=1000000
ZSH_SAVEHIST=1000000

HISTFILE="$HOME/.zsh_history"
HISTSIZE=${ZSH_HISTSIZE}
SAVEHIST=${ZSH_SAVEHIST}

# TODO: validate that these variables are set correctly and exit with an error if not
# TODO: ensure we consume our submodules correctly and exit with an error if they are not present
# TODO: verify what happens when TPM is not configured to point to the XDG path and exit with an error if it is not configured correctly
# TODO: ensure that TPM is configured to consume plugins from the vendored path ./vendor/oh-my-tmux/plugins/ and exit with an error if it is not configured correctly

# INFO: TPM plugins are managed as git submodules inside vendor/oh-my-tmux/plugins/
# SEE: vendor/oh-my-tmux/.gitmodules for the full plugin inventory.

# XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest
# https://wiki.archlinux.org/title/XDG_Base_Directory
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"



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

# export variables for use in other modules
export CPU_ARCHITECTURE OPERATING_SYSTEM CPU_BRAND CPU_FEATURES CPU_CORES
export BASH_RELEASE ZSH_RELEASE GIT_RELEASE
export ZSH ZSH_CUSTOM ZSH_HISTFILE ZSH_HISTSIZE ZSH_SAVEHIST HISTFILE HISTSIZE SAVEHIST
export XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME

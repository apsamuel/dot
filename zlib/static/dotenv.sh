#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207



unset DOT_ROOT DOT_DIRECTORY DOT_LIBRARY DOT_LIBRARY_FILES DOT_DEBUG

# enable debugging by setting the DOT_DEBUG value to 1
export DOT_DEBUG="${DOT_DEBUG:-0}"
# define the root directory for the dotfiles (DOT_ROOT & DOT_DIRECTORY are synonymous)
export DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
export DOT_DIRECTORY="${DOT_DIRECTORY:-${DOT_ROOT}}"
# define the library directory for the dotfiles
export DOT_LIBRARY="${DOT_LIBRARY:-${DOT_ROOT}/zlib}"
# store available library files as sorted list
export DOT_LIBRARY_FILES=($(find "${DOT_LIBRARY}" -maxdepth 1 -type f -name "*.sh" | sort -d))

export DOT_DEBUG="${DOT_DEBUG:-0}"
export DOT_SHELL="${DOT_SHELL:-zsh}"
export DOT_INTERACTIVE="${DOT_INTERACTIVE:-0}"
export DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
export DOT_SHELL="${DOT_SHELL:-zsh}"
export DOT_DEBUG_RC="${DOT_DEBUG_RC:-${DOT_ROOT}/.${DOT_SHELL}rc}"
export DOT_DIRECTORY="${DOT_DIRECTORY:-${DOT_ROOT}}"
export DOT_LIBRARY="${DOT_LIBRARY:-${DOT_ROOT}/zlib}"
export DOT_LIBRARY_FILES=($(find "${DOT_LIBRARY}" -maxdepth 1 -type f -name "*.sh" | sort -d))
export DOT_BOOTSTRAP="${DOT_BOOTSTRAP:-${DOT_DIRECTORY}/bin/bootstrap.sh}"
export DOT_BOOTED="${DOT_BOOTED:-false}"
export DOT_ANACONDA_ENABLED="${DOT_ANACONDA_ENABLED:-0}"
export DOT_DISABLE_BREW="${DOT_DISABLE_BREW:-0}"
export DOT_DISABLE_EXTENSIONS="${DOT_DISABLE_EXTENSIONS:-0}"
export DOT_DISABLE_THEFUCK="${DOT_DISABLE_THEFUCK:-0}"
export DOT_DISABLE_ZSH_AUTOSUGGESTIONS="${DOT_DISABLE_ZSH_AUTOSUGGESTIONS:-0}"
export DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING="${DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING:-0}"
export DOT_DISABLE_Z="${DOT_DISABLE_Z:-0}"
export DOT_DISABLE_ANACONDA="${DOT_DISABLE_ANACONDA:-0}"
export DOT_DISABLE_OUTPUTS="${DOT_DISABLE_OUTPUTS:-0}"
export DOT_DISABLE_GIT="${DOT_DISABLE_GIT:-0}"
export DOT_DISABLE_MAC="${DOT_DISABLE_MAC:-0}"
export DOT_DISABLE_P10K="${DOT_DISABLE_P10K:-0}"
export DOT_DISABLE_NODE="${DOT_DISABLE_NODE:-0}"
export DOT_DISABLE_NETWORK="${DOT_DISABLE_NETWORK:-0}"

if [ "$(uname -m)"  = "x86_64" ]; then
    export DOT_ANACONDA_DIR=/usr/local/anaconda3
    export ANACONDA_DIR=/usr/local/anaconda3
else
    export DOT_ANACONDA_DIR=/opt/homebrew/anaconda3
    export ANACONDA_DIR=/opt/homebrew/anaconda3
fi
export DOT_ANACONDA_ENV="${DOT_ANACONDA_ENV:-base}"

export DOT_DIRECTORY DOT_LIBRARY DOT_LIBRARY_FILES DOT_DEBUG DOT_INTERACTIVE DOT_BOOT DOT_BOOTED DOT_ROOT DOT_SHELL DOT_DEBUG_RC DOT_ANACONDA_ENABLED
export DOT_DISABLE_BREW DOT_DISABLE_EXTENSIONS DOT_DISABLE_THEFUCK DOT_DISABLE_ZSH_AUTOSUGGESTIONS DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING DOT_DISABLE_Z DOT_DISABLE_ANACONDA DOT_DISABLE_OUTPUTS DOT_DISABLE_GIT DOT_DISABLE_MAC DOT_DISABLE_P10K DOT_DISABLE_NODE DOT_DISABLE_NETWORK
export DOT_ROOT DOT_DIRECTORY DOT_LIBRARY DOT_LIBRARY_FILES DOT_DEBUG
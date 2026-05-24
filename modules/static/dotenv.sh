#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

# --- core paths ---
export DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
# DOT_DIRECTORY is a synonym for DOT_ROOT
export DOT_DIRECTORY="${DOT_DIRECTORY:-${DOT_ROOT}}"
export DOT_MODULES="${DOT_MODULES:-${DOT_ROOT}/modules}"
export DOT_BIN="${DOT_BIN:-${DOT_ROOT}/bin}"
# shellcheck disable=SC2046
export DOT_MODULES_FILES=($(find "${DOT_MODULES}" -maxdepth 1 -type f -name "*.sh" | sort -d))
export DOT_BOOTSTRAP="${DOT_BOOTSTRAP:-${DOT_DIRECTORY}/scripts/dot-bootstrap.sh}"

# --- shell settings ---
export DOT_SHELL="${DOT_SHELL:-zsh}"
export DOT_INTERACTIVE="${DOT_INTERACTIVE:-0}"
export DOT_DEBUG="${DOT_DEBUG:-0}"
export DOT_DEBUG_RC="${DOT_DEBUG_RC:-${DOT_ROOT}/${DOT_SHELL}rc}"

# --- runtime ---
export DOT_ARCHITECTURE
DOT_ARCHITECTURE=$(arch)

# --- boot state ---
export DOT_BOOTED="${DOT_BOOTED:-false}"

# --- feature flags ---
export DOT_ANACONDA_ENABLED="${DOT_ANACONDA_ENABLED:-0}"
export DOT_DISABLE_BREW="${DOT_DISABLE_BREW:-0}"
export DOT_DISABLE_EXTENSIONS="${DOT_DISABLE_EXTENSIONS:-0}"
export DOT_DISABLE_THEFUCK="${DOT_DISABLE_THEFUCK:-0}"
export DOT_DISABLE_ZSH_AUTOSUGGESTIONS="${DOT_DISABLE_ZSH_AUTOSUGGESTIONS:-0}"
export DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING="${DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING:-0}"
export DOT_DISABLE_Z="${DOT_DISABLE_Z:-0}"
export DOT_DISABLE_ANACONDA="${DOT_DISABLE_ANACONDA:-1}"
export DOT_DISABLE_OUTPUTS="${DOT_DISABLE_OUTPUTS:-0}"
export DOT_DISABLE_GIT="${DOT_DISABLE_GIT:-0}"
export DOT_DISABLE_MAC="${DOT_DISABLE_MAC:-0}"
export DOT_DISABLE_P10K="${DOT_DISABLE_P10K:-0}"
export DOT_DISABLE_NODE="${DOT_DISABLE_NODE:-0}"
export DOT_DISABLE_NETWORK="${DOT_DISABLE_NETWORK:-0}"
export DOT_DISABLE_TMUX="${DOT_DISABLE_TMUX:-0}"
export DOT_DISABLE_VIMODE="${DOT_DISABLE_VIMODE:-0}"

# --- tool version defaults ---
export DOT_PYTHON_UV_DEFAULT_VERSION="${DOT_PYTHON_UV_DEFAULT_VERSION:-3.13}"

# --- anaconda ---
# anaconda is has been deprecated in favor of uv/pyenv
# if [ "$(uname -m)" = "x86_64" ]; then
#     export DOT_ANACONDA_DIR="${DOT_ANACONDA_DIR:-/usr/local/anaconda3}"
#     export ANACONDA_DIR="${DOT_ANACONDA_DIR}"
# else
#     export DOT_ANACONDA_DIR="${DOT_ANACONDA_DIR:-/opt/homebrew/anaconda3}"
#     export ANACONDA_DIR="${DOT_ANACONDA_DIR}"
# fi
# export DOT_ANACONDA_ENV="${DOT_ANACONDA_ENV:-base}"

# --- notes / vaults ---
export DOT_MARKDOWN_VAULT="${DOT_MARKDOWN_VAULT:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents}"

# --- shell experience ---
export DOT_SPLASH_SCREEN="${DOT_SPLASH_SCREEN:-true}"
export DOT_SPLASH_TYPE="${DOT_SPLASH_TYPE:-quote}"  # valid: quote, ascii, splash
export DOT_SPLASH_IMAGE_EXCLUDE="${DOT_SPLASH_IMAGE_EXCLUDE:-gif}"  # comma-separated extensions to skip

# --- legacy aliases (backward compatibility) ---
export DOT_DIR="${DOT_DIR:-${DOT_ROOT}}"
export DOT_LIBS_DIR="${DOT_LIBS_DIR:-${DOT_MODULES}}"

# --- cloud / data paths ---
export DOT_CLOUD_DIR="${DOT_CLOUD_DIR:-${HOME}/Library/Mobile Documents/com~apple~CloudDocs/dot}"
export DOT_SHELL_DATA="${DOT_SHELL_DATA:-${DOT_ROOT}/data/zsh.yaml}"
export DOT_SECRETS_DATA="${DOT_SECRETS_DATA:-${DOT_CLOUD_DIR}/secrets.json}"

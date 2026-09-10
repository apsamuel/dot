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

# --- runtime ---
export DOT_ARCHITECTURE
DOT_ARCHITECTURE=$(arch)

# --- feature flags ---
export DOT_DISABLE_BREW="${DOT_DISABLE_BREW:-0}"
export DOT_DISABLE_EXTENSIONS="${DOT_DISABLE_EXTENSIONS:-0}"
export DOT_DISABLE_THEFUCK="${DOT_DISABLE_THEFUCK:-0}"
export DOT_DISABLE_ZSH_AUTOSUGGESTIONS="${DOT_DISABLE_ZSH_AUTOSUGGESTIONS:-0}"
export DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING="${DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING:-0}"
export DOT_DISABLE_Z="${DOT_DISABLE_Z:-0}"
export DOT_DISABLE_OUTPUTS="${DOT_DISABLE_OUTPUTS:-0}"
export DOT_DISABLE_GIT="${DOT_DISABLE_GIT:-0}"
export DOT_DISABLE_MAC="${DOT_DISABLE_MAC:-0}"
export DOT_DISABLE_P10K="${DOT_DISABLE_P10K:-0}"
export DOT_DISABLE_NODE="${DOT_DISABLE_NODE:-0}"
export DOT_DISABLE_RUST="${DOT_DISABLE_RUST:-0}"
export DOT_DISABLE_TMUX="${DOT_DISABLE_TMUX:-0}"
export DOT_DISABLE_VIMODE="${DOT_DISABLE_VIMODE:-0}"

# --- tool version defaults ---
export DOT_PYTHON_UV_DEFAULT_VERSION="${DOT_PYTHON_UV_DEFAULT_VERSION:-3.13}"

# --- notes / vaults ---
export DOT_MARKDOWN_VAULTS="${DOT_MARKDOWN_VAULTS:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents}"

# --- shell experience ---
export DOT_SPLASH_SCREEN="${DOT_SPLASH_SCREEN:-true}"
export DOT_SPLASH_TYPE="${DOT_SPLASH_TYPE:-quote}"  # valid: quote, ascii, splash
export DOT_SPLASH_IMAGE_EXCLUDE="${DOT_SPLASH_IMAGE_EXCLUDE:-gif}"  # comma-separated extensions to skip

# --- legacy aliases (backward compatibility) ---
export DOT_LIBS_DIR="${DOT_LIBS_DIR:-${DOT_MODULES}}"

# --- Shell settings ---
# Single source of truth for history sizes; define before deriving HISTSIZE/SAVEHIST.
ZSH_HISTSIZE=1000000000
ZSH_SAVEHIST=1000000000
HISTSIZE=${ZSH_HISTSIZE}
SAVEHIST=${ZSH_SAVEHIST}
ZSH="$HOME/.dot/vendor/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"
export HISTFILE="$HOME/.zsh_history"
export ZSH_HISTFILE="$HOME/.zsh_history"
export ZSH ZSH_HISTSIZE ZSH_SAVEHIST SAVEHIST HISTFILE HISTSIZE

# --- history rotation / archival (consumed by dot::history::rotate) ---
export DOT_HIST_ARCHIVE_ENABLE="${DOT_HIST_ARCHIVE_ENABLE:-true}"
export DOT_HIST_ARCHIVE_DIR="${DOT_HIST_ARCHIVE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dot/history}"
export DOT_HIST_ARCHIVE_INTERVAL="${DOT_HIST_ARCHIVE_INTERVAL:-86400}"  # seconds between snapshots
export DOT_HIST_ARCHIVE_MAX="${DOT_HIST_ARCHIVE_MAX:-30}"               # snapshots to retain
export DOT_HIST_ROTATE_MAX_BYTES="${DOT_HIST_ROTATE_MAX_BYTES:-104857600}"  # trim threshold (100 MiB)
export DOT_HIST_ROTATE_KEEP_LINES="${DOT_HIST_ROTATE_KEEP_LINES:-0}"    # 0 = never trim live file


# --- cloud / data paths ---
export DOT_CLOUD_DIR="${DOT_CLOUD_DIR:-${HOME}/Library/Mobile Documents/com~apple~CloudDocs/dot}"
export DOT_SHELL_DATA="${DOT_SHELL_DATA:-${DOT_ROOT}/data/zsh.yaml}"
export DOT_SECRETS_DATA="${DOT_SECRETS_DATA:-${DOT_CLOUD_DIR}/secrets.json}"

# --- python ---
# When 1 (default), the python module reconciles zsh.yaml pip requirements into
# provisioned venvs (stamp-gated) and installs them into venvs created by
# dot::python::env. Set 0 to disable all requirement reconciliation.
export DOT_PY_ENSURE_REQUIREMENTS="${DOT_PY_ENSURE_REQUIREMENTS:-1}"

#!/bin/sh
# - ignore shellcheck warnings ZSH files, we are loading a ZSH environment
# shellcheck disable=SC1071


# shellcheck disable=SC3054
# shellcheck disable=SC3030
# shellcheck disable=SC3010
# shellcheck disable=SC3024
# shellcheck disable=SC3044

#% author: Aaron P. Samuel
#% description: configure the shell environment
#% usage: chsh -s $(which zsh) , source ~/.zshrc
# - ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# export ZSH="$HOME/.oh-my-zsh"
export ZSH="$HOME/.dot/vendor/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"
# TODO: we need to figure out how to manage TPM plugins as submodules within the forked oh-my-tmux repo in vendor/oh-my-tmux.
# For now, we can just install TPM plugins manually and ignore them as part of the dotfiles repo.
# do we set TMUX_PLUGIN_MANAGER_PATH to point to the plugins directory within the vendor/oh-my-tmux repo? or do we just ignore that and let users manage their own TPM plugins?
# export TMUX_PLUGIN_MANAGER_PATH="$HOME/.dot/vendor/oh-my-tmux/plugins"
export ZSH_HISTFILE="$HOME/.zsh_history"
export ZSH_HISTSIZE=1000000
export ZSH_SAVEHIST=1000000
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=${ZSH_HISTSIZE}
export SAVEHIST=${ZSH_SAVEHIST}

# configure XDG variables
# XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest
# https://wiki.archlinux.org/title/XDG_Base_Directory
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME

DOT_INIT_DIR=$(pwd -P)
# shell start time
DOT_INIT_START_TIME=$(date +%s)

# enable zsh completions
# autoload -U +X bashcompinit && bashcompinit

# baseline conditions
if [ -z "$HOME"  ]; then
    echo "Error: HOME environment variable not set"
    exit 1
fi

if [ -z "$USER" ]; then
    echo "Error: USER environment variable not set"
    exit 1
fi

if [ -z "$SHELL" ]; then
    echo "Error: SHELL environment variable not set"
    exit 1
fi



# iCloud references
ICLOUD="${ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs}"
ICLOUD_DIR="${ICLOUD}" # for backward compatibility
ICLOUD_DOCUMENTS="${ICLOUD}/Documents"
ICLOUD_DOWNLOADS="${ICLOUD}/Downloads"
ICLOUD_SCREENSHOTS="${ICLOUD}/ScreenShots"
export ICLOUD ICLOUD_DOCUMENTS ICLOUD_DOWNLOADS ICLOUD_SCREENSHOTS

# export TERM=xterm-256color
export MANPATH="/usr/local/man:$MANPATH"
export HISTSIZE=1000000000
export HISTFILESIZE=1000000000
export SAVEHIST=$HISTSIZE
export HISTFILE="$HOME"/.zsh_history
GPG_TTY=$(tty)
export GPG_TTY
export LANG=en_US.UTF-8
export EDITOR=vim

# TODO: this is a dependency on the pygmentize tool, which neds to be installed separately. We should either remove this dependency or add it to the bootstrap process
export ZSH_COLORIZE_TOOL=pygmentize
# PAGER / MANPAGER — kept as plain less (set via zlib/000-a-config.sh).
# Avoid bat here: bat-as-pager breaks automated processes that pipe through $PAGER.
# Use `cless` for interactive syntax-highlighted paging.
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
arch="$(arch)"
export ARCH="${arch}"

# minimal bootstrap vars (needed to source dotenv.sh)
DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
DOT_LIBRARY="${DOT_LIBRARY:-${DOT_ROOT}/zlib}"

# load all DOT_* environment variables from the canonical source
. "${DOT_LIBRARY}/static/dotenv.sh" || { echo "Error: unable to load environment variables from dotenv.sh"; exit 1; }

if [ -f "${DOT_BOOTSTRAP}" ]; then
    . "${DOT_BOOTSTRAP}" || {
        echo "Error: unable to load bootstrapper"
        exit 1
    }
fi

# foundational functions
. "${DOT_LIBRARY}"/static/foundation.sh || {
    echo "Error: unable to load foundational functions"
    exit 1
}

# shell limits (user)
. "${DOT_LIBRARY}"/static/limits.sh || {
    echo "Error: unable to load shell limits"
    exit 1
}

# shell autoloads (ZSH)
. "${DOT_LIBRARY}"/static/autoload.sh || {
    echo "Error: unable to configure autoloads"
    exit 1
}

# # bootstrap functions | this is a redundant sourcing
# . "${DOT_DIRECTORY}"/bin/dot-bootstrap.sh || {
#     echo "Error: unable to load bootstrap functions"
#     exit 1
# }

# declare -a SSH_KEYS
SSH_KEYS=()
# prepare files in .ssh directory for the ssh-agent
if [ -d "$HOME"/.ssh ]; then

    files=("$HOME"/.ssh/*)
    for file in "${files[@]}"; do

        if [[ "$file" =~ (config|deprecated|.*pub|environment.*|known_hosts.*) ]]; then
            continue
        fi
        base=$(basename "$file")

        SSH_KEYS+=("$base")
    done
fi

export SSH_KEYS



# enable zsh options
loadZshOptions

# make ZLIB available to shell
loadZlib

compileTermInfo

if [[ "${DOT_DEBUG}" -gt 0 ]]; then
    echo "configuring: $OPERATING_SYSTEM/$CPU_ARCHITECTURE"
fi

# configure zstyle
# NOTE: 💡 the zstyle section should precede sourcing of oh-my-zsh
# shellcheck disable=SC2154
# shellcheck disable=SC2309
if [[ $(getShellName)  =~ .*zsh ]]; then
    zstyle :omz:plugins:iterm2 shell-integration yes # enable zsh integration
    zstyle ':omz:update' frequency 7
    zstyle ':completion::complete:*' use-cache 1
    # zstyle ":conda_zsh_completion:*" use-groups true
    # zstyle ":conda_zsh_completion:*" show-unnamed true
    # zstyle ":conda_zsh_completion:*" sort-envs-by-time true
    zstyle :omz:plugins:ssh-agent identities "${SSH_KEYS[@]}"
    zstyle :omz:plugins:ssh-agent agent-forwarding on
    zstyle :omz:plugins:ssh-agent lifetime

fi

# TODO: host secrets in icloud directory (optionally)
loadUserSecrets

if [[ ${DOT_SPLASH_SCREEN} == true && "${DOT_SPLASH_TYPE}" == "quote" ]]; then
    termQuote
fi
if [[ ${DOT_SPLASH_SCREEN} == true && "${DOT_SPLASH_TYPE}" == "ascii" ]]; then
    termLogo
fi

export VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
export VI_MODE_SET_CURSOR=true

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi
export POWERLEVEL9K_INSTANT_PROMPT=quiet
export POWERLEVEL9K_INSTANT_PROMPT=off

typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="robbyrussell"


# if the icloud theme is not available, fallback to using the file in the dot directory
ZSH_THEME="$(yq '.theme' "$HOME"/.dot/data/zsh.yaml)"
export ZSH_THEME

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
export DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
#ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
export COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
export HIST_STAMPS="dd.mm.yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# shellcheck disable=SC2046
export plugins=(
    $(
        yq '.plugins.builtin[]' "$HOME"/.dot/data/zsh.yaml | xargs
    )
    $(
        yq '.plugins.custom[] | select(.enabled == true) | .repo' "$HOME"/.dot/data/zsh.yaml | xargs
    )
)

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#E0F40A,bg=black,bold,underline"

. "$ZSH"/oh-my-zsh.sh

# bind keys
bindkey -M vicmd v edit-command-line
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

# You may need to manually set your language environment

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# completions defined in $HOME/.completion
#source "$HOME"/.completion/npm

export ITERM2_SQUELCH_MARK=1
# The next line updates PATH for the Google Cloud SDK.
#source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
# The next line enables shell command completion for gcloud.
#source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"




getTmuxWindowName() {
    ("$TMUX_PLUGIN_MANAGER_PATH"/tmux-window-name/scripts/rename_session_windows.py &)
}

add-zsh-hook chpwd getTmuxWindowName

# zle
zle -N create_completion


# post exports
DOT_INIT_END_TIME=$(date +%s)
DOT_LOAD_TIME="$((DOT_INIT_END_TIME - DOT_INIT_START_TIME))"
export DOT_INIT_DIR DOT_INIT_START_TIME DOT_INIT_END_TIME DOT_LOAD_TIME DOT_LIBS_DIR DOT_DIR DOT_DEBUG DOT_SPLASH_SCREEN DOT_SPLASH_TYPE DOT_CLOUD_DIR DOT_SHELL_DATA DOT_SECRETS_DATA
# export PATH="$PATH:$HOME/.dot/bin"

test -e "${HOME}/.iterm2_shell_integration.zsh" && . "${HOME}/.iterm2_shell_integration.zsh"

# Zsh will override CTRL-R & provide its builtin reverse-history-search if this line is not executed here
# https://github.com/junegunn/fzf/issues/1812
configureFzf

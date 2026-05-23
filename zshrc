#!/bin/sh
#% author: Aaron P. Samuel
#% description: configure the shell environment
#% usage: git clone --recurse-submodules https://github.com/apsamuel/dot.git ~/.dot
#% usage:
#% usage: chsh -s $(which zsh) , source ~/.zshrc

# - ignore shellcheck warnings ZSH files, we are loading a ZSH environment
# shellcheck disable=SC1071


# shellcheck disable=SC3054
# shellcheck disable=SC3030
# shellcheck disable=SC3010
# shellcheck disable=SC3024
# shellcheck disable=SC3044

# - ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207



# early exit if critical environment variables are not set

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


# ── VSCode / Copilot / non-interactive guard ─────────────────────────────────
# When sourced by VSCode or Copilot's agent terminal we MUST avoid any feature
# that switches the terminal into the alternate screen buffer (tmux, p10k
# instant prompt redraws, zsh-vi-mode, F-Sy-H, fzf-tab previews) — otherwise
# Copilot's command-output capture fails with: "The command opened the
# alternate buffer, so I couldn't run ...".
#
# Two tiers:
#   1. Full minimal mode: non-interactive shells, dumb terminals, or anything
#      flagged as a Copilot agent terminal → disable everything decorative.
#   2. Tmux-only suppression: any VSCode terminal (human or agent) → never
#      auto-attach tmux, since each tmux pane uses the alt screen and that
#      breaks VSCode shell integration (OSC 633) capture.
if [[ $- != *i* ]] || [[ "$TERM" = "dumb" ]] || [[ -n "$COPILOT_AGENT_TERMINAL" ]]; then
    export DOT_INTERACTIVE=0
    export DOT_DISABLE_P10K=1
    export DOT_DISABLE_OUTPUTS=1
    export DOT_DISABLE_EXTENSIONS=1
    export DOT_DISABLE_THEFUCK=1
    export DOT_DISABLE_ZSH_AUTOSUGGESTIONS=1
    export DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING=1
    export DOT_DISABLE_VIMODE=1
    export DOT_DISABLE_TMUX=1
    export DOT_SPLASH_SCREEN=false
elif [[ "$TERM_PROGRAM" = "vscode" ]]; then
    # Heavy profile is fine for human VSCode terminals, but tmux's per-pane
    # alt-screen still confuses VSCode's shell-integration capture. Suppress
    # only tmux auto-attach; leave p10k / plugins alone.
    export DOT_INTERACTIVE=1
    export DOT_DISABLE_TMUX=1
else
    # Normal human interactive shell.
    export DOT_INTERACTIVE=1
fi


# what path are we running from?
DOT_INIT_DIR=$(pwd -P)

# Captures the start time for benchmarking
DOT_INIT_START_TIME=$(date +%s)

# Enables zsh completions
# autoload -U +X bashcompinit && bashcompinit

# TODO: this is a dependency on the pygmentize tool, which neds to be installed separately.
# TODO: We should either remove this dependency or add it to the bootstrap process
# export ZSH_COLORIZE_TOOL=pygmentize

# PAGER / MANPAGER — kept as plain less (set via modules/000-a-config.sh).
# Avoid bat here: bat-as-pager breaks automated processes that pipe through $PAGER.
# Use `cless` for interactive syntax-highlighted paging.
export TMUX_PLUGIN_MANAGER_PATH="${DOT_ROOT}/vendor/oh-my-tmux/plugins"
arch="$(arch)"
export ARCH="${arch}"

# minimal bootstrap vars (needed to source dotenv.sh)
DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
DOT_MODULES="${DOT_MODULES:-${DOT_ROOT}/modules}"

# load all DOT_* environment variables from the canonical source
. "${DOT_MODULES}/static/dotenv.sh" || { echo "Error: unable to load environment variables from dotenv.sh"; exit 1; }

# dot:: structured logging helpers (must load before foundation.sh / dynamic modules)
. "${DOT_MODULES}"/static/logging.sh || {
    echo "Error: unable to load logging helpers"
    return 1
}

if [ -f "${DOT_BOOTSTRAP}" ]; then
    . "${DOT_BOOTSTRAP}" || {
        echo "Error: unable to load bootstrapper"
        exit 1
    }
fi


# foundational functions
. "${DOT_MODULES}"/static/foundation.sh || {
    echo "Error: unable to load foundational functions"
    exit 1
}

# ssh configuration (keys, config file parsing, etc.)
. "${DOT_MODULES}"/static/ssh.sh || {
    echo "Error: unable to load SSH configuration"
    return 1
}

# shell limits (user)
. "${DOT_MODULES}"/static/limits.sh || {
    echo "Error: unable to load shell limits"
    return 1
}

# shell autoloads (ZSH)
. "${DOT_MODULES}"/static/autoload.sh || {
    echo "Error: unable to configure autoloads"
    return 1
}

# dot.shell command + iCloud/TMUX exports (formerly modules/000-b-dot.sh)
. "${DOT_MODULES}"/static/dot.sh || {
    echo "Error: unable to load dot.shell"
    return 1
}

# declare -a SSH_KEYS
# prepare files in .ssh directory for the ssh-agent
# (getSshIdentities is defined in modules/static/foundation.sh)
SSH_KEYS=()
getSshIdentities --format array --var SSH_KEYS
export SSH_KEYS

# enable zsh options
loadZshOptions

# load dot dynamic modules available
loadModules

if [[ "${DOT_INTERACTIVE}" -ne 0 ]]; then
    compileTermInfo
fi

if [[ "${DOT_DEBUG}" -gt 0 ]]; then
    echo "configuring: $OPERATING_SYSTEM/$CPU_ARCHITECTURE"
fi



# TODO: host secrets in icloud directory (optionally)
# Skip splash screens AND secret-loading prompts in non-interactive shells
# (Copilot agent, dumb terminals, automation tasks) where there's no human
# to enter passphrases or read decorative output.
if [[ "${DOT_INTERACTIVE}" -ne 0 ]]; then
    loadUserSecrets

    if [[ ${DOT_SPLASH_SCREEN} = true && "${DOT_SPLASH_TYPE}" = "quote" ]]; then
        termQuote
    fi
    if [[ ${DOT_SPLASH_SCREEN} = true && "${DOT_SPLASH_TYPE}" = "ascii" ]]; then
        termLogo
    fi
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
ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

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

# shellcheck disable=SC2046
export plugins=(
    $(
        yq '.plugins.builtin[]' "$HOME"/.dot/data/zsh.yaml | xargs
    )
    $(
        yq '.plugins.custom[] | select(.enabled == true) | .repo' "$HOME"/.dot/data/zsh.yaml | xargs
    )
)

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#49F904,bg=black,bold,underline"

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


# zle
zle -N create_completion


# export PATH="$PATH:$HOME/.dot/bin"

# Zsh will override CTRL-R & provide its builtin reverse-history-search if this line is not executed here
# https://github.com/junegunn/fzf/issues/1812
configureFzf

# calculate total load time and export it as an environment variable for use in the shell
DOT_INIT_END_TIME=$(date +%s)
DOT_LOAD_TIME="$((DOT_INIT_END_TIME - DOT_INIT_START_TIME))"
export DOT_INIT_DIR DOT_INIT_START_TIME DOT_INIT_END_TIME DOT_LOAD_TIME DOT_LIBS_DIR DOT_DIR DOT_DEBUG DOT_SPLASH_SCREEN DOT_SPLASH_TYPE DOT_CLOUD_DIR DOT_SHELL_DATA DOT_SECRETS_DATA

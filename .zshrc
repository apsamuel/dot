#% description: a Mac OSX agnostic ZSH resource file
#% usage:
#%  - chsh -s $(which zsh) & reload terminal
#%  - source ~/.zshrc in a ZSH session
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

ulimit -c unlimited

DOT_PROJECT_DEBUG=${DOT_PROJECT_DEBUG:-false}
DOT_PROJECT_SPLASH_ENTRANCE=${DOT_PROJECT_SPLASH_ENTRANCE:-true}
DOT_PROJECT_SPLASH_TYPE="${DOT_PROJECT_SPLASH_TYPE:-quote}"
DOT_PROJECT_DIR="${DOT_PROJECT_DIR:-$HOME/.dot}"
ZLIB_HELPERS_DIR="${ZLIB_HELPERS_DIR:-$DOT_PROJECT_DIR/zlib}"
SHELL_INIT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) # where are we? https://stackoverflow.com/a/246128/1235074
SHELL_INIT_START=$(date +%s)

# run bootstrap
# sh "$HOME"/.dot/bootstrap.sh

# source zlib
if [[ -d "$ZLIB_HELPERS_DIR" ]]; then
    for lib in "${ZLIB_HELPERS_DIR}"/* ; do
        if [[ ! "${DOT_PROJECT_DEBUG}x" == "x" && "${DOT_PROJECT_DEBUG}" == true ]]; then
            echo "loading: $lib"
        fi
        source "$lib" || true
    done
else
    echo "Warning: ZLIB_HELPERS_DIR not found: $ZLIB_HELPERS_DIR"
fi



ZSH_OPTIONS=(
    $(
        jq -r '.[]' "$HOME"/.dot/data/zplugins.json | xargs
    )
)
export ZSH_OPTIONS

# set ZSH flag options

for opt in "${ZSH_OPTIONS[@]}"; do
    if [[ ! "${DOT_PROJECT_DEBUG}x" == "x" && "${DOT_PROJECT_DEBUG}" == true ]]; then
        echo "sets option: $opt"
    fi
    setopt "${opt}"
done

# 💡 the zstyle section should precede sourcing of oh-my-zsh
zstyle :omz:plugins:iterm2 shell-integration yes # enable zsh integration
# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 7
zstyle ':completion::complete:*' use-cache 1
zstyle ":conda_zsh_completion:*" use-groups true
zstyle ":conda_zsh_completion:*" show-unnamed true
zstyle ":conda_zsh_completion:*" sort-envs-by-time true
zstyle :omz:plugins:ssh-agent identities id_rsa id_import_rsa id_rsa_switch noop-staging noop-core-production noop-public-cluster
zstyle :omz:plugins:ssh-agent agent-forwarding on
zstyle :omz:plugins:ssh-agent lifetime

# load & export secrets from icloud
if [[ -d "$ICLOUD"/dot && -f "$ICLOUD"/dot/secrets.json ]]; then
    # uses an associative array to load secrets into memory
    declare -A secrets
    secretKeys=(
        $(
            jq -r '. | keys | .[]' "$ICLOUD"/dot/secrets.json | xargs
        )
    )
    export DOT_SECRET_KEYS=("${secretKeys[@]}")

    #echo "${secretKeys[@]}"
    # if secrets length is greater than 0, write to /tmp/.secrets
    if [[ ${#secretKeys[@]} -gt 0  ]]; then
        # echo $TMPDIR
        touch "${TMPDIR}"/.secrets
        echo "#!/bin/bash" > "$TMPDIR"/.secrets
    fi
    for secretKey in "${secretKeys[@]}"; do
        secrets[$secretKey]="$(jq --arg secretKey "${secretKey}" -r '.[$secretKey]' "$ICLOUD"/dot/secrets.json)"
        echo "${secretKey}=${secrets[$secretKey]}" >> "$TMPDIR"/.secrets
    done

    if [[ -f "$TMPDIR"/.secrets ]]; then
        source "$TMPDIR"/.secrets
        #rm -f "$TMPDIR"/.secrets
    fi
fi


# if [[ -d "$HOME"/.config && -f "$HOME"/.config/secrets ]]; then
#     source "$HOME"/.config/secrets
# fi

# # load & export secrets from $HOME/.dot/data/secrets
# if [[ -d "$HOME"/.dot/data && -f "$HOME"/.dot/data/secrets ]]; then
#     source "$HOME"/.dot/data/secrets
# fi


export TERM=xterm-256color
export MANPATH="/usr/local/man:$MANPATH"
export HISTSIZE=100000
export SAVEHIST=$HISTSIZE
export HISTFILE=$HOME/.zsh_history
export MANPATH="/usr/local/man:$MANPATH"
GPG_TTY=$(tty)
export GPG_TTY
export LANG=en_US.UTF-8
export EDITOR=vim
export ZSH_COLORIZE_TOOL=pygmentize
export PAGER='bat '
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
arch="$(arch)"
export ARCH="${arch}"

if [[ ${DOT_PROJECT_SPLASH_ENTRANCE} == true && "${DOT_PROJECT_SPLASH_TYPE}" == "quote" ]]; then
    # echo "quote"
    termQuote
fi
if [[ ${DOT_PROJECT_SPLASH_ENTRANCE} == true && "${DOT_PROJECT_SPLASH_TYPE}" == "ascii" ]]; then
    termLogo
fi


# set homebrew path based on session architecture
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ $OSTYPE == darwin* && "$arch" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ $OSTYPE == darwin* && "$arch" == "i386" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "Warning: problem detecting OSTYPE"
fi

## node
export NODE_VERSION=16.13.2
export N_PREFIX=${HOME}/devops/node
NODE_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
export NODE_OS
export NODE_ARCH=x64

# path
export PATH=${HOME}/devops/node/node-v${NODE_VERSION}-${NODE_OS}-${NODE_ARCH}/bin:${HOME}/devops/scripts:$PATH:/Users/aaronsamuel/Library/Python/3.11/bin
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
export PATH="/usr/local/opt/openjdk/bin:$PATH"
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

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
#export PATH=/opt/homebrew/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="robbyrussell"
export ZSH_THEME="powerlevel10k/powerlevel10k"

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
export plugins=(
    brew
    history
    alias-finder
    colorize
    colored-man-pages
    copybuffer
    copypath
    direnv
    emoji
    emoji-clock
    dash
    vi-mode
    ssh-agent
    zsh-navigation-tools
    kubectl
    git
    git-extras
    gitignore
    gh
    gnu-utils
    web-search
    node
    npm
    conda-zsh-completion
    autopep8
    python
    docker
    docker-compose
    zsh-autosuggestions
    thefuck
    zsh_codex
    F-Sy-H
    nmap
)

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#E0F40A,bg=black,bold,underline"

source "$ZSH"/oh-my-zsh.sh

# bind keys
bindkey -M vicmd v edit-command-line
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line
# bindkey '^A' n-aliases
# binding for zsh_codex
#zle -N create_completion
#bindkey '^X' create_completion


# You may need to manually set your language environment
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f "$HOME"/.p10k.zsh ]] || source "$HOME"/.p10k.zsh

# zsh syntax highlighting
# source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters
#source /usr/local/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
#source /usr/local/Cellar/zsh-syntax-highlighting/0.7.1/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#iterm integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


#zsh completions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

{
    infocmp -x xterm-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

# thefuck
eval "$(thefuck --enable-experimental-instant-mode --yeah --alias)"
#launchctl completions
source /usr/local/Cellar/launchctl-completion/1.0/etc/bash_completion.d/launchctl
#stormssh completions
source /usr/local/Cellar/stormssh-completion/0.1.1/etc/bash_completion.d/stormssh
# z plugin
source /usr/local/Cellar/z/1.9/etc/profile.d/z.sh

# completions defined in $HOME/.completion
source "$HOME"/.completion/npm
export ITERM2_SQUELCH_MARK=1
# The next line updates PATH for the Google Cloud SDK.
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
# The next line enables shell command completion for gcloud.
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

# >>> conda initialize >>>
export ANACONDA_DIR=/usr/local/anaconda3
__conda_setup="$($ANACONDA_DIR/bin/conda 'shell.zsh' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${ANACONDA_DIR}/etc/profile.d/conda.sh" ]; then
        . "${ANACONDA_DIR}/etc/profile.d/conda.sh"
    else
        export PATH="${ANACONDA_DIR}/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

function tmux-window-name() {
    ("$TMUX_PLUGIN_MANAGER_PATH"/tmux-window-name/scripts/rename_session_windows.py &)
}

add-zsh-hook chpwd tmux-window-name

# zle
zle -N create_completion

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform

## alias definitions
alias cat='bat'
alias ls='ls --color=always'
alias less='bat --paging=always'

# post exports
SHELL_INIT_END=$(date +%s)
SHELL_INIT_TIME="$((SHELL_INIT_END - SHELL_INIT_START)) seconds"
export SHELL_INIT_DIR SHELL_INIT_START SHELL_INIT_END SHELL_INIT_TIME ZLIB_HELPERS_DIR DOT_PROJECT_DIR DOT_PROJECT_DEBUG DOT_PROJECT_SPLASH_ENTRANCE DOT_PROJECT_SPLASH_TYPE
export PATH=$PATH:$HOME/.dot/bin

#% header
#% description: Local ZSH config
#% usage: source ~/.zshrc
#% endheader
# shellcheck source=/dev/null
source "$HOME"/.zsh_helpers/output.sh

# limits
ulimit -c unlimited

# bind keys
bindkey -M vicmd v edit-command-line
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line
# binding for zsh_codex
#zle -N create_completion
#bindkey '^X' create_completion

# zsh options
export ZSH_OPTIONS=(
    autopushd            # Push the old directory onto the directory stack when changing directories.
    extendedglob         # Use extended globbing syntax.
    share_history        # Share history between all sessions.
    hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate.
    BANG_HIST            # Treat the '!' character specially during expansion.
    EXTENDED_HISTORY     # Write the history file in the ":start:elapsed;command" format.
    INC_APPEND_HISTORY   # Write to the history file immediately, not when the shell exits.
    SHARE_HISTORY        # Share history between all sessions.
    histexpiredupsfirst  # Expire duplicate entries first when trimming history.
    histignoredups       # Don't record an entry that was just recorded again.
    histignorealldups    # Delete old recorded entry if new entry is a duplicate.
    HIST_FIND_NO_DUPS    # Do not display a line previously found.
    HIST_IGNORE_SPACE    # Don't record an entry starting with a space.
    histsavenodups       # Don't write duplicate entries in the history file.
    HIST_REDUCE_BLANKS   # Remove superfluous blanks before recording entry.
    histverify           # Don't execute immediately upon history expansion.
    HIST_BEEP            # Beep when accessing nonexistent history.
)

# set ZSH flag options

for opt in "${ZSH_OPTIONS[@]}"; do
    setopt "${opt}"
done

setopt autopushd              # Push the old directory onto the directory stack when changing directories.
setopt extendedglob           # Use extended globbing syntax.
setopt share_history          # Share history between all sessions.
setopt hist_ignore_all_dups   # Delete old recorded entry if new entry is a duplicate.
setopt BANG_HIST              # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY       # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY     # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS       # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a line previously found.
setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY            # Don't execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing nonexistent history.
setopt pushdignoredups        # Don't pushd onto the stack if the last two directories are the same.
setopt monitor                # Report status of background jobs immediately.
setopt zle                    # Enable Zsh Line Editor (ZLE).

# zstyle
# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 7
zstyle ':completion::complete:*' use-cache 1
zstyle ":conda_zsh_completion:*" use-groups true
zstyle ":conda_zsh_completion:*" show-unnamed true
zstyle ":conda_zsh_completion:*" sort-envs-by-time true
zstyle :omz:plugins:ssh-agent identities id_rsa noop-staging noop-core-production noop-public-cluster
zstyle :omz:plugins:ssh-agent agent-forwarding on
zstyle :omz:plugins:ssh-agent lifetime

# environment
export GITHUB_TOKEN=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
export OPENAI_TOKEN=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
export GITHUB_TOKEN_NOOP=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
export WOLFRAM_APPID='KKJJ4V-EJ4UJHV6VR'
export NCBI_API_KEY='3af408e45198ce09787a1556c3c41a482b08'

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

arch="$(arch)"
printAttribute "architecture" "${arch}"

printAttribute "ostype" "${OSTYPE}"
termQuote
# Set Brew path based on session architecture
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

# plugins=(git)
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
    #navi
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
)

source "$ZSH"/oh-my-zsh.sh

# User configuration

# function tPutColors() {
#   for (( i = 0; i < 8; i++  )); do
#     for (( j = 0; j < 8; j++  )); do
#      printf "$(tput setab $i)$(tput setaf $j)(b=$i, f=$j)$(tput sgr0)\n"
#     done
#   done
# }

# function tPutColorsAndAttributes() {
#   for b in {0..7} 9; do
#       for f in {0..7} 9; do
#           for attr in "" bold; do
#              echo -e "$(tput setab $b; tput setaf $f; [ -n "$attr" ] && tput $attr) $f ON $b $attr $(tput sgr0)"
#           done
#       done
#   done
# }

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

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/aaronsamuel/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/aaronsamuel/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/aaronsamuel/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/aaronsamuel/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# zsh syntax highlighting
# source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/local/Cellar/zsh-syntax-highlighting/0.7.1/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#iterm integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

#launchctl completions
source /usr/local/Cellar/launchctl-completion/1.0/etc/bash_completion.d/launchctl

#stormssh completions
source /usr/local/Cellar/stormssh-completion/0.1.1/etc/bash_completion.d/stormssh

# z plugin
source /usr/local/Cellar/z/1.9/etc/profile.d/z.sh

#zsh completions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

{
    infocmp -x screen-256color
    printf '\t%s\n' 'ncv@,'
} >/tmp/t && tic -x /tmp/t

# thefuck
eval "$(thefuck --enable-experimental-instant-mode --yeah --alias)"

# completions defined in $HOME/.completion
source "$HOME"/.completion/npm
export ITERM2_SQUELCH_MARK=1

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/aaronsamuel/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/aaronsamuel/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/aaronsamuel/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/aaronsamuel/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

function showcolors256() {
    local row col blockrow blockcol red green blue
    local showcolor=_showcolor256_${1:-bg}
    local white="\033[1;37m"
    local reset="\033[0m"

    echo -e "Set foreground color: \\\\033[38;5;${white}NNN${reset}m"
    echo -e "Set background color: \\\\033[48;5;${white}NNN${reset}m"
    echo -e "Reset color & style:  \\\\033[0m"
    echo

    echo 16 standard color codes:
    for row in {0..1}; do
        for col in {0..7}; do
            $showcolor $((row * 8 + col)) "$row"
        done
        echo
    done
    echo

    echo 6·6·6 RGB color codes:
    for blockrow in {0..2}; do
        for red in {0..5}; do
            for blockcol in {0..1}; do
                green=$((blockrow * 2 + blockcol))
                for blue in {0..5}; do
                    $showcolor $((red * 36 + green * 6 + blue + 16)) $green
                done
                echo -n "  "
            done
            echo
        done
        echo
    done

    echo 24 grayscale color codes:
    for row in {0..1}; do
        for col in {0..11}; do
            $showcolor $((row * 12 + col + 232)) "$row"
        done
        echo
    done
    echo
}

function _showcolor256_fg() {
    local code
    code=$(printf %03d "$1")
    echo -ne "\033[38;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}

function _showcolor256_bg() {
    if (($2 % 2 == 0)); then
        echo -ne "\033[1;37m"
    else
        echo -ne "\033[0;30m"
    fi
    local code
    code=$(printf %03d "$1")
    echo -ne "\033[48;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}

export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
function tmux-window-name() {
    ("$TMUX_PLUGIN_MANAGER_PATH"/tmux-window-name/scripts/rename_session_windows.py &)
}
add-zsh-hook chpwd tmux-window-name

# zle
zle -N create_completion

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform

## alias definitions
alias less='bat --paging=always'

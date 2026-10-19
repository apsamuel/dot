# shellcheck shell=bash
#% description: configure zstyle settings for zsh subsystems (compsys, oh-my-zsh, plugins)
#% notes: this module MUST be sourced before oh-my-zsh.sh is sourced from zshrc,
#%        because plugins read their styles at load time. modules are loaded from
#%        zshrc *before* `. "$ZSH"/oh-my-zsh.sh`, so the ordering is correct.
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

if [[ "${DOT_DISABLE_ZSTYLE:-0}" -eq 1 ]]; then
    dot::static::logging::skip "zstyle" "disabled"
    return
fi

# zstyle is a zsh-only builtin; bail out for other shells.
# Note: don't use dot::foundation::shell-name() here — it has inverted logic and would skip zsh.
if [[ -z "${ZSH_VERSION:-}" ]]; then
    return
fi

# ---------------------------------------------------------------------------
# Helpers — introspect zstyle at runtime
# ---------------------------------------------------------------------------

dot::zstyle::help() {
    case "${1:-}" in
        ''|help|-h|--help) printf '%s\n' 'Usage: dot::zstyle <command> [arguments]' 'Commands: list, show, dump, help' 'Example: dot::zstyle help dump'; return ;;
        list) printf '%s\n' 'Usage: dot::zstyle list [--] [CONTEXT_PATTERN [STYLE_PATTERN]]' '       dot::zstyle::list [--] [CONTEXT_PATTERN [STYLE_PATTERN]]' 'List matching styles in re-sourceable form; no operands lists all styles.' "Example: dot::zstyle list ':completion:*'" ;;
        show) printf '%s\n' 'Usage: dot::zstyle show [--] CONTEXT STYLE' '       dot::zstyle::show [--] CONTEXT STYLE' 'Print the value of a style, or (unset) with status 1.' "Example: dot::zstyle show ':omz:update' frequency" ;;
        dump) printf '%s\n' 'Usage: dot::zstyle dump [--] [FILE]' '       dot::zstyle::dump [--] [FILE]' 'Dump all styles to stdout by default; FILE is created or overwritten.' 'Example: dot::zstyle dump styles.zsh' ;;
        *) printf 'dot::zstyle: unknown help topic: %s\n' "$1" >&2; return 2 ;;
    esac
    printf '%s\n' 'Options: -h, --help; -- permits literal dash-leading operands.' 'Requires ZSH and its zstyle builtin. Help does not query styles or write files.' 'Returns 0 on success, 2 for usage errors, or the failing builtin/redirection status.'
}

dot::zstyle() {
    local action="${1:-help}"
    [[ $# -eq 0 ]] || shift
    case "${action}" in
        help|-h|--help) dot::zstyle::help "$@" ;;
        list) dot::zstyle::list "$@" ;;
        show) dot::zstyle::show "$@" ;;
        dump) dot::zstyle::dump "$@" ;;
        *) printf 'dot::zstyle: unknown command: %s\n' "${action}" >&2; return 2 ;;
    esac
}

# dot::zstyle::list [pattern] — list all zstyle entries (or those matching pattern)
# in re-sourceable form. Example: dot::zstyle::list ':completion:*'
dot::zstyle::list() {
    case "${1:-}" in -h|--help) dot::zstyle::help list; return ;; --) shift ;; -*) printf '%s\n' 'dot::zstyle::list: unknown option' >&2; return 2 ;; esac
    [[ $# -le 2 ]] || { dot::zstyle::help list >&2; return 2; }
    zstyle -L "$@"
}

# dot::zstyle::show <context> <style> — pretty-print the value of a single style.
# Example: dot::zstyle::show ':omz:plugins:ssh-agent' identities
dot::zstyle::show() {
    case "${1:-}" in -h|--help) dot::zstyle::help show; return ;; --) shift ;; -*) printf '%s\n' 'dot::zstyle::show: unknown option' >&2; return 2 ;; esac
    if [[ $# -ne 2 || -z "${1:-}" || -z "${2:-}" ]]; then
        dot::zstyle::help show >&2
        return 2
    fi
    local __ctx="$1" __style="$2" __val=""
    if zstyle -g __val "${__ctx}" "${__style}"; then
        printf '%s %s = %s\n' "${__ctx}" "${__style}" "${__val}"
    else
        printf '%s %s = (unset)\n' "${__ctx}" "${__style}"
        return 1
    fi
}

# dot::zstyle::dump [file] — dump all zstyle entries to stdout or to a file.
dot::zstyle::dump() {
    case "${1:-}" in -h|--help) dot::zstyle::help dump; return ;; --) shift ;; -*) printf '%s\n' 'dot::zstyle::dump: unknown option' >&2; return 2 ;; esac
    [[ $# -le 1 ]] || { dot::zstyle::help dump >&2; return 2; }
    if [[ -n "${1:-}" ]]; then
        zstyle -L > "$1"
    else
        zstyle -L
    fi
}

# ---------------------------------------------------------------------------
# oh-my-zsh: core
# ---------------------------------------------------------------------------

# Auto-update cadence (days). See vendor/oh-my-zsh/tools/check_for_upgrade.sh
zstyle ':omz:update' frequency "${DOT_OMZ_UPDATE_FREQUENCY:-7}"

# ---------------------------------------------------------------------------
# oh-my-zsh: plugins
# ---------------------------------------------------------------------------

# iterm2 — enable shell integration on plugin load
zstyle ':omz:plugins:iterm2' shell-integration yes

# ssh-agent — keys to load and forwarding behaviour.
# SSH_KEYS is populated in zshrc via dot::static::foundation::ssh-identities before dot::static::foundation::load-modules runs.
if (( ${#SSH_KEYS[@]} > 0 )); then
    zstyle ':omz:plugins:ssh-agent' identities "${SSH_KEYS[@]}"
fi
zstyle ':omz:plugins:ssh-agent' agent-forwarding on
zstyle ':omz:plugins:ssh-agent' lifetime "${DOT_SSH_AGENT_LIFETIME:-4h}"

# ---------------------------------------------------------------------------
# Completion system (compsys) — see `man zshcompsys`
# ---------------------------------------------------------------------------

# Cache completion results for slow generators (e.g. apt, brew).
zstyle ':completion::complete:*' use-cache 1

# ---------------------------------------------------------------------------
# Reserved / opt-in styles (uncomment as plugins are enabled)
# ---------------------------------------------------------------------------

# conda-zsh-completion
# zstyle ':conda_zsh_completion:*' use-groups true
# zstyle ':conda_zsh_completion:*' show-unnamed true
# zstyle ':conda_zsh_completion:*' sort-envs-by-time true

# fzf-tab
# zstyle ':fzf-tab:*' fzf-flags '--height=40%' '--reverse'
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'


# bind keys
bindkey -M vicmd v edit-command-line
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line


alias ls='ls --color=always'

# Opt-in syntax highlighting — use these interactively; never set as defaults
# because bat-as-cat/less breaks piped automation and pager detection.
alias ccat='bat --paging=never'   # syntax-highlighted cat (no pager)
alias cless='bat --paging=always' # syntax-highlighted pager

# zle
zle -N create_completion

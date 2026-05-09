# shellcheck shell=bash
#% description: configure zstyle settings for zsh subsystems (compsys, oh-my-zsh, plugins)
#% notes: this module MUST be sourced before oh-my-zsh.sh is sourced from zshrc,
#%        because plugins read their styles at load time. zlib is loaded from
#%        zshrc *before* `. "$ZSH"/oh-my-zsh.sh`, so the ordering is correct.
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

if [[ "${DOT_DISABLE_ZSTYLE}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "zstyle setup is disabled"
    fi
    return
fi

# zstyle is a zsh-only builtin; bail out for other shells.
# Note: don't use getShellName() here — it has inverted logic and would skip zsh.
if [[ -z "${ZSH_VERSION}" ]]; then
    return
fi

# ---------------------------------------------------------------------------
# Helpers — introspect zstyle at runtime
# ---------------------------------------------------------------------------

# zstyleList [pattern] — list all zstyle entries (or those matching pattern)
# in re-sourceable form. Example: zstyleList ':completion:*'
zstyleList() {
    zstyle -L "$@"
}

# zstyleShow <context> <style> — pretty-print the value of a single style.
# Example: zstyleShow ':omz:plugins:ssh-agent' identities
zstyleShow() {
    if [[ $# -lt 2 ]]; then
        echo "usage: zstyleShow <context> <style>" >&2
        return 2
    fi
    local __ctx="$1" __style="$2" __val
    if zstyle -g __val "${__ctx}" "${__style}"; then
        printf '%s %s = %s\n' "${__ctx}" "${__style}" "${__val}"
    else
        printf '%s %s = (unset)\n' "${__ctx}" "${__style}"
        return 1
    fi
}

# zstyleDump [file] — dump all zstyle entries to stdout or to a file.
zstyleDump() {
    if [[ -n "$1" ]]; then
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
# SSH_KEYS is populated in zshrc via getSshIdentities before loadZlib runs.
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

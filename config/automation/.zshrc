#!/bin/zsh
# Minimal automation environment for Copilot / headless task execution.
# NO oh-my-zsh, NO p10k, NO plugins, NO banners, NO splash screens.
# Sourced automatically when ZDOTDIR points here.

# ── Homebrew ──────────────────────────────────────────────────────────────────
if [[ "$(uname -m)" == "arm64" ]]; then
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
else
    [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
fi

# ── Core paths ────────────────────────────────────────────────────────────────
export DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
export DOT_BIN="${DOT_ROOT}/bin"
export PATH="${DOT_BIN}:${HOME}/.local/bin:${HOME}/bin:${PATH}"

# ── Locale / editor ───────────────────────────────────────────────────────────
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-vim}"

# ── Suppress all interactive/decorative dot features ─────────────────────────
export DOT_SPLASH_SCREEN=false
export DOT_DISABLE_OUTPUTS=1
export DOT_DISABLE_P10K=1
export DOT_DISABLE_THEFUCK=1
export DOT_DISABLE_ZSH_AUTOSUGGESTIONS=1
export DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING=1
export DOT_DISABLE_EXTENSIONS=1
export DOT_INTERACTIVE=0

# ── Plain prompt (no p10k / oh-my-zsh decoration) ────────────────────────────
PS1='%~ $ '
PROMPT="${PS1}"

# ── Python (uv / pyenv) ───────────────────────────────────────────────────────
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"
[[ -d "${HOME}/.pyenv/bin" ]] && export PATH="${HOME}/.pyenv/bin:${PATH}"

# ── Node (fnm fast-path, no shell hooks) ─────────────────────────────────────
if command -v fnm &>/dev/null; then
    eval "$(fnm env --use-on-cd=false 2>/dev/null)"
fi

# ── Rust / cargo ──────────────────────────────────────────────────────────────
[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"

# ── GPG ───────────────────────────────────────────────────────────────────────
GPG_TTY=$(tty 2>/dev/null || true)
export GPG_TTY

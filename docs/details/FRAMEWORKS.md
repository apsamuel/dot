# Frameworks

`dot` does not replace shell frameworks — it configures and orchestrates them. Below are the frameworks integrated and how they are used.

---

## ZSH — [oh-my-zsh](https://ohmyz.sh)

The primary ZSH plugin and theme management framework. `dot` uses oh-my-zsh for:

- Built-in plugins (completions, git aliases, colored man pages, etc.)
- Custom plugin directory at `$ZSH_CUSTOM`
- Theme loading (powerlevel10k is loaded as an oh-my-zsh theme)

The plugin list is configured in `config/data.json` under `plugins.builtin` and `plugins.custom`. Bootstrap ensures oh-my-zsh is installed to `~/.oh-my-zsh`.

---

## Tmux — [oh-my-tmux](https://github.com/gpakosz/.tmux)

A self-contained tmux configuration framework vendored in `vendor/ohmytmux/` (canonical) and `vendor/tmux/` (legacy path retained for backwards compatibility). It provides:

- A feature-rich status bar
- Mouse support
- Sane key bindings

`dot` adds tmux helpers in `zlib/001-tmux.sh` (session management, safe session naming, creation from cwd).

---

## Prompt — [powerlevel10k](https://github.com/romkatv/powerlevel10k)

The ZSH prompt theme. `dot` ships a pre-baked `p10k.zsh` configuration at `config/shell/p10k.zsh`, symlinked to `~/.p10k.zsh` by bootstrap. This means you get a sensible, fast prompt without running the interactive wizard.

Powerlevel10k is vendored directly in `vendor/powerlevel10k/` so it is available immediately after bootstrap without requiring oh-my-zsh's plugin installation step.

Requires a [Nerd Font](https://www.nerdfonts.com) in your terminal emulator to render icons correctly.

---

## Fuzzy Finding — [fzf](https://github.com/junegunn/fzf) + [fzf-git](https://github.com/junegunn/fzf-git.sh)

`fzf` is the fuzzy finder wired into shell history, file selection, and process listing. `fzf-git` (vendored in `vendor/fzf-git/`) extends fzf to cover common git operations:

- Browse branches, tags, and remotes
- Preview diffs interactively
- Stage, unstash, and navigate the reflog

Configured in `zlib/999-a-terminal.sh`.

---

## Shell Utilities — [bash-commons](https://github.com/gruntwork-io/bash-commons)

Vendored in `vendor/bash-commons/`. Provides reusable, tested bash functions for logging, assertions, OS detection, and string manipulation. Used internally by `dot` shell scripts.

---

## Language Environments

`dot` manages language runtimes through dedicated `zlib` modules:

| Language | Toolchain | Module |
|---|---|---|
| Python | [uv](https://github.com/astral-sh/uv) venvs | `zlib/001-d-python.sh` |
| Node.js | Homebrew + `n` | `zlib/001-d-node.sh` |
| Rust | [rustup](https://rustup.rs) via Homebrew | `zlib/001-d-rust.sh` |
| Java | [jenv](https://www.jenv.be) | `zlib/001-z-java.sh` |

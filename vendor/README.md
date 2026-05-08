# Vendor

This directory contains vendored third-party projects that `dot` depends on. They are checked in as git submodules so the framework works reliably without requiring external downloads at install time.

---

## Submodules

| Directory | Upstream | Purpose |
|-----------|----------|---------|
| `bash-commons/` | [gruntwork-io/bash-commons](https://github.com/gruntwork-io/bash-commons) | Gruntwork's reusable Bash utility library — shared helpers for logging, assertions, string manipulation, and OS detection. Used by bootstrap and bin scripts. |
| `figlet-fonts/` | [xero/figlet-fonts](https://github.com/xero/figlet-fonts) | A curated collection of figlet fonts used by `toFiglet` in `zlib/000-a-output.sh`. |
| `fzf-git/` | [junegunn/fzf-git.sh](https://github.com/junegunn/fzf-git.sh) | Key bindings that pipe `git` objects (branches, commits, stashes, tags, remotes) into `fzf` for fuzzy interactive selection. Sourced by `000-a-vendor.sh`. |
| `oh-my-tmux/` | [apsamuel/.tmux](https://github.com/apsamuel/.tmux) (fork of [gpakosz/.tmux](https://github.com/gpakosz/.tmux)) | Oh My Tmux configuration — opinionated tmux base config with a status bar and keybinding improvements. |
| `oh-my-zsh/` | [apsamuel/ohmyzsh](https://github.com/apsamuel/ohmyzsh) (fork of [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)) | The Oh My Zsh framework — plugin system, themes, and completions. Vendored for stability so upstream changes don't break the shell environment. |

---

## Oh My Zsh Custom Plugins & Themes

The following are installed into `oh-my-zsh/custom/` (plugins under `plugins/`, theme under `themes/`):

| Name | Upstream | Purpose |
|------|----------|---------|
| `powerlevel10k` | [romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) | Powerlevel10k ZSH prompt theme. Sourced by `zlib/001-a-p10k.sh`. |
| `fzf-tab` | [Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) | Replace zsh's default completion menu with fzf. |
| `zsh-autosuggestions` | [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style command suggestions as you type. |
| `zsh-vi-mode` | [jeffreytse/zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) | Better vi mode for ZSH with cursor shape switching and text objects. |
| `zsh_codex` | [tom-doerr/zsh_codex](https://github.com/tom-doerr/zsh_codex) | AI-powered inline command completion via OpenAI. |
| `F-Sy-H` | [z-shell/F-Sy-H](https://github.com/z-shell/F-Sy-H) | Feature-rich syntax highlighting for ZSH. |
| `navi` | [denisidoro/navi](https://github.com/denisidoro/navi) | Interactive cheatsheet tool with fzf integration. |
| `conda-zsh-completion` | [conda-incubator/conda-zsh-completion](https://github.com/conda-incubator/conda-zsh-completion) | ZSH completions for conda. |

---

> All submodules are vendored rather than dynamically installed so that a fresh bootstrap produces an identical environment regardless of network availability or upstream changes.

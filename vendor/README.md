# Vendor

This directory contains vendored third-party projects that `dot` depends on. They are checked in (as git submodules or clones) so the framework works reliably without requiring external downloads at install time.

---

## Contents

| Directory | Upstream | Purpose |
|-----------|----------|---------|
| `bash-commons/` | [gruntwork-io/bash-commons](https://github.com/gruntwork-io/bash-commons) | Gruntwork's reusable Bash utility library — shared helpers for logging, assertions, string manipulation, and OS detection. Used by bootstrap and bin scripts. |
| `fzf-git/` | [junegunn/fzf-git.sh](https://github.com/junegunn/fzf-git.sh) | Key bindings that pipe `git` objects (branches, commits, stashes, tags, remotes) into `fzf` for fuzzy interactive selection. Sourced by `000-a-vendor.sh`. |
| `ohmytmux/` | [apsamuel/.tmux](https://github.com/apsamuel/.tmux) (fork of [gpakosz/.tmux](https://github.com/gpakosz/.tmux)) | Oh My Tmux configuration — opinionated tmux base config with a status bar and keybinding improvements. Canonical vendored name for this submodule. |
| `ohmyzsh/` | [apsamuel/ohmyzsh](https://github.com/apsamuel/ohmyzsh) (fork of [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)) | The Oh My Zsh framework — plugin system, themes, and completions. Vendored for stability so upstream changes don't break the shell environment. |
| `powerlevel10k/` | [romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) | The Powerlevel10k ZSH prompt theme. Vendored directly so the prompt is available immediately after bootstrap without relying on oh-my-zsh's plugin installation. |
| `tmux/` | [apsamuel/.tmux](https://github.com/apsamuel/.tmux) (fork of [gpakosz/.tmux](https://github.com/gpakosz/.tmux)) | Oh My Tmux configuration — legacy submodule path retained for backwards compatibility. See `ohmytmux/` for the canonical entry. |

---

> All six projects are vendored rather than dynamically installed so that a fresh bootstrap produces an identical environment regardless of network availability or upstream changes.

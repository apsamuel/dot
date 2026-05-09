# 🌱 Frameworks

`dot` does not replace shell frameworks — it **configures, vendors, and orchestrates** them. Every framework below is a pinned **git submodule** under [`vendor/`](../../vendor/README.md). Update them all in parallel with [`scripts/submodule-sync.sh`](../../scripts/README.md).

---

## 🐚 [oh-my-zsh](https://ohmyz.sh)

The primary ZSH plugin and theme manager.

- 📍 **Location:** `vendor/oh-my-zsh/` (NOT `~/.oh-my-zsh`)
- 🔧 `ZSH=$HOME/.dot/vendor/oh-my-zsh`, `ZSH_CUSTOM=$ZSH/custom`
- 🧾 Plugin list lives in [`data/zsh.yaml`](../../data/zsh.yaml) under `zsh.plugins.{builtin,custom}` — each custom plugin has an `enabled: true|false` flag
- 🐈 Fork: [`apsamuel/oh-my-zsh`](https://github.com/apsamuel/oh-my-zsh)

Custom plugins/themes are themselves nested submodules under `vendor/oh-my-zsh/custom/`:
`powerlevel10k`, `fzf-tab`, `zsh-autosuggestions`, `zsh-vi-mode`, `zsh_codex`, `F-Sy-H`, `navi`, `conda-zsh-completion`.

---

## 🪟 [oh-my-tmux](https://github.com/gpakosz/.tmux)

Tmux configuration framework.

- 📍 **Location:** `vendor/oh-my-tmux/`
- 🔌 TPM root: `TMUX_PLUGIN_MANAGER_PATH=$DOT_ROOT/vendor/oh-my-tmux/plugins`
- 🧾 TPM plugin list lives in `data/zsh.yaml` under `tmux.plugins`
- 🐈 Fork: [`apsamuel/.tmux`](https://github.com/apsamuel/.tmux)
- 🧩 `dot` helpers: [`modules/001-a-tmux.sh`](../../modules/001-a-tmux.sh) (session management, safe session naming, cwd-derived sessions)

---

## ⚡ [powerlevel10k](https://github.com/romkatv/powerlevel10k)

ZSH prompt theme.

- 📍 **Location:** `vendor/oh-my-zsh/custom/themes/powerlevel10k/`
- 🎨 Pre-baked config at [`config/shell/p10k.zsh`](../../config/shell/p10k.zsh) → symlinked to `~/.p10k.zsh` by bootstrap (no wizard, no waiting)
- 🚀 Activated in [`modules/001-a-p10k.sh`](../../modules/001-a-p10k.sh)
- 🔤 Requires a [Nerd Font](https://www.nerdfonts.com) in your terminal emulator

---

## 🔍 [fzf](https://github.com/junegunn/fzf) + [fzf-git](https://github.com/junegunn/fzf-git.sh)

- 🍺 `fzf` is installed via Homebrew (Brewfile)
- 📍 `fzf-git` is vendored at `vendor/fzf-git/`
- 🌳 Adds interactive UI for git branches, tags, remotes, diffs, stage/unstash, reflog
- ⚙️ Wired in [`modules/999-a-terminal.sh`](../../modules/999-a-terminal.sh)

---

## 🛠 [bash-commons](https://github.com/gruntwork-io/bash-commons)

Reusable, tested bash helpers (logging, assertions, OS detection, string manipulation).

- 📍 **Location:** `vendor/bash-commons/`
- 🔧 Used internally by scripts under [`bin/`](../../bin/README.md)

---

## 🔠 [figlet-fonts](https://github.com/xero/figlet-fonts)

Curated figlet font collection used by the `toFiglet` helper.

- 📍 **Location:** `vendor/figlet-fonts/`

---

## 🧬 Language Environments

`dot` manages language runtimes through dedicated `modules/` files. Their package lists live in [`data/zsh.yaml`](../../data/zsh.yaml) under `languages.*` and are installed when `DOT_INSTALL_LANG_DEPS=1`.

| Language  | Toolchain                                     | Module                                                     |
| --------- | --------------------------------------------- | ---------------------------------------------------------- |
| 🐍 Python  | [`uv`](https://github.com/astral-sh/uv) venvs | [`modules/001-d-python.sh`](../../modules/001-d-python.sh) |
| 🟢 Node.js | Homebrew + `fnm`/`n`                          | [`modules/001-d-node.sh`](../../modules/001-d-node.sh)     |
| 🦀 Rust    | [`rustup`](https://rustup.rs) via Homebrew    | [`modules/001-d-rust.sh`](../../modules/001-d-rust.sh)     |
| ☕ Java    | [`jenv`](https://www.jenv.be)                 | [`modules/001-z-java.sh`](../../modules/001-z-java.sh)     |

---

## 🔄 Keeping Frameworks in Sync

Every framework above is a **git submodule** so that upstream renames, archives, or breaking changes can never wreck a fresh `dot` install. Use the [submodule-sync helper](../../scripts/README.md):

```bash
./scripts/submodule-sync.sh status     # report
./scripts/submodule-sync.sh update     # pull latest tracked branches
./scripts/submodule-sync.sh init       # first-time fetch
```

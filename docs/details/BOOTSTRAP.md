# 🚀 Bootstrap

## 🌑 Overview

[`bin/dot-bootstrap.sh`](../../bin/dot-bootstrap.sh) is the first-run script that installs and configures `dot` from scratch. It is **idempotent** — running it again is safe and converges on the same state.

## 🧪 Usage

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/apsamuel/dot.git ~/.dot

# Preview every action without changing your system
DOT_DRY_RUN=1 source ~/.dot/bin/dot-bootstrap.sh
# or
~/.dot/bin/dot-bootstrap.sh -n

# Real run
source ~/.dot/bin/dot-bootstrap.sh

# Force install / refresh of bootstrap dependencies (brew, gh, yq…)
DOT_DEPS=1 source ~/.dot/bin/dot-bootstrap.sh

# Install language deps (Python via uv, Node via npm) declared in data/zsh.yaml
DOT_INSTALL_LANG_DEPS=1 source ~/.dot/bin/dot-bootstrap.sh
```

> 🚨 Source it (`source …`) — don't execute it. The script exports environment variables that need to land in your current shell.

## 🧭 What It Does

1. ✅ Validates `$HOME`, `$USER`, and the project directory.
2. 📚 Sources `zlib/static/lib/internal.sh` for shared helpers.
3. 🍺 Resolves the **Brewfile** (`data/Brewfile`, falling back to iCloud).
4. 🧰 Installs **bootstrap dependencies**: Homebrew, `gh`, and `yq` (the YAML parser is required because `data/zsh.yaml` is the runtime source of truth).
5. 🔗 Symlinks `~/.dot/zshrc` → `~/.zshrc` (existing file → `~/.zshrc.bak`).
6. 🔗 Symlinks `~/.dot/config/shell/p10k.zsh` → `~/.p10k.zsh`.
7. 🌥 Creates a `~/iCloud` shortcut on macOS.
8. 🍺 If `DOT_DEPS=1`, runs `brew bundle` against the Brewfile.
9. 🌱 Initialises **vendored submodules** under `vendor/` (oh-my-zsh, oh-my-tmux, fzf-git, bash-commons, figlet-fonts, plus all nested oh-my-zsh custom plugins/themes).
10. 🐚 Wires up oh-my-zsh from `vendor/oh-my-zsh` (`ZSH=$HOME/.dot/vendor/oh-my-zsh`, `ZSH_CUSTOM=$ZSH/custom`).
11. 🪟 Wires up oh-my-tmux from `vendor/oh-my-tmux` and sets `TMUX_PLUGIN_MANAGER_PATH=$DOT_ROOT/vendor/oh-my-tmux/plugins`.
12. 🍎 Builds [`bin/applevm-helper`](../../bin/apple-vm-helper/README.md) when Xcode CLT is present.
13. 🐍 If `DOT_INSTALL_LANG_DEPS=1`, seeds Python (via `uv`) and Node (via `npm`) from `data/zsh.yaml`.

## 🎚️ Environment Variables

| 🔧 Variable                | Default                               | Effect                                                   |
| -------------------------- | ------------------------------------- | -------------------------------------------------------- |
| `DOT_DRY_RUN`              | `0`                                   | Print every action without executing                     |
| `DOT_DEPS`                 | `0`                                   | Force install / refresh of bootstrap deps (brew, gh, yq) |
| `DOT_INSTALL_LANG_DEPS`    | `0`                                   | Install language deps from `data/zsh.yaml`               |
| `DOT_NVM_INSTALL_LTS`      | `0`                                   | Install Node.js LTS via `nvm`                            |
| `ICLOUD`                   | `~/iCloud`                            | iCloud Drive path                                        |
| `ZSH`                      | `$HOME/.dot/vendor/oh-my-zsh`         | Vendored oh-my-zsh root                                  |
| `ZSH_CUSTOM`               | `$ZSH/custom`                         | oh-my-zsh custom directory                               |
| `TMUX_PLUGIN_MANAGER_PATH` | `$DOT_ROOT/vendor/oh-my-tmux/plugins` | TPM root                                                 |

## 🚚 Deploy Flags

`dot-bootstrap.sh` exposes deploy shortcuts (matching the standalone scripts under `bin/`):

| Flag               | Equivalent                                               | Effect                                                  |
| ------------------ | -------------------------------------------------------- | ------------------------------------------------------- |
| `-d`               | [`dot-deploy-config.sh`](../../bin/dot-deploy-config.sh) | Push `data/zsh.yaml` → `$ICLOUD/dot/shell/zsh/zsh.yaml` |
| `-r`               | [`dot-deploy-rc.sh`](../../bin/dot-deploy-rc.sh)         | Push `zshrc` → `$ICLOUD/dot/shell/zsh/rc`               |
| `-n` / `--dry-run` | `DOT_DRY_RUN=1`                                          | Preview only                                            |

## 🌱 Submodule Workflow

`dot-bootstrap.sh` calls into [`scripts/submodule-sync.sh`](../../scripts/README.md) to fetch and update every submodule. Use it directly afterwards to keep the tree in sync:

```bash
./scripts/submodule-sync.sh init     # first-time fetch (root + nested, parallel)
./scripts/submodule-sync.sh update   # pull latest tracked branches
./scripts/submodule-sync.sh status   # report dirty/clean/missing
./scripts/submodule-sync.sh list     # paths only
```

Flags: `-n` dry-run, `-v` verbose, `-j N` parallel jobs. SSH→HTTPS rewriting is automatic.

## 🍎 Apple VM Backend (vmctl)

[`bin/ivm.py`](../../bin/ivm.py) drives Apple `Virtualization.framework` VMs through one of two providers:

### 🥇 Native Helper (Recommended)

[`bin/applevm-helper`](../../bin/apple-vm-helper/README.md) is a compiled Swift binary that speaks directly to Virtualization.framework. Full lifecycle: start, stop (graceful), suspend, resume, status.

```bash
cd ~/.dot/bin/apple-vm-helper && swift build -c release
cp .build/release/applevm-helper ~/.dot/bin/
python3 ~/.dot/bin/ivm.py backends    # → "apple yes swift-native: <version>"
```

| 🔧 Variable                        | Effect                                            |
| ---------------------------------- | ------------------------------------------------- |
| `IVM_APPLE_PROVIDER=swift-native`  | Force native provider; fail loudly if unavailable |
| `IVM_APPLE_PROVIDER=vz`            | Force vz fallback; fail if unavailable            |
| `IVM_APPLE_HELPER=/path/to/helper` | Custom path to native helper                      |

### 🥈 Fallback (vz CLI)

```bash
brew install Code-Hex/tap/vz
```

Limitations: SIGTERM stop, no suspend/resume, status only checks bundle presence.

## 🗂️ After Bootstrap

```text
~/
├── .zshrc          → ~/.dot/zshrc                              (symlink)
├── .p10k.zsh       → ~/.dot/config/shell/p10k.zsh              (symlink)
└── iCloud          → ~/Library/Mobile Documents/com~apple~CloudDocs

~/.dot/vendor/
├── oh-my-zsh/                  ← $ZSH (vendored, NOT ~/.oh-my-zsh)
│   └── custom/
│       ├── themes/powerlevel10k/
│       └── plugins/{zsh-autosuggestions,fzf-tab,F-Sy-H,zsh-vi-mode,zsh_codex,navi,conda-zsh-completion}/
├── oh-my-tmux/                 ← TMUX_PLUGIN_MANAGER_PATH=$_/plugins
├── fzf-git/
├── bash-commons/
└── figlet-fonts/
```

## 🧪 Re-running Bootstrap

```bash
source ~/.dot/bin/dot-bootstrap.sh                         # symlinks + checks
DOT_DEPS=1 source ~/.dot/bin/dot-bootstrap.sh              # also refresh brew/gh/yq
DOT_INSTALL_LANG_DEPS=1 source ~/.dot/bin/dot-bootstrap.sh # plus language deps
DOT_DRY_RUN=1 source ~/.dot/bin/dot-bootstrap.sh           # preview only
```

## 🧯 Troubleshooting

- 🔗 **`~/.zshrc` not updated** — clean any stale `~/.zshrc.bak` and rerun.
- 🍺 **Brew packages missing** — `DOT_DEPS=1` or run `brew bundle --file=~/.dot/data/Brewfile`.
- 🌱 **Vendored submodules missing** — `./scripts/submodule-sync.sh init`.
- 🧾 **`yq: command not found`** — `brew install yq`, then re-source `~/.zshrc`.

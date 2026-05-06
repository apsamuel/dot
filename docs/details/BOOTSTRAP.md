# Bootstrap

## Overview

`dot-bootstrap.sh` is the first-run script that installs and configures the `dot` framework from scratch. It is designed to be idempotent — running it multiple times will not break an already-configured environment.

## Usage

```bash
# From the repo root
source ./bin/dot-bootstrap.sh

# Or after cloning
git clone https://github.com/apsamuel/dot.git ~/.dot
pushd ~/.dot && source ./bin/dot-bootstrap.sh
```

> Bootstrap must be sourced (not executed) so that environment variables it sets persist in the current shell.

## What It Does

1. **Validates the environment** — checks that `$HOME`, `$USER`, and the project directory are present.
2. **Sources internal helpers** — loads `zlib/static/lib/internal.sh` for shared utilities.
3. **Resolves the Brewfile** — looks for `data/Brewfile` locally, then falls back to iCloud if present.
4. **Symlinks `zshrc`** — links `~/.dot/zshrc` → `~/.zshrc`, backing up any existing file to `~/.zshrc.bak`.
5. **Symlinks `p10k.zsh`** — links the pre-baked powerlevel10k configuration to `~/.p10k.zsh`.
6. **Sets up iCloud shortcut** — creates a `~/iCloud` symlink for convenience if iCloud Drive is present.
7. **Installs Homebrew dependencies** — runs `brew bundle` against the Brewfile if `DOT_DEPS` is set.
8. **Sets up vendor libraries** — ensures `vendor/` submodules are initialized.

## Environment Variables

| Variable | Default | Effect |
|---|---|---|
| `DOT_DEPS` | `0` | Set to `1` to install Homebrew dependencies during bootstrap |
| `ICLOUD` | `~/iCloud` | Override the iCloud Drive path |
| `ZSH` | `~/.oh-my-zsh` | oh-my-zsh installation directory |
| `ZSH_CUSTOM` | `~/.oh-my-zsh/custom` | oh-my-zsh custom directory for themes and plugins |

## Manually Re-running Parts of Bootstrap

If you want to re-run only the symlink setup without reinstalling packages:

```bash
source ~/.dot/bin/dot-bootstrap.sh
```

If you want to also install/update Homebrew dependencies:

```bash
DOT_DEPS=1 source ~/.dot/bin/dot-bootstrap.sh
```

## Directory Layout After Bootstrap

```
~/
├── .zshrc          → ~/.dot/zshrc          (symlink)
├── .p10k.zsh       → ~/.dot/config/shell/p10k.zsh  (symlink)
├── .oh-my-zsh/     (installed by oh-my-zsh installer if missing)
└── iCloud          → ~/Library/Mobile Documents/com~apple~CloudDocs  (symlink, macOS only)
```

## Troubleshooting

- **`~/.zshrc` not updated** — check if a stale backup (`~/.zshrc.bak`) exists that needs to be cleaned up manually.
- **Homebrew packages not installed** — ensure `DOT_DEPS=1` is exported, or run `brew bundle --file=~/.dot/data/Brewfile` directly.
- **Symlinks point to wrong location** — delete the broken symlink (`rm ~/.zshrc`) and re-run bootstrap.

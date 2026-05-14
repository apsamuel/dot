# vendor/

Pinned third-party projects and forks used by `dot`.

All entries are git submodules so bootstrap remains reproducible and deterministic.

- Root-level submodules are defined in `.gitmodules`.
- Nested oh-my-zsh plugin/theme submodules are defined in `vendor/oh-my-zsh/.gitmodules`.

## Root Vendored Submodules

### Managed by `apsamuel` Origin

| Directory     | Upstream URL                               | Origin Type                   | Purpose                                      |
| ------------- | ------------------------------------------ | ----------------------------- | -------------------------------------------- |
| `oh-my-zsh/`  | `git@github.com:apsamuel/ohmyzsh.git`      | Fork maintained by `apsamuel` | Core plugin/theme framework used by `zshrc`. |
| `oh-my-tmux/` | `git@github.com:apsamuel/.tmux.git`        | Fork maintained by `apsamuel` | Tmux framework + TPM integration baseline.   |
| `vim/`        | `git@github-personal.com:apsamuel/vim.git` | Private/managed by `apsamuel` | Personal Vim config integration repository.  |

### Public Upstream Projects

| Directory       | Upstream URL                                   | Origin Type     | Purpose                              |
| --------------- | ---------------------------------------------- | --------------- | ------------------------------------ |
| `fzf-git/`      | `git@github.com:junegunn/fzf-git.sh.git`       | Public upstream | Fuzzy git workflow helpers.          |
| `bash-commons/` | `git@github.com:gruntwork-io/bash-commons.git` | Public upstream | Reusable shell utility library.      |
| `figlet-fonts/` | `git@github.com:xero/figlet-fonts.git`         | Public upstream | Fonts used by output/splash helpers. |

## Nested oh-my-zsh Submodules

These live under `vendor/oh-my-zsh/custom/`.

| Path                                  | Upstream                        | Kind   | Default in `data/zsh.yaml` |
| ------------------------------------- | ------------------------------- | ------ | -------------------------- |
| `custom/themes/powerlevel10k`         | `romkatv/powerlevel10k`         | Theme  | Enabled                    |
| `custom/plugins/zsh-autosuggestions`  | `zsh-users/zsh-autosuggestions` | Plugin | Enabled                    |
| `custom/plugins/F-Sy-H`               | `z-shell/F-Sy-H`                | Plugin | Enabled                    |
| `custom/plugins/fzf-tab`              | `Aloxaf/fzf-tab`                | Plugin | Disabled                   |
| `custom/plugins/navi`                 | `denisidoro/navi`               | Plugin | Disabled                   |
| `custom/plugins/zsh-vi-mode`          | `jeffreytse/zsh-vi-mode`        | Plugin | Disabled                   |
| `custom/plugins/zsh_codex`            | `tom-doerr/zsh_codex`           | Plugin | Disabled                   |
| `custom/plugins/conda-zsh-completion` | `esc/conda-zsh-completion`      | Plugin | Disabled                   |

## Submodule Management

Use `scripts/submodule-sync.sh` (or `dot.shell vendor`) to manage both root and nested submodules.

```bash
scripts/submodule-sync.sh init
scripts/submodule-sync.sh update
scripts/submodule-sync.sh status
scripts/submodule-sync.sh list
```

## Makefile Interface

Each managed vendor has its own `Makefile` with a consistent developer experience.
All vendor Makefiles share these conventions:

| Convention              | Details                                                      |
| ----------------------- | ------------------------------------------------------------ |
| Self-documenting `help` | `make` (or `make help`) prints all targets with descriptions |
| Dry-run support         | `DOT_DRY_RUN=1 make <target>` — preview without mutations    |
| Debug tracing           | `DOT_DEBUG=1 make <target>` — enable bash `set -x`           |
| Verbose output          | `DOT_VERBOSE=1 make <target>` — verbose git/build output     |
| Idempotent operations   | Re-running any target is safe; guards prevent duplicate work |
| Doctor target           | `make doctor` — read-only health check, always safe to run   |

### Root Makefile Propagation

The root `Makefile` provides passthrough targets (`vim-*`, `omz-*`, `tmux-*`)
that forward to vendor Makefiles with flag propagation:

```
DRY=1 make vim-install
       ↓ propagates as ↓
cd vendor/vim && DOT_DRY_RUN=1 DOT_DEBUG=0 DOT_VERBOSE=0 make install
```

### Per-Vendor Targets

| Vendor        | Makefile                     | Key Targets                                                           | Docs                                               |
| ------------- | ---------------------------- | --------------------------------------------------------------------- | -------------------------------------------------- |
| `vim/`        | `vendor/vim/Makefile`        | `install`, `update`, `build`, `add`, `rm`, `list`, `doctor`           | [vim/README.md](./vim/README.md)                   |
| `oh-my-tmux/` | `vendor/oh-my-tmux/Makefile` | `install`, `clean`, `update`, `add-plugin`, `remove-plugin`, `doctor` | [oh-my-tmux/MAKEFILE.md](./oh-my-tmux/MAKEFILE.md) |
| `oh-my-zsh/`  | `vendor/oh-my-zsh/Makefile`  | `install`, `add-plugin`, `add-theme`, `sync-plugins`, `doctor`        | [oh-my-zsh/MAKEFILE.md](./oh-my-zsh/MAKEFILE.md)   |
| `iterm2/`     | _(managed by root Makefile)_ | `config-iterm` (root target)                                          | [iterm2/README.md](./iterm2/README.md)             |

## Related Docs

- `scripts/README.md`
- `docs/details/BOOTSTRAP.md`
- `data/zsh.yaml`

# vendor/

Pinned third-party projects and forks used by `dot`.

All entries are git submodules so bootstrap remains reproducible and deterministic.

- Root-level submodules are defined in `.gitmodules`.
- Nested oh-my-zsh plugin/theme submodules are defined in `vendor/oh-my-zsh/.gitmodules`.

## Root Vendored Submodules

### Managed by `apsamuel` Origin

| Directory | Upstream URL | Origin Type | Purpose |
| --- | --- | --- | --- |
| `oh-my-zsh/` | `git@github.com:apsamuel/ohmyzsh.git` | Fork maintained by `apsamuel` | Core plugin/theme framework used by `zshrc`. |
| `oh-my-tmux/` | `git@github.com:apsamuel/.tmux.git` | Fork maintained by `apsamuel` | Tmux framework + TPM integration baseline. |
| `vim/` | `git@github-personal.com:apsamuel/vim.git` | Private/managed by `apsamuel` | Personal Vim config integration repository. |

### Public Upstream Projects

| Directory | Upstream URL | Origin Type | Purpose |
| --- | --- | --- | --- |
| `fzf-git/` | `git@github.com:junegunn/fzf-git.sh.git` | Public upstream | Fuzzy git workflow helpers. |
| `bash-commons/` | `git@github.com:gruntwork-io/bash-commons.git` | Public upstream | Reusable shell utility library. |
| `figlet-fonts/` | `git@github.com:xero/figlet-fonts.git` | Public upstream | Fonts used by output/splash helpers. |
| `iterm-themes/` | `git@github.com:mbadolato/iTerm2-Color-Schemes.git` | Public upstream | iTerm2 color scheme catalog. |

## Nested oh-my-zsh Submodules

These live under `vendor/oh-my-zsh/custom/`.

| Path | Upstream | Kind | Default in `data/zsh.yaml` |
| --- | --- | --- | --- |
| `custom/themes/powerlevel10k` | `romkatv/powerlevel10k` | Theme | Enabled |
| `custom/plugins/zsh-autosuggestions` | `zsh-users/zsh-autosuggestions` | Plugin | Enabled |
| `custom/plugins/F-Sy-H` | `z-shell/F-Sy-H` | Plugin | Enabled |
| `custom/plugins/fzf-tab` | `Aloxaf/fzf-tab` | Plugin | Disabled |
| `custom/plugins/navi` | `denisidoro/navi` | Plugin | Disabled |
| `custom/plugins/zsh-vi-mode` | `jeffreytse/zsh-vi-mode` | Plugin | Disabled |
| `custom/plugins/zsh_codex` | `tom-doerr/zsh_codex` | Plugin | Disabled |
| `custom/plugins/conda-zsh-completion` | `esc/conda-zsh-completion` | Plugin | Disabled |

## Submodule Management

Use `scripts/submodule-sync.sh` (or `dot.shell vendor`) to manage both root and nested submodules.

```bash
scripts/submodule-sync.sh init
scripts/submodule-sync.sh update
scripts/submodule-sync.sh status
scripts/submodule-sync.sh list
```

## Related Docs

- `scripts/README.md`
- `docs/details/BOOTSTRAP.md`
- `data/zsh.yaml`

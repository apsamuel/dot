# 📜 scripts/

Repository maintenance scripts. Unlike [`bin/`](../bin/README.md) (user-facing tooling on `$PATH`), `scripts/` contains **maintainer utilities** that operate on the `dot` repository itself.

---

## 🌱 [`submodule-sync.sh`](submodule-sync.sh)

Manage every submodule in the repo — both **root-level** (`vendor/oh-my-zsh`, `vendor/oh-my-tmux`, `vendor/fzf-git`, `vendor/bash-commons`, `vendor/figlet-fonts`) and **nested** (powerlevel10k, fzf-tab, F-Sy-H, navi, zsh-autosuggestions, zsh-vi-mode, zsh_codex, conda-zsh-completion under `vendor/oh-my-zsh/custom/`).

### 🧭 Subcommands

| Command  | Effect                                                               |
| -------- | -------------------------------------------------------------------- |
| `status` | Report checkout state for every submodule (root + nested)            |
| `init`   | Initialise + recursively fetch all submodules (first-time bootstrap) |
| `update` | Pull latest tracked branch for every submodule                       |
| `list`   | Print all registered paths and remote URLs                           |

### 🎚️ Flags

| Flag   | Effect                                                 |
| ------ | ------------------------------------------------------ |
| `-n`   | Dry-run — print commands instead of executing          |
| `-v`   | Verbose — pass `--verbose` to `git submodule`          |
| `-j N` | Parallel jobs for `git submodule update` (default `4`) |
| `-h`   | Help                                                   |

### 🧪 Examples

```bash
./scripts/submodule-sync.sh status                   # full report
./scripts/submodule-sync.sh init -j 8                # parallel first-time fetch
./scripts/submodule-sync.sh update                   # pull latest everywhere
./scripts/submodule-sync.sh update vendor/oh-my-zsh  # target a single path
./scripts/submodule-sync.sh -n update                # preview only
./scripts/submodule-sync.sh list                     # paths + URLs
```

### 🔑 SSH → HTTPS Rewriting

If your `ssh-agent` has no loaded identities, SSH-style submodule URLs (`git@github.com:owner/repo.git`) are **automatically rewritten to HTTPS** (`https://github.com/owner/repo.git`) so that `init`/`update` cannot hang waiting for SSH auth. Original `.gitmodules` entries are left untouched.

### 🪆 Two-Step Nested Handling

`init` runs in two passes:

1. **Root submodules** — `git submodule update --init` against `.gitmodules` at the repo root.
2. **Nested submodules** — for each submodule that itself has `.gitmodules` (notably `vendor/oh-my-zsh`), recurse into it and initialise its children.

This avoids the silent partial-checkout problem of `git submodule update --init --recursive` when nested URLs need rewriting.

---

## 🔗 Related

| Doc                                                           | Purpose                                            |
| ------------------------------------------------------------- | -------------------------------------------------- |
| [`vendor/README.md`](../vendor/README.md)                     | Inventory of vendored libraries                    |
| [`docs/details/FRAMEWORKS.md`](../docs/details/FRAMEWORKS.md) | Why each framework is vendored                     |
| [`docs/details/BOOTSTRAP.md`](../docs/details/BOOTSTRAP.md)   | First-run flow that calls into `submodule-sync.sh` |

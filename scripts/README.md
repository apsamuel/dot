# 📜 scripts/

Repository maintenance scripts. Unlike [`bin/`](../bin/README.md) (user-facing tooling on `$PATH`), `scripts/` contains **maintainer utilities** that operate on the `dot` repository itself — first-run bootstrap, iCloud config deployment, submodule management, and host dependency auditing.

---

## 🚀 [`dot-bootstrap.sh`](dot-bootstrap.sh)

First-run installer — installs deps, symlinks configs, vendors `oh-my-zsh` & `oh-my-tmux`, sets `TMUX_PLUGIN_MANAGER_PATH`. Supports `DOT_DRY_RUN=1` / `-n` / `--dry-run`. Idempotent — safe to re-run. Full reference: [BOOTSTRAP.md](../docs/details/BOOTSTRAP.md).

```bash
DOT_DRY_RUN=1 source ./scripts/dot-bootstrap.sh   # preview
source ./scripts/dot-bootstrap.sh                 # apply
DOT_INSTALL_LANG_DEPS=1 source ./scripts/dot-bootstrap.sh   # +pip/npm seed
```

---

## 🌥 [`dot-deploy-config.sh`](dot-deploy-config.sh) & [`dot-deploy-rc.sh`](dot-deploy-rc.sh)

Mirror the repo's runtime config and shell rc to the iCloud Drive copy used as the cross-machine source of truth.

| Script                                           | Effect                                              |
| ------------------------------------------------ | --------------------------------------------------- |
| [`dot-deploy-config.sh`](./dot-deploy-config.sh) | `cp data/zsh.yaml → $ICLOUD/dot/shell/zsh/zsh.yaml` |
| [`dot-deploy-rc.sh`](./dot-deploy-rc.sh)         | `cp zshrc → $ICLOUD/dot/shell/zsh/rc`               |

Both require `$ICLOUD` to be exported (the bootstrap step links `~/Library/Mobile Documents/com~apple~CloudDocs` → `~/iCloud`).

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

## 🩺 [`dot-deps-report.sh`](dot-deps-report.sh)

Audit the host for the system dependencies catalogued in [`docs/details/DEPENDENCIES.md`](../docs/details/DEPENDENCIES.md). The script carries its own tier table — every entry is checked with `command -v` and reported as `🟢 ok`, `🟠 missing (optional)`, or `🔴 missing (REQUIRED)`.

### 🎚️ Flags

| Flag           | Effect                                               |
| -------------- | ---------------------------------------------------- |
| `--tier <N>`   | Restrict the audit to a single tier (`0`–`4`)        |
| `-q`/`--quiet` | Print only the missing items                         |
| `--json`       | Emit machine-readable JSON (`results[]` + `summary`) |
| `--list`       | Dump the in-script tier table verbatim and exit      |
| `-h`/`--help`  | Help                                                 |

### 🚦 Exit codes

| Code | Meaning                                                        |
| ---- | -------------------------------------------------------------- |
| `0`  | All Tier 0 required tools present (optional gaps allowed)      |
| `1`  | At least one Tier 0 required tool is missing — safe to gate CI |
| `2`  | Bad usage                                                      |

### 🧪 Examples

```bash
./scripts/dot-deps-report.sh                 # full audit, human-readable
./scripts/dot-deps-report.sh --tier 0        # essentials only
./scripts/dot-deps-report.sh -q              # show only what's missing
./scripts/dot-deps-report.sh --json | jq     # machine-readable summary
./scripts/dot-deps-report.sh --list          # dump tier table
```

---

## 🔗 Related

| Doc                                                               | Purpose                                            |
| ----------------------------------------------------------------- | -------------------------------------------------- |
| [`vendor/README.md`](../vendor/README.md)                         | Inventory of vendored libraries                    |
| [`docs/details/FRAMEWORKS.md`](../docs/details/FRAMEWORKS.md)     | Why each framework is vendored                     |
| [`docs/details/BOOTSTRAP.md`](../docs/details/BOOTSTRAP.md)       | First-run flow that calls into `submodule-sync.sh` |
| [`docs/details/DEPENDENCIES.md`](../docs/details/DEPENDENCIES.md) | Engineer reference for every system dependency     |

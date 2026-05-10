# 🛠 bin/

> General-purpose tooling that becomes available in any shell that loads `dot`. Scripts in this directory are prepended to `$PATH` at shell startup by the static-tier path module ([`modules/000-a-paths.sh`](../modules/000-a-paths.sh)). Drop a new executable here and it's on `$PATH` in the next shell.

---

## 📜 Scripts

### 🧱 Bootstrap & Deployment

> 🪧 The first-run installer and iCloud deploy helpers now live in [`scripts/`](../scripts/README.md):
> [`scripts/dot-bootstrap.sh`](../scripts/dot-bootstrap.sh),
> [`scripts/dot-deploy-config.sh`](../scripts/dot-deploy-config.sh),
> [`scripts/dot-deploy-rc.sh`](../scripts/dot-deploy-rc.sh).

| Script                                           | Lang | Description                                                               |
| ------------------------------------------------ | ---- | ------------------------------------------------------------------------- |
| [`brew-bootstrap.sh`](./brew-bootstrap.sh)       | Bash | Thin wrapper around Homebrew (`install`, `uninstall`, `upgrade`, `info`). |
| [`plugctl.sh`](./plugctl.sh)                     | Bash | Installs / updates oh-my-zsh themes and plugins.                          |
| [`python-create-env.sh`](./python-create-env.sh) | Bash | Creates a project Python venv via `uv`.                                   |

### 🌳 Git Tools

| Script                                     | Lang   | Description                                                                                                                                                                                                                         |
| ------------------------------------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`git-branch-zap.sh`](./git-branch-zap.sh) | Bash   | Deletes merged local branches.                                                                                                                                                                                                      |
| [`git-changelog.sh`](./git-changelog.sh)   | Bash   | Conventional-commit changelog for the `dot` repo.                                                                                                                                                                                   |
| [`git-import-org.py`](./git-import-org.py) | Python | List & clone all repos from a GitHub org (needs `GITHUB_TOKEN`).                                                                                                                                                                    |
| [`git-import-org.sh`](./git-import-org.sh) | Bash   | Shell wrapper for the Python importer.                                                                                                                                                                                              |
| [`git-loc.sh`](./git-loc.sh)               | Bash   | LOC stats for the current repo.                                                                                                                                                                                                     |
| [`git-secret.sh`](./git-secret.sh)         | Bash   | Rewrites git history to remove secrets via `git-filter-repo`. Flags: `-s <secret>` (repeatable), `-f <rules-file>`, `-r <replacement>` (default `***REMOVED***`), `-m` submodules, `-n` dry-run, `-v` verbose, `--push` force-push. |

### 🔐 Secrets

| Script                                       | Lang | Description                                                                                                                                                                                                                                         |
| -------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`secret-report.sh`](./secret-report.sh)     | Bash | Scans git history (all refs), commit messages, and the working tree for exposed secret values & keys. Severities: `HIGH` / `MEDIUM` / `LOW`. Flags: `-f <secrets.json>` (required), `-r <repo>`, `-m`, `-u`, `-n <count>`, `-o pretty\|json`, `-d`. |
| [`secret-scanner.sh`](./secret-scanner.sh)   | Bash | Standalone scanner for working-tree secrets.                                                                                                                                                                                                        |
| [`zsh-mask-secret.sh`](./zsh-mask-secret.sh) | ZSH  | Secret masking, detection, ZLE integration, and git pre-commit hook installer. Modes: `-m` mask text, `-c` check, `-Z` print sourceable ZLE hooks, `-G <path>` install pre-commit hook.                                                             |

### 🖥 macOS / VM / iCloud

| Script                                          | Lang   | Description                                                                                                                                                                                                                             |
| ----------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`ivm.py`](./ivm.py)                            | Python | `vmctl` — unified VM lifecycle. Backends: UTM (`utmctl`), QEMU, Podman Machine, Apple `Virtualization.framework` (native helper or `vz` CLI). `ivm.py <backends\|list\|start\|stop\|suspend\|resume\|status\|shell> [--backend <name>]` |
| [`ictl.py`](./ictl.py)                          | Python | iCloud / Notes / Music / MobileMeAccounts inspector and manager.                                                                                                                                                                        |
| [`isync.py`](./isync.py)                        | Python | Reads & displays iCloud account info from `MobileMeAccounts.plist`.                                                                                                                                                                     |
| [`applevm-helper`](./apple-vm-helper/README.md) | Swift  | Compiled Swift binary that talks directly to Apple's `Virtualization.framework`. Source under [`apple-vm-helper/`](./apple-vm-helper/). Preferred provider for `ivm.py`'s `apple` backend.                                              |
| [`applevm-helper`](./applevm-helper)            | Binary | Built artefact (committed for convenience).                                                                                                                                                                                             |

### 🎨 Misc

| Script                                               | Lang | Description                                                                                    |
| ---------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------- |
| [`tmux-code.sh`](./tmux-code.sh)                     | Bash | Open / attach to a tmux session named after `cwd`. Flags: `-s <name>`, `-d`, `-k`, `-l`, `-h`. |
| [`imgcat.sh`](./imgcat.sh)                           | Bash | Print images inline (iTerm2 / compatible).                                                     |
| [`blender-render.sh`](./blender-render.sh)           | Bash | Headless Blender render helper.                                                                |
| [`rust-project-format.sh`](./rust-project-format.sh) | Bash | Recursively `rustfmt` every `.rs` file.                                                        |
| [`turtle-run.sh`](./turtle-run.sh)                   | Bash | _(Deprecated — `turtle/` is being removed from this repo.)_                                    |

---

## 🍎 Apple VM Helper

[`applevm-helper`](./apple-vm-helper/README.md) is a compiled Swift binary that drives Apple's `Virtualization.framework` directly: start, stop, suspend, resume, status. It is the preferred provider for `ivm.py`'s `apple` backend. Build instructions live in [`apple-vm-helper/README.md`](./apple-vm-helper/README.md); the [`scripts/dot-bootstrap.sh`](../scripts/dot-bootstrap.sh) flow can build & link it for you.

---

## 📚 `lib/`

Internal helpers shared across `bin/` scripts. Not invoked directly.

| File                               | Description                             |
| ---------------------------------- | --------------------------------------- |
| [`lib/common.sh`](./lib/common.sh) | Shared shell helpers (logging, guards). |
| [`lib/main.sh`](./lib/main.sh)     | Common entry-point bootstrap snippet.   |

---

## ➕ Adding a Script

1. Drop your `.sh` / `.py` / executable in `bin/`.
2. `chmod +x` it.
3. Add a row to the relevant table above.
4. It's on `$PATH` after the next shell start (via `DOT_BIN`).

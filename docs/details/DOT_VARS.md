# DOT_* Environment Variables

All variables defined, exported, and consumed by the `dot` framework are prefixed `DOT_`. This document catalogs every variable — what it does, where it is set, where it is consumed, and whether it is actively used or orphaned (defined but never read).

---

## Quick-Reference Index

| Variable                                                          | Category       | Status                                    |
| ----------------------------------------------------------------- | -------------- | ----------------------------------------- |
| [`DOT_ROOT`](#dot_root)                                           | Path           | ✅ Active                                 |
| [`DOT_DIRECTORY`](#dot_directory)                                 | Path           | ✅ Active                                 |
| [`DOT_MODULES`](#dot_modules)                                     | Path           | ✅ Active                                 |
| [`DOT_MODULES_FILES`](#dot_modules_files)                         | Path           | ✅ Active                                 |
| [`DOT_BOOTSTRAP`](#dot_bootstrap)                                 | Path           | ⚠️ Set, rarely read                       |
| [`DOT_CONFIGURATION`](#dot_configuration)                         | Path           | ✅ Active                                 |
| [`DOT_DEBUG`](#dot_debug)                                         | Debug          | ✅ Active                                 |
| [`DOT_SHELL`](#dot_shell)                                         | State          | ⚠️ Shell identity tag                     |
| [`DOT_INTERACTIVE`](#dot_interactive)                             | State          | ✅ Active                                 |
| [`DOT_SECRETS_LOADED`](#dot_secrets_loaded)                       | State          | ✅ Active (internal)                      |
| [`DOT_DISABLE_BREW`](#4-feature-disable-flags)                    | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_EXTENSIONS`](#4-feature-disable-flags)              | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_THEFUCK`](#4-feature-disable-flags)                 | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_ZSH_AUTOSUGGESTIONS`](#4-feature-disable-flags)     | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING`](#4-feature-disable-flags) | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_Z`](#4-feature-disable-flags)                       | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_GIT`](#4-feature-disable-flags)                     | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_MAC`](#4-feature-disable-flags)                     | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_OUTPUTS`](#4-feature-disable-flags)                 | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_P10K`](#4-feature-disable-flags)                    | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_NODE`](#4-feature-disable-flags)                    | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_RUST`](#4-feature-disable-flags)                    | Feature Flag   | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_USER`](#5-git-default-variables)                | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_EMAIL`](#5-git-default-variables)               | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_SOURCE_BRANCH`](#5-git-default-variables)       | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_DESTINATION_BRANCH`](#5-git-default-variables)  | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_MERGE_BRANCH`](#5-git-default-variables)        | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_REBASE_BRANCH`](#5-git-default-variables)       | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_STASH_COMMITS`](#5-git-default-variables)       | Git            | ✅ Active                                 |
| [`DOT_CPU_TIME_LIMIT`](#6-resource-limit-variables)               | Resource Limit | ⚠️ Informational                          |
| [`DOT_FILE_SIZE_LIMIT`](#6-resource-limit-variables)              | Resource Limit | ⚠️ Informational                          |
| [`DOT_DATA_SIZE_LIMIT`](#6-resource-limit-variables)              | Resource Limit | ⚠️ Informational                          |
| [`DOT_STACK_SIZE_LIMIT`](#6-resource-limit-variables)             | Resource Limit | ⚠️ Informational                          |
| [`DOT_CORE_DUMP_LIMIT`](#6-resource-limit-variables)              | Resource Limit | ⚠️ Informational                          |
| [`DOT_VIRTUAL_MEMORY_LIMIT`](#6-resource-limit-variables)         | Resource Limit | ⚠️ Informational                          |
| [`DOT_LOCKED_MEMORY_LIMIT`](#6-resource-limit-variables)          | Resource Limit | ⚠️ Informational                          |
| [`DOT_OPEN_FILES_LIMIT`](#6-resource-limit-variables)             | Resource Limit | ⚠️ Duplicate of DOT_FILE_DESCRIPTOR_LIMIT |
| [`DOT_FILE_DESCRIPTOR_LIMIT`](#6-resource-limit-variables)        | Resource Limit | ⚠️ Informational                          |
| [`DOT_DEPS`](#dot_deps)                                           | External Input | ✅ Active (bootstrap only)                |
| [`DOT_NVM_INSTALL_LTS`](#dot_nvm_install_lts)                     | External Input | ✅ Active (bootstrap only)                |
| [`DOT_LIBS_DIR`](#dot_libs_dir)                                   | External Input | ✅ Active (when set)                      |
| [`DOT_PY_ENSURE_REQUIREMENTS`](#8-python-environment-variables)   | Python         | ✅ Active                                 |
| [`DOT_PY_FORCE_BASE`](#8-python-environment-variables)            | Python         | ✅ Active                                 |
| [`PYTHON_VERSION`](#8-python-environment-variables)               | Python         | ✅ Active (when set)                      |

**Status key:**

- ✅ Active — set and consumed by at least one module
- ⚠️ Partial — set but only used in limited/indirect ways
- ❌ Orphan — defined and exported but never consumed (candidate for removal)

---

## 1. Path Variables

These variables establish the filesystem layout of the framework and are used throughout all modules.

### `DOT_ROOT`

- **Default:** `$HOME/.dot`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** `dotenv.sh` to derive `DOT_DIRECTORY` and `DOT_MODULES`
- **Notes:** Synonymous with `DOT_DIRECTORY`. `unset` and re-exported on every shell start to avoid stale values from parent processes.

### `DOT_DIRECTORY`

- **Default:** `$DOT_ROOT`
- **Set in:** `modules/static/dotenv.sh`, `modules/static/limits.sh`
- **Used in:** `modules/000-a-output.sh` (quotes file path), `modules/static/dot.sh` (all `git -C` operations, sources `static/lib/internal.sh`, plugin/theme install), `modules/000-a-paths.sh` (`$DOT_DIRECTORY/bin` and `/scripts` PATH entries), `modules/static/lib/internal.sh` (zsh.yaml plugin list), `modules/static/lib/mac.sh` and `linux.sh` (debug messages)
- **Notes:** Canonical (and only) name for the repo root. `DOT_ROOT` is its upstream default.

### `DOT_MODULES`

- **Default:** `$DOT_ROOT/modules`
- **Set in:** `modules/static/dotenv.sh`, `modules/static/limits.sh`
- **Used in:** `modules/000-a-foundation.sh` (sources `static/lib/mac.sh`), `modules/static/dotbase.sh` (sources `limits.sh`, `autoload.sh`), `modules/static/foundation.sh` (sources `000-c-mac.sh`)
- **Notes:** Points to the modules directory.

### `DOT_MODULES_FILES`

- **Default:** sorted array of `$DOT_MODULES/*.sh` paths
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** `zshrc` — iterates this array to source every module at startup
- **Notes:** The core mechanism by which all numbered `modules/` files are loaded. Re-populated each shell start.

### `DOT_BOOTSTRAP`

- **Default:** `$DOT_DIRECTORY/scripts/dot-bootstrap.sh`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** Informational only — no module executes `$DOT_BOOTSTRAP` automatically
- **Notes:** ⚠️ Set but only passively exported. Its value is never actually invoked by any module. Useful as a convenience reference (`source $DOT_BOOTSTRAP`) but not strictly necessary.

### `DOT_CONFIGURATION`

- **Default:** `$ICLOUD/dot/data.json`
- **Set in:** `modules/static/config.sh`
- **Used in:** `modules/000-a-config.sh` — `dot::config::theme()` and `dot::config::condition()` query this file via `jq`
- **Notes:** Points to the **live** runtime config (in iCloud), not the repo source of truth at `data/zsh.yaml`. `scripts/dot-deploy-config.sh` copies the repo config to this location.

---

## 2. Debug Variables

### `DOT_DEBUG`

- **Default:** `0`
- **Set in:** `modules/static/dotenv.sh` (authoritative); also re-defaulted defensively in `000-a-foundation.sh`, `000-a-emulation.sh`, `000-a-output.sh`, `000-c-git.sh`, `000-a-secrets.sh`
- **Used in:** Every numbered `modules/` file, `bin/tmux-code.sh`, `modules/static/lib/{mac,linux,windows,plumbing}.sh`
- **Effect:** When set to `1`, each module prints `"loading: <file> (<dir>)"` to stdout at source time
- **To enable:** `export DOT_DEBUG=1` before starting a new shell (or `export DOT_DEBUG=1 && exec zsh`)

## 3. Runtime State Variables

These are set during shell startup to reflect the current state of the loaded environment.

### `DOT_SHELL`

- **Default:** `"zsh"`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** Exported as a shell identity tag; not currently read by any module.
- **Notes:** Harmless to keep as a shell identity tag.

### `DOT_INTERACTIVE`

- **Default:** `0` (set to `1` for human interactive shells)
- **Set in:** `zshrc` (0 for non-interactive/automation shells, 1 for interactive/VSCode); `modules/static/dotenv.sh` provides the default
- **Used in:** `zshrc` (splash-screen gating), `modules/001-a-tmux.sh` (auto-tmux), `modules/999-a-terminal.sh` (fzf / interactive setup); also set by the automation profile and `.vscode` settings
- **Notes:** ✅ Active — the interactive vs non-interactive session switch.

### `DOT_SECRETS_LOADED`

- **Default:** unset
- **Set in:** `modules/static/lib/plumbing.sh` → set to `1` after secrets are loaded
- **Used in:** `modules/static/lib/plumbing.sh` → checked to skip double-loading; unset after use
- **Notes:** ✅ Internal one-shot latch — functions correctly as a re-entrancy guard.

---

## 4. Feature Disable Flags

Set any of these to `1` to skip the corresponding module or feature. All default to `0` (enabled). Set in `modules/static/dotenv.sh`.

### Top-level module guards

| Variable                 | Checked in                    | Effect when `1`                                                                                                      |
| ------------------------ | ----------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `DOT_DISABLE_BREW`       | `modules/000-a-brewster.sh`   | Skips Homebrew helper function definitions                                                                           |
| `DOT_DISABLE_EXTENSIONS` | `modules/000-d-extensions.sh` | Skips all of: iTerm2 shell integration, thefuck, zsh-autosuggestions, zsh-syntax-highlighting, z                     |
| `DOT_DISABLE_GIT`        | `modules/000-c-git.sh`        | Skips git configuration and `dot::git::config` function                                                              |
| `DOT_DISABLE_MAC`        | `modules/000-c-mac.sh`        | Skips macOS-specific helpers (`dot::mac::cpu-cores`, `dot::mac::cpu-brand`)                                          |
| `DOT_DISABLE_OUTPUTS`    | `modules/000-a-output.sh`     | Skips terminal decoration functions (`dot::output::logo`, `dot::output::term-quote`, `dot::output::colors256`, etc.) |
| `DOT_DISABLE_P10K`       | `modules/001-a-p10k.sh`       | Skips Powerlevel10k prompt activation                                                                                |
| `DOT_DISABLE_NODE`       | `modules/001-d-node.sh`       | Skips Node.js environment setup (`N_PREFIX`, PATH)                                                                   |
| `DOT_DISABLE_RUST`       | `modules/001-d-rust.sh`       | Skips Rust environment setup (rustup PATH, `dot::rust` helpers)                                                      |

### Sub-flags within `000-d-extensions.sh`

These are checked **after** `DOT_DISABLE_EXTENSIONS` — if the parent flag is `1`, these are never reached.

| Variable                              | Effect when `1`                        |
| ------------------------------------- | -------------------------------------- |
| `DOT_DISABLE_THEFUCK`                 | Skips `thefuck` shell hook init        |
| `DOT_DISABLE_ZSH_AUTOSUGGESTIONS`     | Skips `zsh-autosuggestions` source     |
| `DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING` | Skips `zsh-syntax-highlighting` source |
| `DOT_DISABLE_Z`                       | Skips `z` (directory autojump) source  |

---

## 5. Git Default Variables

Set in `modules/000-c-git.sh`. Used by the `dot::git::config` function in the same file to configure git globally or locally.

| Variable                             | Default                     | Description                                  |
| ------------------------------------ | --------------------------- | -------------------------------------------- |
| `DOT_GIT_DEFAULT_USER`               | `"apsamuel"`                | `git config user.name`                       |
| `DOT_GIT_DEFAULT_EMAIL`              | `"aaron.psamuel@gmail.com"` | `git config user.email`                      |
| `DOT_GIT_DEFAULT_SOURCE_BRANCH`      | `"main"`                    | Default source branch for operations         |
| `DOT_GIT_DEFAULT_DESTINATION_BRANCH` | `"staging"`                 | Default destination/target branch            |
| `DOT_GIT_DEFAULT_MERGE_BRANCH`       | `1`                         | Use merge strategy (1 = yes)                 |
| `DOT_GIT_DEFAULT_REBASE_BRANCH`      | `0`                         | Use rebase strategy (0 = no)                 |
| `DOT_GIT_DEFAULT_STASH_COMMITS`      | `0`                         | Auto-stash before branch operations (0 = no) |

**Note:** `DOT_GIT_DEFAULT_EMAIL` has a bug in `modules/000-c-git.sh` — the `dot::git::config` function calls `git config user.DOT_GIT_DEFAULT_EMAIL` (literal string) instead of `git config user.email "$DOT_GIT_DEFAULT_EMAIL"`.

---

## 6. Resource Limit Variables

Set in `modules/static/limits.sh` by reading the current `ulimit` values at shell startup. These are **informational snapshots** — the framework does not call `ulimit` to change any limits.

| Variable                    | `ulimit` flag | Description                                                              |
| --------------------------- | ------------- | ------------------------------------------------------------------------ |
| `DOT_CPU_TIME_LIMIT`        | `-t`          | Max CPU time per process (seconds)                                       |
| `DOT_FILE_SIZE_LIMIT`       | `-f`          | Max file size (512-byte blocks)                                          |
| `DOT_DATA_SIZE_LIMIT`       | `-d`          | Max data segment size (KB)                                               |
| `DOT_STACK_SIZE_LIMIT`      | `-s`          | Max stack size (KB)                                                      |
| `DOT_CORE_DUMP_LIMIT`       | `-c`          | Max core dump size (512-byte blocks)                                     |
| `DOT_VIRTUAL_MEMORY_LIMIT`  | `-v`          | Max virtual memory (KB)                                                  |
| `DOT_LOCKED_MEMORY_LIMIT`   | `-l`          | Max locked-in-memory size (KB)                                           |
| `DOT_OPEN_FILES_LIMIT`      | `-n`          | Max open file descriptors — **duplicate** of `DOT_FILE_DESCRIPTOR_LIMIT` |
| `DOT_FILE_DESCRIPTOR_LIMIT` | `-n`          | Max open file descriptors — **duplicate** of `DOT_OPEN_FILES_LIMIT`      |

**Recommendation:** Remove `DOT_OPEN_FILES_LIMIT`; keep `DOT_FILE_DESCRIPTOR_LIMIT` as the canonical name.

---

## 7. External Input Variables

These are **not** set by any `modules/` file. They are meant to be set by the caller (in the environment or a wrapper script) before invoking bootstrap or starting a shell.

### `DOT_DEPS`

- **Consumed in:** `scripts/dot-bootstrap.sh`
- **Effect:** If set to `1`, forces re-installation of all bootstrap dependencies (brew packages, etc.)
- **Example:** `DOT_DEPS=1 source scripts/dot-bootstrap.sh`

### `DOT_NVM_INSTALL_LTS`

- **Consumed in:** `scripts/dot-bootstrap.sh`
- **Effect:** If set to `1`, installs the LTS version of Node.js via nvm during bootstrap
- **Example:** `DOT_NVM_INSTALL_LTS=1 source scripts/dot-bootstrap.sh`

### `DOT_LIBS_DIR`

- **Consumed in:** [`modules/static/dot.sh`](../../modules/static/dot.sh) — the `dot::static::shell` command sources all `*.sh` files found under this path
- **Effect:** Allows injecting additional shell libraries into the `dot` environment without modifying the repo
- **Example:** `export DOT_LIBS_DIR="$HOME/.local/dot-extras"` in a machine-local rc snippet

---

## 8. Python Environment Variables

Read by [`modules/001-d-python.sh`](../../modules/001-d-python.sh), which manages `uv`-created venvs under `~/.venv`.

| Variable                     | Default | Description                                                                                                                                                                                                                                                             |
| ---------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DOT_PY_ENSURE_REQUIREMENTS` | `1`     | When `1`, reconcile `.languages.python.pip.requirements` from `data/zsh.yaml` into provisioned venvs. On startup (interactive shells) every venv under `~/.venv` is reconciled (stamp-gated); new venvs created by `dot::python::env` get them too. Set `0` to disable. |
| `DOT_PY_FORCE_BASE`          | `0`     | When `1`, re-activate the base venv on startup even if another venv (venv/direnv) is already active.                                                                                                                                                                    |
| `PYTHON_VERSION`             | _unset_ | Overrides the python version otherwise resolved from `.languages.python.version` in `data/zsh.yaml` (fallback `3.11`).                                                                                                                                                  |

**Requirement reconciliation** installs a configured package only when it is entirely missing (existing versions are never modified). A per-venv stamp `<venv>/.dot-requirements.sha` records the last reconciled requirement set so steady-state shell startup stays cheap. Use `dot::python::sync [--force] [<venv>...]` to reconcile on demand.

---

## Summary: Cleanup Recommendations

| Action                                        | Variables                                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Remove duplicate** (same `ulimit -n` value) | `DOT_OPEN_FILES_LIMIT` (keep `DOT_FILE_DESCRIPTOR_LIMIT`)                                                          |
| **Fix bug**                                   | `000-c-git.sh` `dot::git::config` calls `git config user.DOT_GIT_DEFAULT_EMAIL` instead of `git config user.email` |
| **Keep as-is**                                | All actively used path, debug, feature flag, and git default variables                                             |

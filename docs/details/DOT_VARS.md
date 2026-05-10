# DOT_* Environment Variables

All variables defined, exported, and consumed by the `dot` framework are prefixed `DOT_`. This document catalogs every variable — what it does, where it is set, where it is consumed, and whether it is actively used or orphaned (defined but never read).

---

## Quick-Reference Index

| Variable                                                                      | Category       | Status                                   |
| ----------------------------------------------------------------------------- | -------------- | ---------------------------------------- |
| [`DOT_ROOT`](#dot_root)                                                       | Path           | ✅ Active                                 |
| [`DOT_DIRECTORY`](#dot_directory)                                             | Path           | ✅ Active                                 |
| [`DOT_DIR`](#dot_dir)                                                         | Path           | ✅ Active (alias)                         |
| [`DOT_MODULES`](#dot_modules)                                                 | Path           | ✅ Active                                 |
| [`DOT_MODULES_FILES`](#dot_modules_files)                                     | Path           | ✅ Active                                 |
| [`DOT_BOOTSTRAP`](#dot_bootstrap)                                             | Path           | ⚠️ Set, rarely read                       |
| [`DOT_CONFIGURATION`](#dot_configuration)                                     | Path           | ✅ Active                                 |
| [`DOT_DEBUG`](#dot_debug)                                                     | Debug          | ✅ Active                                 |
| [`DOT_DEBUG_RC`](#dot_debug_rc)                                               | Debug          | ❌ Orphan                                 |
| [`DOT_SHELL`](#dot_shell)                                                     | State          | ⚠️ Set, used only for DOT_DEBUG_RC        |
| [`DOT_INTERACTIVE`](#dot_interactive)                                         | State          | ❌ Orphan                                 |
| [`DOT_BOOT`](#dot_boot)                                                       | State          | ❌ Orphan (never assigned)                |
| [`DOT_BOOTED`](#dot_booted)                                                   | State          | ❌ Orphan                                 |
| [`DOT_ENABLED`](#dot_enabled)                                                 | State          | ❌ Orphan                                 |
| [`DOT_SECRETS_LOADED`](#dot_secrets_loaded)                                   | State          | ✅ Active (internal)                      |
| [`DOT_DIRECTORY_NAME`](#dot_directory_name)                                   | State          | ❌ Dead code                              |
| [`DOT_DISABLE_BREW`](#dot_disable_brew)                                       | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_EXTENSIONS`](#dot_disable_extensions)                           | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_THEFUCK`](#dot_disable_thefuck)                                 | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_ZSH_AUTOSUGGESTIONS`](#dot_disable_zsh_autosuggestions)         | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING`](#dot_disable_zsh_syntax_highlighting) | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_Z`](#dot_disable_z)                                             | Feature Flag   | ✅ Active (sub-flag)                      |
| [`DOT_DISABLE_GIT`](#dot_disable_git)                                         | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_MAC`](#dot_disable_mac)                                         | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_OUTPUTS`](#dot_disable_outputs)                                 | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_P10K`](#dot_disable_p10k)                                       | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_NODE`](#dot_disable_node)                                       | Feature Flag   | ✅ Active                                 |
| [`DOT_DISABLE_ANACONDA`](#dot_disable_anaconda)                               | Feature Flag   | ❌ Orphan                                 |
| [`DOT_DISABLE_NETWORK`](#dot_disable_network)                                 | Feature Flag   | ❌ Orphan                                 |
| [`DOT_GIT_DEFAULT_USER`](#dot_git_default_user)                               | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_EMAIL`](#dot_git_default_email)                             | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_SOURCE_BRANCH`](#dot_git_default_source_branch)             | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_DESTINATION_BRANCH`](#dot_git_default_destination_branch)   | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_MERGE_BRANCH`](#dot_git_default_merge_branch)               | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_REBASE_BRANCH`](#dot_git_default_rebase_branch)             | Git            | ✅ Active                                 |
| [`DOT_GIT_DEFAULT_STASH_COMMITS`](#dot_git_default_stash_commits)             | Git            | ✅ Active                                 |
| [`DOT_CPU_TIME_LIMIT`](#dot_cpu_time_limit)                                   | Resource Limit | ⚠️ Informational                          |
| [`DOT_FILE_SIZE_LIMIT`](#dot_file_size_limit)                                 | Resource Limit | ⚠️ Informational                          |
| [`DOT_DATA_SIZE_LIMIT`](#dot_data_size_limit)                                 | Resource Limit | ⚠️ Informational                          |
| [`DOT_STACK_SIZE_LIMIT`](#dot_stack_size_limit)                               | Resource Limit | ⚠️ Informational                          |
| [`DOT_CORE_DUMP_LIMIT`](#dot_core_dump_limit)                                 | Resource Limit | ⚠️ Informational                          |
| [`DOT_VIRTUAL_MEMORY_LIMIT`](#dot_virtual_memory_limit)                       | Resource Limit | ⚠️ Informational                          |
| [`DOT_LOCKED_MEMORY_LIMIT`](#dot_locked_memory_limit)                         | Resource Limit | ⚠️ Informational                          |
| [`DOT_OPEN_FILES_LIMIT`](#dot_open_files_limit)                               | Resource Limit | ⚠️ Duplicate of DOT_FILE_DESCRIPTOR_LIMIT |
| [`DOT_FILE_DESCRIPTOR_LIMIT`](#dot_file_descriptor_limit)                     | Resource Limit | ⚠️ Informational                          |
| [`DOT_ANACONDA_ENABLED`](#dot_anaconda_enabled)                               | Anaconda       | ❌ Orphan                                 |
| [`DOT_ANACONDA_DIR`](#dot_anaconda_dir)                                       | Anaconda       | ❌ Orphan                                 |
| [`DOT_ANACONDA_ENV`](#dot_anaconda_env)                                       | Anaconda       | ❌ Orphan                                 |
| [`DOT_DEPS`](#dot_deps)                                                       | External Input | ✅ Active (bootstrap only)                |
| [`DOT_NVM_INSTALL_LTS`](#dot_nvm_install_lts)                                 | External Input | ✅ Active (bootstrap only)                |
| [`DOT_LIBS_DIR`](#dot_libs_dir)                                               | External Input | ✅ Active (when set)                      |

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
- **Used in:** `dotenv.sh` to derive `DOT_DIRECTORY`, `DOT_MODULES`, and `DOT_DEBUG_RC`
- **Notes:** Synonymous with `DOT_DIRECTORY`. `unset` and re-exported on every shell start to avoid stale values from parent processes.

### `DOT_DIRECTORY`
- **Default:** `$DOT_ROOT`
- **Set in:** `modules/static/dotenv.sh`, `modules/static/limits.sh`
- **Used in:** `modules/000-a-output.sh` (quotes file path), `modules/static/lib/internal.sh` (zsh.yaml plugin list), `modules/static/lib/mac.sh` and `linux.sh` (debug messages), `modules/000-b-dot.sh` (initializes `DOT_DIR`)
- **Notes:** Canonical name for the repo root. Prefer this over `DOT_DIR` in new code.

### `DOT_DIR`
- **Default:** `$DOT_DIRECTORY` (set in `000-b-dot.sh`)
- **Set in:** `modules/000-b-dot.sh` (`DOT_DIR="${DOT_DIRECTORY}"`)
- **Used in:** `modules/000-b-dot.sh` (all `git -C` operations, plugin/theme install), `modules/000-aa-paths.sh` (`$DOT_DIR/bin` PATH entry), `modules/000-b-dot.sh` sources `$DOT_DIR/modules/static/lib/internal.sh`
- **Notes:** Redundant alias for `DOT_DIRECTORY` introduced in `000-b-dot.sh`. Candidate for consolidation — replace all `DOT_DIR` references with `DOT_DIRECTORY`.

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
- **Default:** `$DOT_DIRECTORY/bin/dot-bootstrap.sh`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** Informational only — no module executes `$DOT_BOOTSTRAP` automatically
- **Notes:** ⚠️ Set but only passively exported. Its value is never actually invoked by any module. Useful as a convenience reference (`source $DOT_BOOTSTRAP`) but not strictly necessary.

### `DOT_CONFIGURATION`
- **Default:** `$ICLOUD/dot/data.json`
- **Set in:** `modules/static/config.sh`
- **Used in:** `modules/000-a-config.sh` — `getTheme()` and `getCondition()` query this file via `jq`
- **Notes:** Points to the **live** runtime config (in iCloud), not the repo template at `config/data.json`. `bin/dot-deploy-config.sh` copies the repo template to this location.

---

## 2. Debug Variables

### `DOT_DEBUG`
- **Default:** `0`
- **Set in:** `modules/static/dotenv.sh` (authoritative); also re-defaulted defensively in `000-a-foundation.sh`, `000-a-emulation.sh`, `000-a-output.sh`, `000-c-git.sh`, `000-a-secrets.sh`
- **Used in:** Every numbered `modules/` file, `bin/tmux-code.sh`, `modules/static/lib/{mac,linux,windows,plumbing}.sh`
- **Effect:** When set to `1`, each module prints `"loading: <file> (<dir>)"` to stdout at source time
- **To enable:** `export DOT_DEBUG=1` before starting a new shell (or `export DOT_DEBUG=1 && exec zsh`)

### `DOT_DEBUG_RC`
- **Default:** `$DOT_ROOT/.$DOT_SHELL rc` → e.g. `~/.dot/.zshrc`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** ❌ **Nowhere** — never read by any module or script
- **Recommendation:** Remove. The variable suggests an intent to have a debug-mode rc file that was never implemented.

---

## 3. Runtime State Variables

These are set during shell startup to reflect the current state of the loaded environment.

### `DOT_SHELL`
- **Default:** `"zsh"`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** Only to construct `DOT_DEBUG_RC` (`${DOT_ROOT}/.${DOT_SHELL}rc`) — and since `DOT_DEBUG_RC` itself is never read, `DOT_SHELL` has no effective consumer
- **Notes:** ⚠️ Would be useful if `DOT_DEBUG_RC` were implemented. Harmless to keep as a shell identity tag.

### `DOT_INTERACTIVE`
- **Default:** `0`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** ❌ **Nowhere** — defined and exported but never checked
- **Recommendation:** Remove, or implement a check (e.g. `[[ $- == *i* ]]` → set to 1) and guard interactive-only modules with it.

### `DOT_BOOT`
- **Default:** (none — never assigned a value)
- **Set in:** Appears in the `export` statement in `modules/static/dotenv.sh` line 57 but is never assigned
- **Used in:** ❌ **Nowhere**
- **Recommendation:** Remove from the export list. It is always empty/unset.

### `DOT_BOOTED`
- **Default:** `false`
- **Set in:** `modules/static/dotenv.sh`
- **Used in:** ❌ **Nowhere** — set to `false` but never checked or updated to `true` by any module
- **Recommendation:** Remove, or implement: set to `true` at the end of `zshrc` load sequence so callers can detect a fully-initialized shell.

### `DOT_ENABLED`
- **Default:** `true` (set at end of `000-b-dot.sh`; conditionally `false` if iCloud is unavailable)
- **Set in:** `modules/000-b-dot.sh`
- **Used in:** ❌ **Nowhere outside `000-b-dot.sh`** — exported but never checked by any other module
- **Recommendation:** Remove or honour: modules that depend on iCloud-backed config could guard themselves with `[[ "${DOT_ENABLED}" == "true" ]]`.

### `DOT_SECRETS_LOADED`
- **Default:** unset
- **Set in:** `modules/static/lib/plumbing.sh` → set to `1` after secrets are loaded
- **Used in:** `modules/static/lib/plumbing.sh` → checked to skip double-loading; unset after use
- **Notes:** ✅ Internal one-shot latch — functions correctly as a re-entrancy guard.

### `DOT_DIRECTORY_NAME`
- **Default:** (derived from `dirname "${DOT_DIRECTORY_NAME}"` — self-reference without initialisation)
- **Set in:** `modules/000-b-dot.sh` line 11
- **Used in:** ❌ Only in its own assignment (`DOT_DIRECTORY_NAME="$(dirname "${DOT_DIRECTORY_NAME}")"` with no prior value)
- **Recommendation:** Remove. This is a no-op that produces an empty string.

---

## 4. Feature Disable Flags

Set any of these to `1` to skip the corresponding module or feature. All default to `0` (enabled). Set in `modules/static/dotenv.sh`.

### Top-level module guards

| Variable                 | Checked in                    | Effect when `1`                                                                                  |
| ------------------------ | ----------------------------- | ------------------------------------------------------------------------------------------------ |
| `DOT_DISABLE_BREW`       | `modules/000-a-brewster.sh`   | Skips Homebrew helper function definitions                                                       |
| `DOT_DISABLE_EXTENSIONS` | `modules/000-d-extensions.sh` | Skips all of: iTerm2 shell integration, thefuck, zsh-autosuggestions, zsh-syntax-highlighting, z |
| `DOT_DISABLE_GIT`        | `modules/000-c-git.sh`        | Skips git configuration and `gitConfig` function                                                 |
| `DOT_DISABLE_MAC`        | `modules/000-c-mac.sh`        | Skips macOS-specific helpers (`osCpuCores`, `osCpuBrand`)                                        |
| `DOT_DISABLE_OUTPUTS`    | `modules/000-a-output.sh`     | Skips terminal decoration functions (`termLogo`, `termQuote`, `showcolors256`, etc.)             |
| `DOT_DISABLE_P10K`       | `modules/001-a-p10k.sh`       | Skips Powerlevel10k prompt activation                                                            |
| `DOT_DISABLE_NODE`       | `modules/001-d-node.sh`       | Skips Node.js environment setup (`N_PREFIX`, PATH)                                               |

### Sub-flags within `000-d-extensions.sh`

These are checked **after** `DOT_DISABLE_EXTENSIONS` — if the parent flag is `1`, these are never reached.

| Variable                              | Effect when `1`                        |
| ------------------------------------- | -------------------------------------- |
| `DOT_DISABLE_THEFUCK`                 | Skips `thefuck` shell hook init        |
| `DOT_DISABLE_ZSH_AUTOSUGGESTIONS`     | Skips `zsh-autosuggestions` source     |
| `DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING` | Skips `zsh-syntax-highlighting` source |
| `DOT_DISABLE_Z`                       | Skips `z` (directory autojump) source  |

### Orphaned flags (defined but never checked)

| Variable               | Notes                                |
| ---------------------- | ------------------------------------ |
| `DOT_DISABLE_ANACONDA` | No anaconda module exists to read it |
| `DOT_DISABLE_NETWORK`  | No network module exists to read it  |

---

## 5. Git Default Variables

Set in `modules/000-c-git.sh`. Used by the `gitConfig` function in the same file to configure git globally or locally.

| Variable                             | Default                     | Description                                  |
| ------------------------------------ | --------------------------- | -------------------------------------------- |
| `DOT_GIT_DEFAULT_USER`               | `"apsamuel"`                | `git config user.name`                       |
| `DOT_GIT_DEFAULT_EMAIL`              | `"aaron.psamuel@gmail.com"` | `git config user.email`                      |
| `DOT_GIT_DEFAULT_SOURCE_BRANCH`      | `"main"`                    | Default source branch for operations         |
| `DOT_GIT_DEFAULT_DESTINATION_BRANCH` | `"staging"`                 | Default destination/target branch            |
| `DOT_GIT_DEFAULT_MERGE_BRANCH`       | `1`                         | Use merge strategy (1 = yes)                 |
| `DOT_GIT_DEFAULT_REBASE_BRANCH`      | `0`                         | Use rebase strategy (0 = no)                 |
| `DOT_GIT_DEFAULT_STASH_COMMITS`      | `0`                         | Auto-stash before branch operations (0 = no) |

**Note:** `DOT_GIT_DEFAULT_EMAIL` has a bug in `modules/000-c-git.sh` — the `gitConfig` function calls `git config user.DOT_GIT_DEFAULT_EMAIL` (literal string) instead of `git config user.email "$DOT_GIT_DEFAULT_EMAIL"`.

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

## 7. Anaconda Variables

Defined in `modules/static/dotenv.sh`. No module currently reads any of these — there is no anaconda module in `modules/`. All three are candidates for removal unless an anaconda module is planned.

| Variable               | Default                                                         | Notes                                     |
| ---------------------- | --------------------------------------------------------------- | ----------------------------------------- |
| `DOT_ANACONDA_ENABLED` | `0`                                                             | Flag to enable anaconda — never checked   |
| `DOT_ANACONDA_DIR`     | `/opt/homebrew/anaconda3` (arm) or `/usr/local/anaconda3` (x86) | Path to anaconda install — never consumed |
| `DOT_ANACONDA_ENV`     | `"base"`                                                        | Active conda env name — never consumed    |

---

## 8. External Input Variables

These are **not** set by any `modules/` file. They are meant to be set by the caller (in the environment or a wrapper script) before invoking bootstrap or starting a shell.

### `DOT_DEPS`
- **Consumed in:** `bin/dot-bootstrap.sh`
- **Effect:** If set to `1`, forces re-installation of all bootstrap dependencies (brew packages, etc.)
- **Example:** `DOT_DEPS=1 source bin/dot-bootstrap.sh`

### `DOT_NVM_INSTALL_LTS`
- **Consumed in:** `bin/dot-bootstrap.sh`
- **Effect:** If set to `1`, installs the LTS version of Node.js via nvm during bootstrap
- **Example:** `DOT_NVM_INSTALL_LTS=1 source bin/dot-bootstrap.sh`

### `DOT_LIBS_DIR`
- **Consumed in:** [`modules/static/dot.sh`](../../modules/static/dot.sh) — the `dot.shell` command sources all `*.sh` files found under this path
- **Effect:** Allows injecting additional shell libraries into the `dot` environment without modifying the repo
- **Example:** `export DOT_LIBS_DIR="$HOME/.local/dot-extras"` in a machine-local rc snippet

---

## Summary: Cleanup Recommendations

| Action                                        | Variables                                                                                                                                                                                                       |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Remove** (never read, no planned use)       | `DOT_BOOT`, `DOT_DEBUG_RC`, `DOT_INTERACTIVE`, `DOT_BOOTED`, `DOT_ENABLED`, `DOT_DIRECTORY_NAME`, `DOT_DISABLE_ANACONDA`, `DOT_DISABLE_NETWORK`, `DOT_ANACONDA_ENABLED`, `DOT_ANACONDA_DIR`, `DOT_ANACONDA_ENV` |
| **Remove duplicate** (same `ulimit -n` value) | `DOT_OPEN_FILES_LIMIT` (keep `DOT_FILE_DESCRIPTOR_LIMIT`)                                                                                                                                                       |
| **Consolidate alias**                         | `DOT_DIR` → replace all references with `DOT_DIRECTORY`                                                                                                                                                         |
| **Fix bug**                                   | `000-c-git.sh` `gitConfig` calls `git config user.DOT_GIT_DEFAULT_EMAIL` instead of `git config user.email`                                                                                                     |
| **Implement or remove**                       | `DOT_BOOTED` — useful if set to `true` at end of zshrc; `DOT_INTERACTIVE` — useful if set from `[[ $- == *i* ]]`; `DOT_ENABLED` — useful if modules guard on iCloud availability                                |
| **Keep as-is**                                | All actively used path, debug, feature flag, and git default variables                                                                                                                                          |

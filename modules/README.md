# modules — The dot Module Library

`modules/` is the heart of the `dot` framework. It contains every ZSH module sourced when a new shell starts. Modules come in two flavours:

- 🪨 **Static modules** — files under [`modules/static/`](./static/). Foundational functions and variables that are **always** loaded (no opt-out), sourced explicitly by [`zshrc`](../zshrc) **before** anything else. They are the substrate consumed by every dynamic module and by the helper scripts in [`bin/`](../bin/README.md).
- 🌀 **Dynamic modules** — the numbered `NNN-x-name.sh` files at the top of `modules/`. Loaded in lex order by `loadModules`. Each one is a self-contained, narrowly-scoped snippet of functionality (a tool integration, a language environment, a set of aliases). Most can be turned off individually via a `DOT_DISABLE_*` env var.

---

## 🌀 Dynamic Module Loading Order

Dynamic module files are sourced in lexicographic order based on their filename prefix. Two levels of prefixing control load order:

```
NNN-x-name.sh
│   │ └─ Module name (descriptive)
│   └─── Sub-order letter (a–z within a tier)
└─────── Three-digit numeric tier (left-padded, e.g. 000, 001, 999)
```

**Example:** `000-a-base.sh` loads before `000-b-aliases.sh`, which loads before `001-d-python.sh`.

Lower numbers are foundational (variables, paths, helpers). Higher numbers are integrations (language runtimes, completions, work tools).

---

## Disabling Dynamic Modules

Most dynamic modules respect a `DOT_DISABLE_*` flag. Set the variable to `1` to skip that module at shell startup:

```bash
export DOT_DISABLE_NODE=1       # skip Node.js setup
export DOT_DISABLE_EXTENSIONS=1 # skip iTerm2, thefuck, autosuggestions
```

Static modules cannot be disabled — the rest of the framework depends on them.

---

## 🌀 Dynamic Module Reference

### Tier 000 — Foundation

| File                  | Description                                                                                                                                                       |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `000-a-base.sh`       | Sets base variables: CPU brand/cores/architecture, OS type, shell versions (bash, zsh, git)                                                                       |
| `000-a-config.sh`     | Loads and exports base configuration variables                                                                                                                    |
| `000-a-emulation.sh`  | Functions to emulate or spawn other shells: `emulateZsh`, `emulateBash`, `spawnArm`, `spawnIntel`, etc.                                                           |
| `000-a-foundation.sh` | Baseline environment wiring: terminal info, `getShellName`, `getSecureString`                                                                                     |
| `000-a-homebrew.sh`   | Homebrew helper functions: `brewInstall`, `brewUpdate`, `brewUpgrade`, `brewDump`, `brewLoad`, `brewJson`, etc.                                                   |
| `000-a-math.sh`       | Math utility: `bcSolve` — evaluate arbitrary expressions via `bc`                                                                                                 |
| `000-a-output.sh`     | Terminal output helpers: `printLevel`, `printPretty`, `termLogo`, `termImage`, `termQuote`, `randomQuote`, `toFiglet`, `showcolors256`                            |
| `000-a-paths.sh`      | PATH configuration and path manipulation helpers (prepends `bin/` so its scripts are available in every shell)                                                    |
| `000-a-plugins.sh`    | Defines environment variables required for oh-my-zsh plugin loading                                                                                               |
| `000-a-secrets.sh`    | Secrets management: `loadSecrets`, `maskSecrets`, `__mask_secrets__`, `reloadOptions`                                                                             |
| `000-a-tools.sh`      | General utilities: `splitString`, `joinList`, `GetPreview` (fzf file picker with `bat` preview), and string manipulation helpers                                  |
| `000-a-vendor.sh`     | Vendor integration — sources third-party libraries from `vendor/` (fzf-git, figlet-fonts, etc.)                                                                   |
| `000-b-aliases.sh`    | Shell aliases: `cat='bat'`, `ls='ls --color=always'`, `less='bat --paging=always'`                                                                                |
| `000-b-zstyle.sh`     | Zstyle configuration for zsh subsystems (compsys, oh-my-zsh, plugins). Provides `zstyleList`, `zstyleShow`, `zstyleDump` helpers. Guarded by `DOT_DISABLE_ZSTYLE` |
| `000-c-git.sh`        | Git configuration: `gitConfig`, default branch settings, default user/email                                                                                       |
| `000-c-mac.sh`        | macOS-specific helpers: `osCpuCores`, `osCpuBrand`; guarded by `DOT_DISABLE_MAC`                                                                                  |
| `000-d-extensions.sh` | Shell extensions: iTerm2 shell integration, `thefuck`, `zsh-autosuggestions`; guarded by `DOT_DISABLE_EXTENSIONS`                                                 |
| `000-d-notes.sh`      | Notes utilities (placeholder for future expansion)                                                                                                                |
| `000-d-podman.sh`     | Sets `PODMAN_COMPOSE_WARNING_LOGS=False`                                                                                                                          |

> `000-c-network.sh.deprecated` is retained on disk for reference only and is **not** sourced (the `.deprecated` suffix excludes it from `loadModules`).

### Tier 001 — Language & Environment

| File              | Description                                                                                                           |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| `001-a-ai.sh`     | Wires the LM Studio CLI onto `PATH` when `~/.lmstudio/bin` exists                                                     |
| `001-a-p10k.sh`   | Sources `~/.p10k.zsh` to activate the powerlevel10k prompt                                                            |
| `001-a-tmux.sh`   | Tmux helpers: `tmuxCreateSessionFromCwd`, `tmuxHasSession`, `tmuxGetSafeSessionName`, `tmuxKillUnattached`            |
| `001-d-node.sh`   | Node.js environment: detects architecture, sets `N_PREFIX`, adds Homebrew node to PATH; guarded by `DOT_DISABLE_NODE` |
| `001-d-python.sh` | Python environment: creates and activates an architecture-specific `uv` venv at `~/.venv/<version>-<arch>-base`       |
| `001-d-rust.sh`   | Rust environment: adds `rustup` Homebrew prefix to PATH                                                               |
| `001-z-java.sh`   | Java environment: initialises `jenv`, sets `JAVA_HOME`; guarded by `jenv` availability                                |

### Tier 002 — Domain-specific

| File           | Description                                                             |
| -------------- | ----------------------------------------------------------------------- |
| `002-a-sre.sh` | SRE tooling: Terraform completion setup (commented out by default)      |
| `002-b-bio.sh` | Bioinformatics: adds NCBI `edirect` tools to PATH if `~/edirect` exists |

### Tier 999 — Completions & Finalization

| File                       | Description                                                                      |
| -------------------------- | -------------------------------------------------------------------------------- |
| `999-a-completion.sh`      | Shell completion initialization; sets up Homebrew completion paths               |
| `999-a-terminal.sh`        | Terminal finalization: `compileTerminalInfo`, `configureFzf` for fzf keybindings |
| `999-audio-video-tools.sh` | Audio/video tool helpers (stub for future expansion)                             |
| `999-z-work.sh`            | Work-specific aliases and configuration (guarded, last to load)                  |

---

## 🪨 Static Modules — `static/`

Files in `modules/static/` are sourced directly by `zshrc` **before** the numbered dynamic modules. They provide foundational infrastructure the rest of the framework depends on (and which `bin/` scripts also import). They cannot be disabled.

| File                   | Description                                                                                                                                                       |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `static/autoload.sh`   | Autoloads ZSH built-in functions                                                                                                                                  |
| `static/cloud.sh`      | iCloud path setup — exports `ICLOUD` pointing to `~/Library/Mobile Documents/com~apple~CloudDocs`                                                                 |
| `static/config.sh`     | Sets `$DOT_CONFIGURATION` to `$ICLOUD/dot/data.json` (the live runtime config path)                                                                               |
| `static/dotbase.sh`    | Bootstrap entry point for static sources — chains `limits.sh` and `autoload.sh`                                                                                   |
| `static/dotenv.sh`     | Core `DOT_*` variable exports: `DOT_ROOT`, `DOT_DIRECTORY`, `DOT_MODULES`, `DOT_BIN`, `DOT_BOOTSTRAP`, `DOT_SHELL`, `DOT_DEBUG`, `DOT_BOOTED`, `DOT_ARCHITECTURE` |
| `static/foundation.sh` | Foundational shell functions loaded early: `getShellName`, `getSecureString`, `getProcessorCores`, `getProcessorBrand`, `loadZshOptions`                          |
| `static/limits.sh`     | Reads and exports current `ulimit` values as `DOT_*_LIMIT` variables                                                                                              |
| `static/set.sh`        | Shell option configuration (placeholder for `setopt`/`unsetopt` directives)                                                                                       |
| `static/ssh.sh`        | Discovers SSH private keys from `~/.ssh/` and exports them as the `SSH_KEYS` array                                                                                |

### `static/lib/` — Internal Bootstrap Helpers

Sourced exclusively by `dot-bootstrap.sh` and other low-level scripts. Not intended for direct use.

| File                      | Description                                                     |
| ------------------------- | --------------------------------------------------------------- |
| `static/lib/internal.sh`  | Core bootstrap utilities shared across `bin/` scripts           |
| `static/lib/universal.sh` | OS-agnostic helper functions                                    |
| `static/lib/mac.sh`       | macOS-specific helper functions                                 |
| `static/lib/linux.sh`     | Linux-specific helper functions                                 |
| `static/lib/windows.sh`   | Windows/WSL stub helpers                                        |
| `static/lib/plumbing.sh`  | Low-level plumbing utilities (process, path, string)            |
| `static/lib/std.sh`       | Standard library shims and compatibility helpers                |
| `static/dotenv.sh`        | `.env` file loading support                                     |
| `static/foundation.sh`    | Pre-module environment validation                               |
| `static/limits.sh`        | Sets shell resource limits                                      |
| `static/set.sh`           | ZSH `setopt` / `unsetopt` calls                                 |
| `static/ssh.sh`           | SSH agent initialization                                        |
| `static/lib/`             | Internal utility functions used by bootstrap and static helpers |

---

## Adding a New Dynamic Module

1. Create `modules/NNN-x-name.sh` (pick a tier that fits)
2. Start with the standard header:
   ```bash
   #shellcheck shell=bash
   # shellcheck source=/dev/null
   directory=$(dirname "$0")
   library=$(basename "$0")
   if [[ "${DOT_DEBUG}" -eq 1 ]]; then
       echo "loading: ${library} (${directory})"
   fi
   ```
3. Add your functions, aliases, or exports
4. If the module can be disabled, wrap it:
   ```bash
   if [[ "${DOT_DISABLE_MYMODULE}" -eq 1 ]]; then return; fi
   ```
5. Open a new shell to test — the module loads automatically

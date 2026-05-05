# zlib — ZSH Library

`zlib/` is the heart of the `dot` framework. It contains all ZSH modules that are sourced automatically when a new shell session starts. Each module is a plain `.sh` file.

---

## Loading Order

Files are sourced in lexicographic order based on their filename prefix. Two levels of prefixing control load order:

```
NNN-x-name.sh
│   │ └─ Module name (descriptive)
│   └─── Sub-order letter (a–z within a tier)
└─────── Three-digit numeric tier (left-padded, e.g. 000, 001, 999)
```

**Example:** `000-a-base.sh` loads before `000-b-aliases.sh`, which loads before `001-d-python.sh`.

Lower numbers are foundational (variables, paths, helpers). Higher numbers are integrations (language runtimes, completions, work tools).

---

## Disabling Modules

Most modules respect a `DOT_DISABLE_*` flag. Set the variable to `1` to skip that module at shell startup:

```bash
export DOT_DISABLE_NODE=1       # skip Node.js setup
export DOT_DISABLE_EXTENSIONS=1 # skip iTerm2, thefuck, autosuggestions
```

---

## Module Reference

### Tier 000 — Foundation

| File | Description |
|---|---|
| `000-a-base.sh` | Sets base variables: CPU brand/cores/architecture, OS type, shell versions (bash, zsh, git) |
| `000-a-brewster.sh` | Homebrew helper functions: `brewInstall`, `brewUpdate`, `brewUpgrade`, `brewDump`, `brewLoad`, `brewJson`, etc. |
| `000-a-config.sh` | Loads and exports base configuration variables |
| `000-a-emulation.sh` | Functions to emulate or spawn other shells: `emulateZsh`, `emulateBash`, `spawnArm`, `spawnIntel`, etc. |
| `000-a-foundation.sh` | Baseline environment wiring: terminal info, `getShellName`, `getSecureString` |
| `000-a-math.sh` | Math utility: `bcSolve` — evaluate arbitrary expressions via `bc` |
| `000-a-output.sh` | Terminal output helpers: `printLevel`, `printPretty`, `termLogo`, `termImage`, `termQuote`, `randomQuote`, `toFiglet`, `showcolors256` |
| `000-a-plugins.sh` | Defines environment variables required for oh-my-zsh plugin loading |
| `000-a-secrets.sh` | Secrets management: `loadSecrets`, `maskSecrets`, `__mask_secrets__`, `reloadOptions` |
| `000-a-tools.sh` | General utilities: `splitString`, `joinList`, and string manipulation helpers |
| `000-a-vendor.sh` | Vendor integration stub — reserved for sourcing third-party libraries from `vendor/`; currently empty |
| `000-aa-paths.sh` | PATH configuration and path manipulation helpers |
| `000-b-aliases.sh` | Shell aliases: `cat='bat'`, `ls='ls --color=always'`, `less='bat --paging=always'` |
| `000-b-dot.sh` | The `dot.shell` command; iCloud path exports; TMUX session detection |
| `000-c-git.sh` | Git configuration: `gitConfig`, default branch settings, default user/email |
| `000-c-mac.sh` | macOS-specific helpers: `osCpuCores`, `osCpuBrand`; guarded by `DOT_DISABLE_MAC` |
| `000-d-extensions.sh` | Shell extensions: iTerm2 shell integration, `thefuck`, `zsh-autosuggestions`; guarded by `DOT_DISABLE_EXTENSIONS` |
| `000-d-notes.sh` | Notes utilities (placeholder for future expansion) |
| `000-d-podman.sh` | Sets `PODMAN_COMPOSE_WARNING_LOGS=False` |
| `000-tools.sh` | Additional tool helpers: `GetPreview` — fzf file picker with `bat` syntax-highlighted preview |

### Tier 001 — Language & Environment

| File | Description |
|---|---|
| `001-a-p10k.sh` | Sources `~/.p10k.zsh` to activate the powerlevel10k prompt |
| `001-d-node.sh` | Node.js environment: detects architecture, sets `N_PREFIX`, adds Homebrew node to PATH; guarded by `DOT_DISABLE_NODE` |
| `001-d-python.sh` | Python environment: creates and activates an architecture-specific `uv` venv at `~/.venv/<version>-<arch>-base` |
| `001-d-rust.sh` | Rust environment: adds `rustup` Homebrew prefix to PATH |
| `001-tmux.sh` | Tmux helpers: `tmuxCreateSessionFromCwd`, `tmuxHasSession`, `tmuxGetSafeSessionName`, `tmuxKillUnattached` |
| `001-z-java.sh` | Java environment: initialises `jenv`, sets `JAVA_HOME`; guarded by `jenv` availability |

### Tier 002 — Domain-specific

| File | Description |
|---|---|
| `002-a-sre.sh` | SRE tooling: Terraform completion setup (commented out by default) |
| `002-b-bio.sh` | Bioinformatics: adds NCBI `edirect` tools to PATH if `~/edirect` exists |

### Tier 999 — Completions & Finalization

| File | Description |
|---|---|
| `999-a-completion.sh` | Shell completion initialization; sets up Homebrew completion paths |
| `999-a-terminal.sh` | Terminal finalization: `compileTerminalInfo`, `configureFzf` for fzf keybindings |
| `999-audio-video-tools.sh` | Audio/video tool helpers (stub for future expansion) |
| `999-z-work.sh` | Work-specific aliases and configuration (guarded, last to load) |

---

## `static/` — Static Helpers

Files in `zlib/static/` are sourced directly by `bootstrap.sh` and `zshrc` before the numbered modules, providing infrastructure the modules depend on.

| File | Description |
|---|---|
| `static/autoload.sh` | Autoloads ZSH built-in functions |
| `static/cloud.sh` | iCloud path setup |
| `static/config.sh` | Sets `$DOT_CONFIGURATION` to `$ICLOUD/dot/data.json` (the live runtime config path) |
| `static/dotbase.sh` | Foundational `DOT_*` variable exports |
| `static/dotenv.sh` | `.env` file loading support |
| `static/foundation.sh` | Pre-module environment validation |
| `static/limits.sh` | Sets shell resource limits |
| `static/set.sh` | ZSH `setopt` / `unsetopt` calls |
| `static/ssh.sh` | SSH agent initialization |
| `static/lib/` | Internal utility functions used by bootstrap and static helpers |

---

## Adding a New Module

1. Create `zlib/NNN-x-name.sh` (pick a tier that fits)
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

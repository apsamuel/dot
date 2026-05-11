# modules/

The `modules/` directory is the runtime shell framework for `dot`.

- `modules/static/` contains foundational files sourced explicitly by `zshrc`.
- `modules/NNN-*.sh` contains dynamic modules sourced by `loadModules` in lexical order.

## Startup Sequence

`zshrc` currently sources the static layer in this exact order:

1. `modules/static/dotenv.sh`
2. `scripts/dot-bootstrap.sh` (when present)
3. `modules/static/foundation.sh`
4. `modules/static/ssh.sh`
5. `modules/static/limits.sh`
6. `modules/static/autoload.sh`
7. `modules/static/dot.sh`
8. `loadZshOptions` (reads options from `data/zsh.yaml`)
9. `loadModules` (all dynamic modules below)
10. `compileTermInfo`

## Dynamic Modules (Load Order)

Dynamic modules are discovered using:

`find modules -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*-*.sh' | sort -d`

### Tier 000 (foundation)

| File | Purpose |
| --- | --- |
| `000-a-base.sh` | Base host/runtime defaults and baseline env values. |
| `000-a-config.sh` | Config accessors based on `DOT_SHELL_DATA` (`data/zsh.yaml` preferred). |
| `000-a-emulation.sh` | Architecture/shell emulation helpers. |
| `000-a-foundation.sh` | Foundation glue and helpers consumed by later modules. |
| `000-a-homebrew.sh` | Homebrew discovery/helpers and brew-centric utility functions. |
| `000-a-math.sh` | Shell math helper wrappers. |
| `000-a-output.sh` | Splash/quote/output formatting helpers. |
| `000-a-paths.sh` | PATH composition (`edirect`, `bin`, `scripts`, `~/bin`) and path helper funcs. |
| `000-a-plugins.sh` | Plugin/env wiring helpers used by plugin ecosystem setup. |
| `000-a-secrets.sh` | Secret loading/masking helpers. |
| `000-a-tools.sh` | Generic list/string/path utility functions. |
| `000-a-vendor.sh` | Vendor framework integrations (e.g., vendored shell helpers). |
| `000-b-aliases.sh` | General shell aliases. |
| `000-b-zstyle.sh` | zstyle defaults and completion tuning. |
| `000-c-git.sh` | Git defaults and git utility helpers. |
| `000-c-mac.sh` | macOS-specific helper functions. |
| `000-d-extensions.sh` | Optional extension hooks (guarded by disable flags). |
| `000-d-notes.sh` | Notes-related helper hooks. |
| `000-d-podman.sh` | Podman-related env tuning. |

### Tier 001 (language/runtime)

| File | Purpose |
| --- | --- |
| `001-a-ai.sh` | AI tooling integration hooks. |
| `001-a-p10k.sh` | Powerlevel10k prompt configuration loading. |
| `001-a-tmux.sh` | Tmux session helpers and defaults. |
| `001-d-node.sh` | Node runtime/tooling setup (`n`/`npm`) and env exports. |
| `001-d-python.sh` | Python runtime/tooling setup (`uv`) and env exports. |
| `001-d-rust.sh` | Rust toolchain env setup. |
| `001-z-java.sh` | Java/JDK env setup (`jenv`-aware). |

### Tier 002 (domain-specific)

| File | Purpose |
| --- | --- |
| `002-a-sre.sh` | SRE/IaC helper exports. |
| `002-b-bio.sh` | Bioinformatics helper exports. |

### Tier 999 (finalization)

| File | Purpose |
| --- | --- |
| `999-a-completion.sh` | Completion finalization hooks. |
| `999-a-terminal.sh` | Terminal capability/fzf terminal integration finalization. |
| `999-audio-video-tools.sh` | Audio/video tooling helper exports. |
| `999-z-work.sh` | Late-loading work profile hooks. |

## Static Modules

| File | Purpose |
| --- | --- |
| `static/dotenv.sh` | Canonical `DOT_*` path/runtime/feature-flag exports. |
| `static/foundation.sh` | Foundational functions (`loadZshOptions`, `loadModules`, ssh key helpers). |
| `static/ssh.sh` | SSH environment and key helper setup. |
| `static/limits.sh` | Shell limit discovery/exports. |
| `static/autoload.sh` | ZSH autoload wiring. |
| `static/dot.sh` | `dot.shell` command and related helpers. |
| `static/lib/*.sh` | Internal bootstrap/platform helper library. |

## Naming Convention

- `NNN`: major phase (load tier)
- `a-z`: sub-order within the phase
- remainder: feature domain

Example: `001-d-python.sh` loads after `001-a-tmux.sh` and before `001-d-rust.sh`.

## Disable Flags

Most dynamic modules support one or more `DOT_DISABLE_*` flags exported by `modules/static/dotenv.sh`. Use these to skip optional integrations without editing module files.

See `docs/details/DOT_VARS.md` for the full variable index.

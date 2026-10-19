# modules/

The `modules/` directory is the runtime shell framework for `dot`.

- `modules/static/` contains foundational files sourced explicitly by `zshrc`.
- `modules/NNN-*.sh` contains dynamic modules sourced by `dot::static::foundation::load-modules` in lexical order.

## Command Discovery

Enabled command families expose ordinary Bash/ZSH functions. No additional CLI runtime or parser framework is needed. Existing feature backends (such as `bc`, `jq`, `uv`, or `rustup`) are required only for the operations that use them.

```bash
dot::output help
dot::output help pretty
dot::output pretty --help
dot::output::pretty --help
dot::output pretty --level error -- "Build failed"
dot::static::ssh help create-key
dot::static::shell help update
```

New family dispatchers default to help. `dot::static::shell` retains its existing no-argument version output. Help runs before operational dependency checks, does not read credentials or mutate state, and does not require a terminal. Explicit disable flags still suppress their modules.

### Family Coverage

Each family below supports `help`, `help <command>`, and command-level help. The source-local help is authoritative for arguments, prerequisites, effects, and return codes; existing direct functions remain available.

| Family                    | Operations                                            | Implementation                               |
| ------------------------- | ----------------------------------------------------- | -------------------------------------------- |
| `dot::output`             | Formatting, images, quotes, terminal dimensions       | [000-a-output.sh](000-a-output.sh)           |
| `dot::math`               | Arithmetic, expressions, numerical calculus           | [000-a-math.sh](000-a-math.sh)               |
| `dot::paths`              | PATH queries and updates                              | [000-a-paths.sh](000-a-paths.sh)             |
| `dot::config`             | Configuration queries                                 | [000-a-config.sh](000-a-config.sh)           |
| `dot::tools`              | Interactive file preview                              | [000-a-tools.sh](000-a-tools.sh)             |
| `dot::zstyle`             | ZSH style inspection and dumps                        | [000-b-zsh.sh](000-b-zsh.sh)                 |
| `dot::mac`                | macOS host queries                                    | [000-c-mac.sh](000-c-mac.sh)                 |
| `dot::foundation`         | Terminfo compilation, shell name, generated strings   | [000-a-foundation.sh](000-a-foundation.sh)   |
| `dot::brew`               | Package queries and management                        | [000-a-brew.sh](000-a-brew.sh)               |
| `dot::emulation`          | Shell and architecture selection                      | [000-a-emulation.sh](000-a-emulation.sh)     |
| `dot::git`                | Authentication, configuration, diffs and previews     | [000-c-git.sh](000-c-git.sh)                 |
| `dot::tmux`               | Session queries, creation and cleanup                 | [001-a-tmux.sh](001-a-tmux.sh)               |
| `dot::python`             | Requirements, reconciliation and virtual environments | [001-d-python.sh](001-d-python.sh)           |
| `dot::node`               | Node archive retrieval                                | [001-d-node.sh](001-d-node.sh)               |
| `dot::rust`               | Rustup toolchains, targets and components             | [001-d-rust.sh](001-d-rust.sh)               |
| `dot::secrets`            | Literal loading, masking and option reload            | [000-a-secrets.sh](000-a-secrets.sh)         |
| `dot::terminal`           | Terminfo compilation and interactive fzf setup        | [999-a-terminal.sh](999-a-terminal.sh)       |
| `dot::static::shell`      | Root maintenance and configuration                    | [static/dot.sh](static/dot.sh)               |
| `dot::static::ssh`        | SSH key queries and management                        | [static/ssh.sh](static/ssh.sh)               |
| `dot::static::foundation` | Host helpers, user-secret loading, SSH identities     | [static/foundation.sh](static/foundation.sh) |
| `dot::history`            | History configuration and archive rotation            | [static/foundation.sh](static/foundation.sh) |

### Compatibility Boundaries

- Literal helpers keep their data semantics: direct `dot::secrets::mask`, `dot::brew::parse-line`, and `dot::tmux::safe-session-name` do not reinterpret data as help flags. Use family topic help; `dot::secrets mask -- --help` masks the literal string `--help`.
- Predicates retain their existing true/false statuses, including PATH membership, tmux session existence, and unset zstyle queries. A nonzero predicate result does not necessarily indicate an operational failure.
- Platform-specific CPU leaves are selected at startup. Use `dot::static::foundation help cpu-cores` or `help cpu-brand` rather than passing flags directly to platform leaves.
- Private helpers, logging primitives, lifecycle loaders, and initialization-only modules are not command-line interfaces. Their arguments, source order, and interactive guards remain internal contracts.
- Backend-forwarding commands retain delegated flags. Use `--` where a command's help documents a literal/backend boundary; there is no universal parser or automatic retry policy.
- Dynamic secret loading preserves export attributes and accepts string values. Static user-secret loading exports values and records key names. Both reject invalid identifiers and their documented reserved loader names. Neither operation provides transactional rollback if a shell variable rejects assignment.

Operational failures return nonzero; optional presentation tools may fall back to plain output. Package changes, authentication, key operations, and shell reloads are not automatically retried. See [contributor interface rules](../CONTRIBUTING.md#public-command-interfaces) and [isolated module tests](../test/README.md#module-unit-tests).

## Startup Sequence

`zshrc` currently sources the static layer in this exact order:

1. `modules/static/dotenv.sh`
2. `scripts/dot-bootstrap.sh` (when present)
3. `modules/static/foundation.sh`
4. `modules/static/ssh.sh`
5. `modules/static/limits.sh`
6. `modules/static/autoload.sh`
7. `modules/static/dot.sh`
8. `dot::static::foundation::load-zsh-options` (reads options from `data/zsh.yaml`)
9. `dot::static::foundation::load-modules` (all dynamic modules below)
10. `dot::foundation::compile-terminfo`

## Dynamic Modules (Load Order)

Dynamic modules are discovered using:

`find modules -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*-*.sh' | sort -d`

### Tier 000 (foundation)

| File                  | Purpose                                                                        |
| --------------------- | ------------------------------------------------------------------------------ |
| `000-a-base.sh`       | Base host/runtime defaults and baseline env values.                            |
| `000-a-brew.sh`       | Homebrew discovery/helpers and brew-centric utility functions.                 |
| `000-a-config.sh`     | Config accessors based on `DOT_SHELL_DATA` (`data/zsh.yaml` preferred).        |
| `000-a-emulation.sh`  | Architecture/shell emulation helpers.                                          |
| `000-a-foundation.sh` | Foundation glue and helpers consumed by later modules.                         |
| `000-a-iterm.sh`      | iTerm integration setup.                                                       |
| `000-a-math.sh`       | Shell math helper wrappers.                                                    |
| `000-a-output.sh`     | Splash/quote/output formatting helpers.                                        |
| `000-a-paths.sh`      | PATH composition (`edirect`, `bin`, `scripts`, `~/bin`) and path helper funcs. |
| `000-a-plugins.sh`    | Plugin/env wiring helpers used by plugin ecosystem setup.                      |
| `000-a-secrets.sh`    | Secret loading/masking helpers.                                                |
| `000-a-tools.sh`      | Interactive file preview helpers.                                              |
| `000-a-vendor.sh`     | Vendor framework integrations (e.g., vendored shell helpers).                  |
| `000-b-aliases.sh`    | General shell aliases.                                                         |
| `000-b-zsh.sh`        | zstyle defaults and completion tuning.                                         |
| `000-c-git.sh`        | Git defaults and git utility helpers.                                          |
| `000-c-mac.sh`        | macOS-specific helper functions.                                               |
| `000-d-extensions.sh` | Optional extension hooks (guarded by disable flags).                           |
| `000-d-notes.sh`      | Notes-related helper hooks.                                                    |
| `000-d-podman.sh`     | Podman-related env tuning.                                                     |

### Tier 001 (language/runtime)

| File              | Purpose                                                 |
| ----------------- | ------------------------------------------------------- |
| `001-a-ai.sh`     | AI tooling integration hooks.                           |
| `001-a-p10k.sh`   | Powerlevel10k prompt configuration loading.             |
| `001-a-tmux.sh`   | Tmux session helpers and defaults.                      |
| `001-d-node.sh`   | Node runtime/tooling setup (`n`/`npm`) and env exports. |
| `001-d-python.sh` | Python runtime/tooling setup (`uv`) and env exports.    |
| `001-d-rust.sh`   | Rust toolchain env setup + `dot::rust` rustup helpers.  |
| `001-z-java.sh`   | Java/JDK env setup (`jenv`-aware).                      |

### Tier 002 (domain-specific)

| File           | Purpose                        |
| -------------- | ------------------------------ |
| `002-a-sre.sh` | SRE/IaC helper exports.        |
| `002-b-bio.sh` | Bioinformatics helper exports. |

### Tier 999 (finalization)

| File                       | Purpose                                                    |
| -------------------------- | ---------------------------------------------------------- |
| `999-a-completion.sh`      | Completion finalization hooks.                             |
| `999-a-terminal.sh`        | Terminal capability/fzf terminal integration finalization. |
| `999-audio-video-tools.sh` | Audio/video tooling helper exports.                        |
| `999-z-work.sh`            | Late-loading work profile hooks.                           |

## Static Modules

| File                   | Purpose                                                                                                                         |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `static/dotenv.sh`     | Canonical `DOT_*` path/runtime/feature-flag exports.                                                                            |
| `static/foundation.sh` | Foundational functions (`dot::static::foundation::load-zsh-options`, `dot::static::foundation::load-modules`, ssh key helpers). |
| `static/ssh.sh`        | SSH environment and key helper setup.                                                                                           |
| `static/limits.sh`     | Shell limit discovery/exports.                                                                                                  |
| `static/autoload.sh`   | ZSH autoload wiring.                                                                                                            |
| `static/dot.sh`        | `dot::static::shell` command and related helpers.                                                                               |
| `static/lib/*.sh`      | Internal bootstrap/platform helper library.                                                                                     |

## Naming Convention

- `NNN`: major phase (load tier)
- `a-z`: sub-order within the phase
- remainder: feature domain

Example: `001-d-python.sh` loads after `001-a-tmux.sh` and before `001-d-rust.sh`.

## Disable Flags

Most dynamic modules support one or more `DOT_DISABLE_*` flags exported by `modules/static/dotenv.sh`. Use these to skip optional integrations without editing module files.

See [DOT_VARS.md](../docs/details/DOT_VARS.md) for the full variable index.

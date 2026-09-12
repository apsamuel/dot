# Copilot instructions

## Project overview

`dot` is a macOS-first ZSH configuration and bootstrap framework. `zshrc` is the runtime entry
point; it loads foundational shell modules, applies `data/zsh.yaml`, then loads numbered dynamic
modules in lexical order. The root `Makefile` orchestrates installation, configuration, health
checks, tests, and vendored subprojects. Treat the checked-in `vendor/` trees as pinned git
submodules rather than ordinary source.

The repository is primarily Bash/ZSH, with standalone Python utilities in `bin/`, a Swift package
for Apple VM control in `bin/apple-vm-helper/`, and a TypeScript VS Code SBOM extension in
`data/sbom/`.

## Commands

The root Makefile requires GNU Make 4.4+ and runs recipes with Bash strict mode.

```bash
# Discover supported targets
make help

# Tests
make test
make test-verbose
make test-module MODULE=000-a-config  # substring filter; runs one matching test suite
zsh test/modules/test_000-a-config.sh # direct single-suite invocation

# Checks and formatting
shellcheck path/to/changed-script.sh   # lint changed shell files
make lint-md                          # Prettier check for Markdown
make format-md                        # rewrite Markdown with Prettier
make brewfile-check                   # verify Brewfiles match .dependencies.yml
make dry-run-verify                   # prove supported DRY=1 flows do not mutate the tree
make doctor                           # read-only host, symlink, submodule, and vendor health check

# Component builds
swift build -c release --package-path bin/apple-vm-helper
cd data/sbom && npm run compile
cd data/sbom && npm run lint
```

Use `DRY=1 make dot-bootstrap` to inspect the full bootstrap plan. `make dot-bootstrap` changes the
developer machine (packages, symlinks, shell configuration, and submodules), so do not run it
without explicit user intent.

CI currently runs CodeQL (`.github/workflows/codeql.yml`) and TruffleHog
(`.github/workflows/secret-scanner.yaml`); it does not run the local unit-test or formatting
targets.

## Architecture

- `zshrc` establishes non-interactive/VS Code safeguards, sources static modules in an explicit
  order, loads options from `data/zsh.yaml`, then calls
  `dot::static::foundation::load-modules`.
- `modules/static/` is the always-loaded foundation. `dotenv.sh` defines canonical `DOT_*` paths
  and feature flags; `logging.sh` supplies shared logging; `foundation.sh` owns option loading,
  module discovery, history management, and secret/SSH helpers.
- `modules/NNN-x-name.sh` contains feature modules. `foundation.sh` discovers files matching
  `[0-9][0-9][0-9]-*-*.sh` and sorts them lexically, so renaming a module changes startup order.
  Tier `000` is foundational, `001` is language/tooling integration, `002` is domain-specific,
  and `999` is finalization.
- `data/zsh.yaml` is the runtime configuration source of truth for theme, options, plugins, and
  language dependencies. `.dependencies.yml` is the source for generated `data/Brewfile` and
  `data/Brewfile.cask`; update it and regenerate with `make brewfile`.
- `scripts/dot-bootstrap.sh` implements the operations exposed by the root Makefile. Mutating
  bootstrap work is expected to flow through its `dryrun`/`dry_*` helpers so `DOT_DRY_RUN=1`
  remains non-mutating and idempotent.
- `bin/` contains user-facing commands placed on `PATH`; `scripts/` contains repository
  maintenance commands. `bin/ivm.py` selects VM backends and prefers the Swift
  `applevm-helper`, falling back to `vz`.
- `test/framework.sh` is a Bash/ZSH-compatible TAP harness. `test/run_unit.sh` discovers
  `test/modules/test_*.sh`, runs each suite in a separate ZSH process, and supports a filename
  substring filter. Tests source real modules against `test/mocks/env.sh`, fixture data, and
  shell-function mocks from `test/mocks/tools.sh`.

## Repository conventions

- Preserve the startup layering and lexical filename scheme. Static modules must be safe for all
  sessions; optional dynamic integrations should have a `DOT_DISABLE_*` guard whose default is
  declared in `modules/static/dotenv.sh`.
- Shell code commonly targets both Bash and ZSH even when files declare
  `# shellcheck shell=bash`. Prefer `[[ ... ]]`, quote expansions, use local variables in
  functions, and add narrow ShellCheck suppressions only where the cross-shell implementation
  requires them.
- Use namespaced public shell functions such as `dot::config::theme` and
  `dot::static::foundation::load-modules`. Bootstrap-local helpers use descriptive private names
  such as `_is_dry` or `dry_mkdir`.
- Keep automation non-interactive. Do not introduce prompts, alternate-screen programs, splash
  output, tmux attachment, or secret loading into the minimal path guarded in `zshrc`.
- Preserve bootstrap idempotency and dry-run behavior. Route filesystem or system mutations
  through existing helpers in `scripts/dot-bootstrap.sh`; add corresponding coverage and run
  `make dry-run-verify` when changing those flows.
- Module tests follow the existing portable bootstrap block, source `test/framework.sh` plus
  mocks, call `source_module`, group cases with `describe`, register them with `it`, and finish
  with `tap_summary`. Mock external commands rather than touching the real host.
- Never use real `$HOME`, iCloud, credentials, package managers, or VM state in unit tests.
  `test/mocks/env.sh` supplies isolated paths and defaults `DOT_DRY_RUN=1`.
- Update the relevant reference when behavior changes: `modules/README.md` for module inventory
  and load order, `bin/README.md` for user commands, `scripts/README.md` for maintenance tools,
  and `docs/details/DOT_VARS.md` for `DOT_*` variables.
- Do not edit files inside `vendor/` as if they were repository-owned. Make vendor changes through
  the root dispatch targets (`make vim ...`, `make omz ...`, `make tmux ...`) or in the upstream
  submodule repository, and expect the parent repository to record only the submodule commit.
- Treat secret handling as sensitive. Never print values read from iCloud secret files or expose
  MCP credentials; keep `.trufflehog-exclude.txt` narrowly scoped to verified false positives.
- Prefer current executable sources over stale prose when they disagree: the root `Makefile`,
  `zshrc`, and `test/run_unit.sh` define the active commands and loading behavior.

Repository MCP configuration is in `.vscode/mcp.json`; use the GitHub server for repository,
workflow, and code-scanning context, and Context7 when current third-party API documentation is
needed. Never copy authentication headers or tokens into source, logs, or responses.

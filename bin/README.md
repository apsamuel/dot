# bin

Scripts in this directory are added to `$PATH` by `dot` at shell startup. They can be called directly from any terminal session after the framework is loaded.

---

## Scripts

| Script | Language | Description |
|---|---|---|
| `dot-bootstrap.sh` | Bash | First-run installer — installs dependencies, symlinks configs, and sets up the environment. See [BOOTSTRAP.md](../docs/details/BOOTSTRAP.md). |
| `brew-bootstrap.sh` | Bash | Thin wrapper around Homebrew for `install`, `uninstall`, `upgrade`, and `info` actions. Usage: `brew-bootstrap.sh <action>` |
| `git-branch-zap.sh` | Bash | Deletes merged local branches that are no longer needed. |
| `git-changelog.sh` | Bash | Generates a formatted git changelog for the `dot` repo from conventional commits. |
| `git-import-org.py` | Python | Lists and clones repositories from a GitHub organization via the GitHub API. Requires `GITHUB_TOKEN` env var. |
| `git-import-org.sh` | Bash | Shell wrapper for cloning GitHub organization repositories. |
| `git-loc.sh` | Bash | Reports lines of code statistics for the current repository. |
| `git-secret.sh` | Bash | Rewrites git history to permanently remove secrets using `git-filter-repo`. Requires `brew install git-filter-repo`. Flags: `-s <secret>` (repeatable), `-f <rules-file>`, `-r <replacement>` (default `***REMOVED***`), `-m` submodules, `-n` dry run, `-v` verbose, `--push` force-push after scrub. |
| `imgcat.sh` | Bash | Prints images inline in the terminal (iTerm2 / compatible terminals). |
| `isync.py` | Python | Reads and displays iCloud account info and service enablement from `MobileMeAccounts.plist`. |
| `ivm.py` | Python | `vmctl` — unified VM control utility for macOS. Supports backends: UTM (`utmctl`), QEMU, Podman Machine, and Apple Virtualization.framework (native helper or `vz` CLI). Usage: `ivm.py <backends\|list\|start\|stop\|suspend\|resume\|status\|shell> [--backend <name>]` |
| `macctl.py` | Python | macOS system control utility — inspects and manages iCloud, Notes, Music library paths, and MobileMeAccounts. |
| `plugctl.sh` | Bash | Installs oh-my-zsh themes and plugins. |
| `python-create-env.sh` | Bash | Creates a Python virtual environment for the current project using `uv`. |
| `rust-project-format.sh` | Bash | Recursively finds and formats all `.rs` source files using `rustfmt`. |
| `secret-report.sh` | Bash | Scans git history (all refs), commit messages, and the working tree for exposed secret values and keys. Severity levels: `HIGH` (value in diff or working tree), `MEDIUM` (key in commit message), `LOW` (key in working tree). Flags: `-f <secrets.json>` (required), `-r <repo>`, `-m` submodules, `-u` fetch remotes, `-n <count>` depth limit, `-o pretty\|json`, `-d` debug. |
| `tmux-code.sh` | Bash | Opens or attaches to a tmux session named after the current directory. Flags: `-s <name>` custom name, `-d` detach, `-k` kill, `-l` list, `-h` help. |
| `turtle-run.sh` | Bash | Builds and runs the Turtle shell interpreter. |
| `zsh-mask-secret.sh` | ZSH | Secret masking, detection, ZLE integration, and git pre-commit hook installer. Four modes: `-m` mask text, `-c` check for secrets, `-Z` print sourceable ZLE hooks, `-G <path>` install a git pre-commit hook. Reads secrets from a flat JSON file (`-f`). |

### Apple VM Helper

`applevm-helper` is a compiled Swift binary (source in `apple-vm-helper/`) that speaks directly to Apple's Virtualization.framework. It provides full VM lifecycle control (start, stop, suspend, resume, status) and is the preferred provider for `ivm.py`'s `apple` backend. See [BOOTSTRAP.md](../docs/details/BOOTSTRAP.md) for build instructions.

---

## `lib/`

Internal helpers shared across `bin/` scripts. Not intended to be called directly.

| File | Description |
|---|---|
| `lib/common.sh` | Shared utility function stubs (placeholder — currently empty) |

---

## Adding a Script

Drop a `.sh` (or executable Python/Go file) in `bin/`. It will be automatically available in any shell session after restart because `DOT_BIN` (`~/.dot/bin`) is prepended to `$PATH` by `zlib/000-aa-paths.sh`.

# bin

Scripts in this directory are added to `$PATH` by `dot` at shell startup. They can be called directly from any terminal session after the framework is loaded.

---

## Scripts

| Script | Language | Description |
|---|---|---|
| `bootstrap.sh` | Bash | First-run installer — installs dependencies, symlinks configs, and sets up the environment. See [BOOTSTRAP.md](../docs/details/BOOTSTRAP.md). |
| `brewstrap.sh` | Bash | Thin wrapper around Homebrew for `install`, `uninstall`, `upgrade`, and `info` actions. Usage: `brewstrap.sh <action>` |
| `git-changelog.sh` | Bash | Generates a formatted git changelog for the `dot` repo from conventional commits. |
| `mask-secret.sh` | ZSH | Secret masking, detection, ZLE integration, and git pre-commit hook installer. Four modes: `-m` mask text, `-c` check for secrets, `-Z` print sourceable ZLE hooks, `-G <path>` install a git pre-commit hook. Reads secrets from a flat JSON file (`-f`). |
| `secret-report.sh` | Bash | Scans git history (all refs), commit messages, and the working tree for exposed secret values and keys. Severity levels: `HIGH` (value in diff or working tree), `MEDIUM` (key in commit message), `LOW` (key in working tree). Flags: `-f <secrets.json>` (required), `-r <repo>`, `-m` submodules, `-u` fetch remotes, `-n <count>` depth limit, `-o pretty\|json`, `-d` debug. |
| `secret-scrub.sh` | Bash | Rewrites git history to permanently remove secrets using `git-filter-repo`. Requires `brew install git-filter-repo`. Flags: `-s <secret>` (repeatable), `-f <rules-file>`, `-r <replacement>` (default `***REMOVED***`), `-m` submodules, `-n` dry run, `-v` verbose, `--push` force-push after scrub. |
| `tmux-code.sh` | Bash | Opens or attaches to a tmux session named after the current directory. Flags: `-s <name>` custom name, `-d` detach, `-k` kill, `-l` list, `-h` help. |
| `utmctlx.py` | Python | Control utility for [UTM](https://mac.getutm.app) virtual machines on macOS. Wraps `utmctl` with extended functionality. |

---

## `lib/`

Internal helpers shared across `bin/` scripts. Not intended to be called directly.

| File | Description |
|---|---|
| `lib/common.sh` | Shared utility function stubs (placeholder — currently empty) |

---

## Adding a Script

Drop a `.sh` (or executable Python/Go file) in `bin/`. It will be automatically available in any shell session after restart because `DOT_BIN` (`~/.dot/bin`) is prepended to `$PATH` by `zlib/000-aa-paths.sh`.

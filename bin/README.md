# bin

Scripts in this directory are added to `$PATH` by `dot` at shell startup. They can be called directly from any terminal session after the framework is loaded.

---

## Scripts

| Script | Language | Description |
|---|---|---|
| `bootstrap.sh` | Bash | First-run installer — installs dependencies, symlinks configs, and sets up the environment. See [BOOTSTRAP.md](../docs/details/BOOTSTRAP.md). |
| `brewstrap.sh` | Bash | Thin wrapper around Homebrew for `install`, `uninstall`, `upgrade`, and `info` actions. Usage: `brewstrap.sh <action>` |
| `changelog.sh` | Bash | Generates a formatted git changelog for the `dot` repo. |
| `mask.sh` | Bash | Masks sensitive values in output — useful for piping commands that might print secrets. |
| `tmux-code.sh` | Bash | Opens a tmux session wired to a VS Code workspace, enabling a consistent tmux + editor layout. |
| `utmctlx.py` | Python | Control utility for [UTM](https://mac.getutm.app) virtual machines on macOS. Wraps `utmctl` with extended functionality. |

## `lib/`

Internal helpers shared across `bin/` scripts. Not intended to be called directly.

| File | Description |
|---|---|
| `lib/common.sh` | Shared utility functions used by the other bin scripts |

---

## Adding a Script

Drop a `.sh` (or executable Python/Go file) in `bin/`. It will be automatically available in any shell session after restart because `DOT_BIN` (`~/.dot/bin`) is prepended to `$PATH` by `zlib/000-aa-paths.sh`.

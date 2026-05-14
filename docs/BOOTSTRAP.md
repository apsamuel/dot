# 🔄 Bootstrap & Vendor Management

This document describes the bootstrap process, dry-run/debug/verbose modes, and idempotent vendor management across the `dot` framework.

---

## Overview

**`dot`** uses a hierarchical Makefile + bash architecture to ensure **100% idempotent**, **atomic**, and **non-mutating** behavior in dry-run mode. All core install/update operations across the root, oh-my-zsh, oh-my-tmux, and vim subsystems support three control modes:

| Flag        | Env Var         | Purpose                                        |
| ----------- | --------------- | ---------------------------------------------- |
| `DRY=1`     | `DOT_DRY_RUN=1` | Dry-run: print planned actions, zero mutations |
| `DEBUG=1`   | `DOT_DEBUG=1`   | Enable bash xtrace (`set -x`) for visibility   |
| `VERBOSE=1` | `DOT_VERBOSE=1` | Verbose output in git/yq/cmake operations      |

---

## Root Makefile (`./Makefile`)

### Entry Points

#### Full Bootstrap
```bash
# Preview everything without changes
DRY=1 make dot-bootstrap

# Run the full install
make dot-bootstrap

# Run specific subsystems
make check-brew               # install/update Homebrew packages
make config-zsh               # symlink ~/.zshrc, load modules
make config-vim               # vendor vim plugins, build natives
make config-omz-plugins       # sync oh-my-zsh custom plugins
make config-tmux              # sync oh-my-tmux plugins, link configs
```

#### Vendor Passthroughs
All vendor management targets are passthrough to the respective vendor Makefiles:

```bash
# vim
make vim-install                           # symlink + submodule init + build
make vim-update                            # pull latest plugins + rebuild
make vim-add PLUGIN=owner/repo BUNDLE=shared|nvim
make vim-rm PLUGIN=name BUNDLE=shared|nvim
make vim-list                              # list vendored plugins

# oh-my-zsh
make omz-add-plugin OWNER=org REPO=name [EXEC="cmd"]
make omz-add-theme OWNER=org REPO=name
make omz-remove-plugin OWNER=org REPO=name
make omz-remove-theme OWNER=org REPO=name
make omz-sync-plugins                      # reconcile plugins from data/zsh.yaml
make omz-sync-themes                       # reconcile themes from data/zsh.yaml

# oh-my-tmux
make tmux-install                          # symlink configs + sync plugins
make tmux-update                           # pull latest plugins
make tmux-add-plugin PLUGIN=owner/repo
make tmux-remove-plugin PLUGIN=owner/repo
make tmux-sync-plugins                     # reconcile plugins from .tmux.conf.local
make tmux-list-plugins                     # show declared vs installed
```

### Control Flags

#### `DRY=1` — Dry-run Mode
When `DRY=1` is set at the root level, it is automatically propagated to all vendor sub-makes via the `VENDOR_FLAGS` macro:

```makefile
VENDOR_FLAGS := DRY="$(DRY)" DEBUG="$(DEBUG)" VERBOSE="$(VERBOSE)" \
                DOT_DRY_RUN="$(DRY)" DOT_DEBUG="$(DEBUG)" DOT_VERBOSE="$(VERBOSE)"
```

**Behavior in dry-run:**
- ✅ All planned actions are printed with `🔮 plan »` prefix
- ✅ No files are created, moved, symlinked, or deleted
- ✅ No git submodule operations execute
- ✅ No git commits or pushes
- ✅ No shell rc files are modified
- ✅ No Homebrew packages are installed
- ✅ No native builds (fzf, jsregexp, treesitter) compile

**Example:**
```bash
$ DRY=1 make dot-bootstrap
🔮 plan » mkdir -p ~/.config/nvim
🔮 plan » ln -snf ~/.dot/vendor/vim ~/.vim
🔮 plan » ln -snf ~/.dot/vendor/vim/init.vim ~/.vimrc
🔮 plan » git submodule add https://github.com/tmux-plugins/tpm vendor/oh-my-tmux/plugins/tpm
[done — zero mutations]
```

#### `DEBUG=1` — Xtrace Mode
When `DEBUG=1` is set, bash xtrace (`set -x`) is enabled in all scripts and Makefile recipes:

```bash
# See every command before execution
DEBUG=1 make vim-install
+ mkdir -p ~/.vim
+ git submodule update --init --recursive vendor/vim/pack/shared/start/vim-surround
+ (cd ~/.vim && vim +helptags! +q)
```

#### `VERBOSE=1` — Verbose Output
When `VERBOSE=1` is set, all subcommands (git, yq, cmake, make) receive verbose flags:

```bash
VERBOSE=1 make omz-sync-plugins
git submodule update --init --recursive --verbose vendor/oh-my-zsh/plugins/...
yq -i '.plugins |= ...' --verbose data/zsh.yaml
```

#### Combined Flags
Flags can be combined for maximum visibility during troubleshooting:

```bash
# Dry-run with full debug output
DRY=1 DEBUG=1 VERBOSE=1 make config-vim

# Output will show every planned action with xtrace expansion
+ [[ 1 -eq 1 ]]  # DOT_DRY_RUN check
+ echo "[dry-run] ln -snf ~/.dot/vendor/vim ~/.vim"
[dry-run] ln -snf ~/.dot/vendor/vim ~/.vim
+ return 0
```

---

## Vendor Makefiles

Each vendor subsystem has its own Makefile that enforces dry-run idempotency at the local level.

### oh-my-zsh (`vendor/oh-my-zsh/Makefile`)

#### Targets
```bash
make add-plugin OWNER=org REPO=name [EXEC="post-init-cmd"]
make add-theme OWNER=org REPO=name
make remove-plugin OWNER=org REPO=name
make remove-theme OWNER=org REPO=name
make sync-plugins      # reconcile from data/zsh.yaml
make sync-themes       # reconcile from data/zsh.yaml
make list
make help
```

#### Dry-run Behavior
In `DOT_DRY_RUN=1` mode:
- ✅ All `git submodule add/deinit` operations are skipped (printed instead)
- ✅ All `yq -i` YAML mutations are skipped
- ✅ `EXEC` post-init commands are NOT executed (printed as preview)
- ✅ All planned mutations output `[dry-run] <cmd>` prefix

**Example:**
```bash
$ DRY=1 make omz-add-plugin OWNER=zsh-users REPO=zsh-autosuggestions
[dry-run] git submodule add https://github.com/zsh-users/zsh-autosuggestions vendor/oh-my-zsh/plugins/zsh-autosuggestions
[dry-run] yq -i '.zsh.plugins += ["zsh-autosuggestions"]' data/zsh.yaml
```

#### Idempotency Guarantees
- ✅ `sync-plugins` is **fully idempotent** — running it twice yields zero mutations
- ✅ Plugins already installed are checked via git submodule status before adding
- ✅ Removed plugins are validated via `git submodule deinit` with `--force`

---

### oh-my-tmux (`vendor/oh-my-tmux/Makefile` + `lib/tmux-helpers.sh`)

#### Targets
```bash
make install                 # symlink configs, sync plugins
make update                  # pull latest plugins
make add-plugin PLUGIN=owner/repo
make remove-plugin PLUGIN=owner/repo
make sync-plugins            # reconcile from .tmux.conf.local
make clean                   # remove config symlinks from ~
make status                  # show symlink health + plugin status
make list-plugins            # list declared vs installed
make help
```

#### Dry-run Behavior
In `DOT_DRY_RUN=1` mode:
- ✅ All symlinks (`ln -snf`) are skipped (printed as plan)
- ✅ All `git submodule` operations are skipped
- ✅ All `tmux display-message` notifications are suppressed (no noise in dry-run)
- ✅ Plugin sync/clean operations show planned git commands

**Example:**
```bash
$ DRY=1 make tmux-install
[dry-run] ln -snf ~/.dot/vendor/oh-my-tmux/.tmux.conf ~/.tmux.conf
[dry-run] ln -snf ~/.dot/vendor/oh-my-tmux/.tmux.conf.local ~/.tmux.conf.local
[dry-run] git submodule update --init --recursive vendor/oh-my-tmux/plugins/tpm
```

#### Runtime Helper (`lib/tmux-helpers.sh`)
The tmux plugin manager is implemented in `lib/tmux-helpers.sh`, which is invoked both by the Makefile and at runtime (inside `.tmux.conf`). It respects `DOT_DRY_RUN` and `DOT_DEBUG` environment variables:

```bash
# Inside .tmux.conf
set-environment -g DOT_DRY_RUN "$DOT_DRY_RUN"
bind-key I run-shell "DOT_DRY_RUN=$DOT_DRY_RUN $DOTFILES/vendor/oh-my-tmux/lib/tmux-helpers.sh"
```

---

### vim (`vendor/vim/Makefile` + `install.sh`)

#### Targets
```bash
make install        # symlinks ~/.vim + submodule init + build natives
make update         # pull latest plugins + rebuild
make build          # compile native artifacts (fzf, jsregexp, treesitter)
make helptags       # regenerate vim/nvim helptags
make add PLUGIN=owner/repo BUNDLE=shared|nvim
make rm PLUGIN=name BUNDLE=shared|nvim
make list           # list all plugins
make plugins        # show which plugins each editor loads
make doctor         # run :checkhealth in nvim
make help
```

#### Dry-run Behavior
In `DOT_DRY_RUN=1` mode:
- ✅ All symlinks (`ln -snf`, `mv`) are skipped
- ✅ All `mkdir` operations are skipped
- ✅ All `git submodule init/update` operations are skipped
- ✅ All native builds (fzf, jsregexp, treesitter) are skipped
- ✅ All vim/nvim helptag generation is skipped
- ✅ All planned mutations output `[dry-run] <cmd>` prefix

**Example:**
```bash
$ DRY=1 make vim-install
[dry-run] mkdir -p ~/.config/nvim
[dry-run] ln -snf ~/.dot/vendor/vim ~/.vim
[dry-run] ln -snf ~/.dot/vendor/vim/init.vim ~/.vimrc
[dry-run] git submodule update --init --recursive vendor/vim/pack/shared/start
[dry-run] (cd ~/.vim && vim +helptags! +q)
[dry-run] (cd ~/.vim && cmake -S build -B build/build)
```

#### Install Script (`install.sh`)
The actual installation logic lives in `install.sh`, which is driven by the Makefile. All mutations are guarded by the `dry_run()` function:

```bash
dry_run() {
    if [[ ${DOT_DRY_RUN} -eq 1 ]]; then
        echo "[dry-run] $@"
        return 0
    fi
    "$@"
}

# Usage:
dry_run mkdir -p ~/.config/nvim
dry_run ln -snf ~/.dot/vendor/vim ~/.vim
dry_run git submodule update --init --recursive
```

---

## Bootstrap Script (`scripts/dot-bootstrap.sh`)

The root bootstrap script houses the core logic for orchestrating install steps and provides dry-run-aware primitives.

### Function Signature
```bash
run [--dry-run | -n] [--debug] [--verbose]
```

### Environment Variables
The script sets `DOT_DRY_RUN`, `DOT_DEBUG`, and `DOT_VERBOSE` based on flags, then sources all bootstrap functions (`check_*`, `config_*`, `install_*`, etc.):

```bash
DOT_DRY_RUN=0
DOT_DEBUG=0
DOT_VERBOSE=0

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DOT_DRY_RUN=1; shift ;;
        --debug) DOT_DEBUG=1; shift ;;
        --verbose) DOT_VERBOSE=1; shift ;;
    esac
done
```

### Dry-run Primitives
The script provides dry-run-safe helpers for common operations:

```bash
dry_mkdir()   # mkdir -p, skipped if DRY_RUN=1
dry_rm()      # rm, skipped if DRY_RUN=1
dry_rmrf()    # rm -rf, skipped if DRY_RUN=1
dry_mv()      # mv, skipped if DRY_RUN=1
dry_cp()      # cp, skipped if DRY_RUN=1
dryrun()      # generic wrapper: print "[plan »]", return 0 in dry-run
```

### Example: Invoke with Flags
```bash
# Dry-run from command line
scripts/dot-bootstrap.sh --dry-run --debug

# Or via Make
DRY=1 DEBUG=1 make dot-bootstrap
```

---

## Integration: Root → Vendor → Script

The control flow is:

1. **Root Makefile** (`./Makefile`):
   - User specifies `DRY=1 make vim-install`
   - Root Makefile sets `VENDOR_FLAGS` macro with `DRY=1 DOT_DRY_RUN=1`
   - Invokes `$(MAKE) -C $(VENDOR_VIM) $(VENDOR_FLAGS) install`

2. **Vendor Makefile** (e.g., `vendor/vim/Makefile`):
   - Receives `DOT_DRY_RUN=1` from environment
   - Conditionally wraps mutations: `ifeq ($(DOT_DRY_RUN),1) <skip> else <execute> endif`
   - Calls `install.sh` with `DOT_DRY_RUN=1` env var

3. **Script** (e.g., `vendor/vim/install.sh`):
   - Reads `DOT_DRY_RUN` environment variable
   - Routes all mutations through `dry_run()` function
   - Outputs `[dry-run] <cmd>` instead of executing

**Result:** Zero mutations when `DRY=1` is used.

---

## Idempotency Contract

All major install/update operations are **guaranteed idempotent**:

| Operation               | Idempotent? | Verification                     |
| ----------------------- | ----------- | -------------------------------- |
| `make vim-install`      | ✅ Yes       | Run twice, zero file changes     |
| `make omz-sync-plugins` | ✅ Yes       | Reconciles to YAML, then stable  |
| `make tmux-install`     | ✅ Yes       | Symlinks exist, re-link is no-op |
| `make config-zsh`       | ✅ Yes       | Same symlinks, zero overwrites   |
| `DRY=1 make <anything>` | ✅ Yes       | Zero mutations, all planned      |

**Verification Approach:**
```bash
# Before and after dry-run should be identical
git status > /tmp/before.txt
DRY=1 make dot-bootstrap
git status > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt  # should be empty
```

---

## Troubleshooting

### "Why didn't `DRY=1` prevent a mutation?"

Ensure the flag is passed all the way through:
1. Check that root Makefile receives `DRY=1` (confirm with `make -n`)
2. Confirm vendor Makefile receives `DOT_DRY_RUN=1` (add `@echo DOT_DRY_RUN=$(DOT_DRY_RUN)` to target)
3. Verify backing script checks `[[ ${DOT_DRY_RUN} -eq 1 ]]` before mutations

### "I need to see every command being executed."

Use `DEBUG=1`:
```bash
DEBUG=1 make vim-install  # shows xtrace output
```

Or combine with dry-run:
```bash
DRY=1 DEBUG=1 make vim-install  # planned actions + xtrace
```

### "Help! I accidentally ran without dry-run and want to undo."

Mutations in `dot` are designed to be safe:
- Symlinks can be safely re-created (`ln -snf` overwrites)
- Submodule additions/removals are reversible (check `git status`)
- Brew packages can be uninstalled via `brew uninstall <pkg>`

If needed, use `git diff` and `git checkout` to revert changes to tracked files:
```bash
git status
git diff data/zsh.yaml    # review what changed
git checkout data/zsh.yaml # revert if desired
```

---

## See Also

- [README.md](../README.md) — Overview and quick start
- [Makefile](../Makefile) — Root orchestration
- [vendor/oh-my-zsh/Makefile](../vendor/oh-my-zsh/Makefile) — ZSH plugin management
- [vendor/oh-my-tmux/Makefile](../vendor/oh-my-tmux/Makefile) — tmux configuration
- [vendor/vim/Makefile](../vendor/vim/Makefile) — vim/nvim setup
- [scripts/dot-bootstrap.sh](../scripts/dot-bootstrap.sh) — Core bootstrap logic

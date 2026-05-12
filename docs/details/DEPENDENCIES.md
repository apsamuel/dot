# 🧰 System Dependencies

What `dot` expects to find on the host before it can fully express its capabilities. Use this as an **engineer reference** — every entry cites where it is consumed and what happens when it's missing.

> 🛠️ **Audit your machine** with [`scripts/dot-deps-report.sh`](../../scripts/README.md#-dot-deps-reportsh). It mirrors the tier table below and prints `🟢 / 🟠 / 🔴` per tool.

---

## 📑 TL;DR — Tier 0 essentials

These must exist before [`scripts/dot-bootstrap.sh`](../../scripts/dot-bootstrap.sh) or [`zshrc`](../../zshrc) can succeed.

| Tool      | Why                                                                                                        | Install                                                  |
| --------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `bash`    | Bootstrap is bash 3.2-compatible                                                                           | macOS ships `/bin/bash` 3.2; `brew install bash` for 5.x |
| `zsh`     | Login shell `dot` configures                                                                               | macOS ships `/bin/zsh`; `brew install zsh`               |
| `git`     | Submodule sync, secrets, fugitive, half the modules                                                        | `xcode-select --install` (macOS) or `brew install git`   |
| `curl`    | Brew installer, `getNodeJS`, fzf, secrets fetch                                                            | macOS ships `curl`                                       |
| `jq`      | Brew JSON parsing in [`modules/000-a-homebrew.sh`](../../modules/000-a-homebrew.sh), `brew info` consumers | `brew install jq` (in [Brewfile](../../data/Brewfile))   |
| `yq`      | Reads [`data/zsh.yaml`](../../data/zsh.yaml) at every shell start (theme, plugins, language versions)      | `brew install yq` (in [Brewfile](../../data/Brewfile))   |
| `brew`    | All Tier 1/2 installs flow through it                                                                      | `bash bin/brew-bootstrap.sh install`                     |
| `tmux`    | [`check_omtmux`](../../scripts/dot-bootstrap.sh) installs TPM plugins via a transient session    | `brew install tmux`                                      |
| Xcode CLT | `/usr/bin/git`, `swift build` for [`bin/applevm-helper`](../../bin/apple-vm-helper/)                       | `xcode-select --install`                                 |

The [`Brewfile`](../../data/Brewfile) intentionally lists only `yq` and `jq` — everything else is either OS-shipped, installed by sub-bootstrappers, or feature-gated and looked up via `command -v`.

---

## 🏷️ Tier 0 — bootstrap essentials

Each tool below is **assumed present**. If missing, [`preflight`](../../scripts/dot-bootstrap.sh) prints `🔴 not installed` and downstream steps fail.

| Tool      | Referenced from                                                                                                                                                                                                      | Failure mode if missing                   |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `bash`    | [`scripts/dot-bootstrap.sh`](../../scripts/dot-bootstrap.sh) shebang; bash 3.2 syntax preserved                                                                                                                      | Script will not execute                   |
| `zsh`     | [`zshrc`](../../zshrc), every `modules/*.sh`                                                                                                                                                                         | `dot` is a no-op in any other shell       |
| `git`     | [`scripts/submodule-sync.sh`](../../scripts/submodule-sync.sh), [`bin/git-*`](../../bin/), `vim-fugitive`, `gitsigns`                                                                                                | Submodules cannot be fetched              |
| `curl`    | [`bin/brew-bootstrap.sh`](../../bin/brew-bootstrap.sh), [`modules/001-d-node.sh`](../../modules/001-d-node.sh) `getNodeJS`, secret loaders                                                                           | Cannot install Homebrew or fetch tarballs |
| `jq`      | [`modules/000-a-homebrew.sh`](../../modules/000-a-homebrew.sh), [`modules/999-a-terminal.sh`](../../modules/999-a-terminal.sh) (fzf cellar lookup)                                                                   | Brew helpers and fzf wiring break         |
| `yq`      | [`zshrc`](../../zshrc), [`modules/001-d-python.sh`](../../modules/001-d-python.sh), [`modules/001-d-node.sh`](../../modules/001-d-node.sh), [`modules/000-a-output.sh`](../../modules/000-a-output.sh) `randomQuote` | Theme + plugin list cannot be resolved    |
| `brew`    | [`modules/000-a-homebrew.sh`](../../modules/000-a-homebrew.sh) `eval shellenv`, every `brew*` helper                                                                                                                 | Tier 1+ installs unavailable              |
| `tmux`    | [`check_omtmux`](../../scripts/dot-bootstrap.sh), [`modules/001-a-tmux.sh`](../../modules/001-a-tmux.sh)                                                                                                   | TPM plugin install is skipped             |
| Xcode CLT | [`bin/apple-vm-helper/`](../../bin/apple-vm-helper/), `git`                                                                                                                                                          | Apple VM helper cannot be built           |

---

## 🧬 Tier 1 — language toolchains

Gated by `command -v` and/or `DOT_DISABLE_*` flags. Each is required only when you use the corresponding language module.

| Tool               | Used by                                                                                                                                                | Required for                                                                   | Install                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `uv`               | [`config_python`](../../scripts/dot-bootstrap.sh), [`modules/001-d-python.sh`](../../modules/001-d-python.sh)                                  | Python venvs (`~/.venv/<ver>-<arch>-base`)                                     | `brew install uv`                                                  |
| `python3` (≥3.11)  | Default venv interpreter; [`bin/*.py`](../../bin/) (`ivm.py`, `ictl.py`, `isync.py`, `git-import-org.py`)                                              | Bin scripts + venv seed                                                        | macOS ships `python3` (Xcode CLT); pin via `uv venv --python 3.11` |
| `n`                | [`modules/001-d-node.sh`](../../modules/001-d-node.sh), [`config_node`](../../scripts/dot-bootstrap.sh)                                        | Switch to `languages.node.version` from [`data/zsh.yaml`](../../data/zsh.yaml) | `brew install n`                                                   |
| `node` / `npm`     | [`modules/001-d-node.sh`](../../modules/001-d-node.sh), `npm install -g` for `@google/gemini-cli`, `@openai/codex`                                     | Anything Node-flavored                                                         | Installed by `n`                                                   |
| `rustup` + `cargo` | [`modules/001-d-rust.sh`](../../modules/001-d-rust.sh), [`bin/turtle-run.sh`](../../bin/turtle-run.sh), [`turtle/Cargo.toml`](../../turtle/Cargo.toml) | Building [`turtle/`](../../turtle/) and Rust crates                            | `brew install rustup-init && rustup-init`                          |
| `jenv` + `java`    | [`modules/001-z-java.sh`](../../modules/001-z-java.sh)                                                                                                 | `JAVA_HOME` resolution + JDK switching                                         | `brew install jenv openjdk`                                        |
| Xcode `swift`      | [`bin/apple-vm-helper/Package.swift`](../../bin/apple-vm-helper/Package.swift)                                                                         | Native Apple VM helper                                                         | `xcode-select --install`                                           |

---

## 🔧 Tier 2 — daily-use CLI tools

All are guarded by `command -v` or `DOT_DISABLE_*` — `dot` continues to load if they're absent, but the corresponding feature is silently skipped.

| Tool         | Referenced from                                                                                                          | Behavior when missing                         | Install                                            |
| ------------ | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------- | -------------------------------------------------- |
| `fzf`        | [`modules/999-a-terminal.sh`](../../modules/999-a-terminal.sh) (cellar lookup), `vendor/fzf-git`, oh-my-zsh `fzf` plugin | No key-bindings, no completion widgets        | `brew install fzf`                                 |
| `figlet`     | [`modules/000-a-output.sh`](../../modules/000-a-output.sh) `termQuote`, splash screens                                   | Falls back to plain `randomQuote \| lolcat`   | `brew install figlet`                              |
| `lolcat`     | [`modules/000-a-output.sh`](../../modules/000-a-output.sh) (quote pipe)                                                  | Plain quote output                            | `brew install lolcat`                              |
| `jp2a`       | [`modules/000-a-output.sh`](../../modules/000-a-output.sh) `termLogo`                                                    | iCloud splash images cannot render            | `brew install jp2a`                                |
| `kitty`      | [`modules/000-a-output.sh`](../../modules/000-a-output.sh) `termImage`                                                   | `termImage` errors out with a hint            | `brew install --cask kitty`                        |
| `shuf`       | [`modules/000-a-output.sh`](../../modules/000-a-output.sh) `termLogo`/`randomQuote`                                      | Splash + quote selection breaks               | `brew install coreutils` (provides `gshuf`/`shuf`) |
| `thefuck`    | [`modules/000-d-extensions.sh`](../../modules/000-d-extensions.sh) (gated by `DOT_DISABLE_THEFUCK`)                      | No `fuck` alias                               | `brew install thefuck`                             |
| `direnv`     | oh-my-zsh `direnv` plugin                                                                                                | Plugin no-ops                                 | `brew install direnv`                              |
| `z`          | [`modules/000-d-extensions.sh`](../../modules/000-d-extensions.sh) (`DOT_DISABLE_Z`)                                     | Directory autojump unavailable                | `brew install z`                                   |
| `gh`         | oh-my-zsh `gh` plugin, [`bin/git-import-org.sh`](../../bin/git-import-org.sh)                                            | Plugin no-ops; org-import scripts fail        | `brew install gh`                                  |
| `kubectl`    | oh-my-zsh `kubectl` plugin                                                                                               | Plugin no-ops                                 | `brew install kubectl`                             |
| `docker`     | oh-my-zsh `docker` / `docker-compose` plugins                                                                            | Plugin no-ops                                 | `brew install --cask docker`                       |
| `nmap`       | oh-my-zsh `nmap` plugin                                                                                                  | Plugin no-ops                                 | `brew install nmap`                                |
| `ansible`    | oh-my-zsh `ansible` plugin                                                                                               | Plugin no-ops                                 | `brew install ansible`                             |
| `deno`       | oh-my-zsh `deno` plugin                                                                                                  | Plugin no-ops                                 | `brew install deno`                                |
| `pygmentize` | oh-my-zsh `colorize` plugin                                                                                              | Falls back to `chroma` or no highlighting     | `brew install pygments`                            |
| `bat`        | Optional pager / `cless` helper                                                                                          | `cless` falls back to `less`                  | `brew install bat`                                 |
| `iTerm2`     | [`modules/000-d-extensions.sh`](../../modules/000-d-extensions.sh) (`~/.iterm2_shell_integration.zsh`)                   | No iTerm2 shell integration                   | [iTerm2 download](https://iterm2.com)              |
| `podman`     | [`modules/000-d-podman.sh`](../../modules/000-d-podman.sh) (sets compose env var)                                        | Compose warnings re-enable; otherwise a no-op | `brew install podman podman-compose`               |

---

## 🧪 Tier 3 — domain modules

Larger toolboxes loaded only by their respective module. Most modules in this tier are stubs today — install only if you intend to use them.

| Module                                                                       | Domain                                  | Tools you'll want                                                                                         |
| ---------------------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| [`modules/002-a-sre.sh`](../../modules/002-a-sre.sh)                         | SRE / IaC                               | `terraform`, `kubectl`, `helm`, `gh` (currently a placeholder)                                            |
| [`modules/002-b-bio.sh`](../../modules/002-b-bio.sh)                         | Bioinformatics                          | NCBI `edirect` toolkit at `~/edirect`                                                                     |
| [`modules/999-audio-video-tools.sh`](../../modules/999-audio-video-tools.sh) | A/V                                     | `ffmpeg`, `imagemagick`, `blender` (used by [`bin/blender-render.sh`](../../bin/blender-render.sh))       |
| [`modules/000-d-podman.sh`](../../modules/000-d-podman.sh)                   | Containers (rootless)                   | `podman`, `podman-compose`                                                                                |
| [`modules/000-a-emulation.sh`](../../modules/000-a-emulation.sh)             | Multi-arch / multi-shell                | `csh`, `ksh` (optional), Rosetta 2 + Apple Silicon for `spawnArm` / `spawnIntel`                          |
| [`bin/ivm.py`](../../bin/ivm.py) + [`bin/ictl.py`](../../bin/ictl.py)        | Apple Virtualization, UTM, QEMU, Podman | `swift` (native helper), `Code-Hex/tap/vz` (fallback), `qemu`, `utm`, `podman machine` per backend in use |

---

## 🪴 Tier 4 — vendor framework runtime needs

Each vendored submodule is configured by `dot` but expects its own runtime.

| Vendor                                                                                                                                 | Needs                                                                                                     | Notes                                                                                           |
| -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [`vendor/oh-my-zsh`](../../vendor/oh-my-zsh)                                                                                           | `zsh` ≥ 5.x, plus per-plugin binaries (see table below)                                                   | Loaded as `ZSH=$HOME/.dot/vendor/oh-my-zsh`                                                     |
| `vendor/oh-my-zsh/custom/themes/powerlevel10k`                                                                                         | A [Nerd Font](https://www.nerdfonts.com) in your terminal                                                 | Bundled `gitstatusd` is auto-built on first run                                                 |
| `vendor/oh-my-zsh/custom/plugins/F-Sy-H`, `zsh-autosuggestions`, `zsh-vi-mode`, `fzf-tab`, `navi`, `zsh_codex`, `conda-zsh-completion` | Pure ZSH; `fzf-tab` needs `fzf`; `navi` ships its own binary; `zsh_codex` needs `python3` + an OpenAI key | Enable/disable per-plugin via [`data/zsh.yaml`](../../data/zsh.yaml) `plugins.custom[].enabled` |
| [`vendor/oh-my-tmux`](../../vendor/oh-my-tmux)                                                                                         | `tmux` ≥ 3.x; `git` for `tpm` clones                                                                      | `TMUX_PLUGIN_MANAGER_PATH=$DOT_ROOT/vendor/oh-my-tmux/plugins`                                  |
| [`vendor/fzf-git`](../../vendor/fzf-git)                                                                                               | `fzf`, `git`, `bash`/`zsh`                                                                                | Wired in [`modules/999-a-terminal.sh`](../../modules/999-a-terminal.sh)                         |
| [`vendor/bash-commons`](../../vendor/bash-commons)                                                                                     | `bash` ≥ 4                                                                                                | macOS `/bin/bash` is 3.2 — install GNU bash via `brew install bash`                             |
| [`vendor/figlet-fonts`](../../vendor/figlet-fonts)                                                                                     | `figlet`, `lolcat`                                                                                        | Used by `termQuote`                                                                             |
| `vendor/vim` (apsamuel fork)                                                                                                           | `vim` or `nvim`; treesitter parsers need a C compiler                                                     | Optional — only loaded if you symlink it as your `~/.vim`/`~/.config/nvim`                      |

### 🐚 oh-my-zsh builtin plugins — declared in [data/zsh.yaml](../../data/zsh.yaml)

One-liner per plugin in the `plugins.builtin` array. **Required?** = does the plugin need an external binary to do anything useful.

| Plugin              | Expects on `$PATH`  | Required? | Note                                          |
| ------------------- | ------------------- | --------- | --------------------------------------------- |
| `aliases`           | —                   | no        | Lists aliases                                 |
| `alias-finder`      | —                   | no        | Suggests aliases for typed commands           |
| `ansible`           | `ansible`           | optional  | Adds completions + aliases                    |
| `autopep8`          | `autopep8`          | optional  | Python formatter completions                  |
| `brew`              | `brew`              | yes       | Tier 0                                        |
| `colored-man-pages` | `less`              | no        | Re-themes `less`                              |
| `colorize`          | `pygmentize`        | optional  | Falls back to `chroma`                        |
| `copybuffer`        | —                   | no        | Adds `Ctrl-O` to copy current buffer          |
| `copypath`          | `pbcopy` / `xclip`  | optional  | macOS has `pbcopy`                            |
| `dash`              | Dash.app            | optional  | macOS Dash documentation browser              |
| `deno`              | `deno`              | optional  | Completions                                   |
| `direnv`            | `direnv`            | optional  | Auto `direnv hook`                            |
| `docker-compose`    | `docker compose`    | optional  | Completions                                   |
| `docker`            | `docker`            | optional  | Completions + aliases                         |
| `emoji-clock`       | —                   | no        | `emoji-clock` function                        |
| `emoji`             | —                   | no        | Emoji helpers                                 |
| `fzf`               | `fzf`               | yes       | Tier 2                                        |
| `gh`                | `gh`                | optional  | GitHub CLI completions                        |
| `git-extras`        | `git-extras`        | optional  | `brew install git-extras`                     |
| `git`               | `git`               | yes       | Tier 0                                        |
| `gitignore`         | `gi` (gitignore.io) | optional  | `brew install gitignore`                      |
| `gnu-utils`         | `coreutils`         | optional  | `brew install coreutils` to drop `g`-prefixes |
| `history`           | —                   | no        | History helpers                               |
| `kubectl`           | `kubectl`           | optional  | Completions                                   |
| `nmap`              | `nmap`              | optional  | Aliases for common scans                      |
| `node`              | `node`              | optional  | `n`-managed node                              |
| `npm`               | `npm`               | optional  | npm completions                               |
| `python`            | `python3`           | optional  | Aliases                                       |
| `shrink-path`       | —                   | no        | Used by powerlevel10k                         |
| `ssh`               | `ssh`               | yes       | OpenSSH always present                        |
| `ssh-agent`         | `ssh-agent`         | yes       | OpenSSH always present                        |
| `thefuck`           | `thefuck`           | optional  | `brew install thefuck`                        |
| `web-search`        | `open` / `xdg-open` | yes       | macOS / Linux URL opener                      |

### 🪟 oh-my-tmux TPM plugins — declared under `vendor/oh-my-tmux/.tmux.conf.local`

`tmux-sensible`, `tmux-pain-control`, `tmux-yank`, `tmux-window-name`, `tmux-autoreload`, `tmux-prefix-highlight`, `tmux-open`, `tmux-copycat`, `tmux-urlview`, `tmux-test`. None require extra binaries beyond `tmux` ≥ 3.x and (for `tmux-yank`) `pbcopy`/`xclip`.

---

## 📦 Pip / NPM packages — `DOT_INSTALL_LANG_DEPS=1`

Bootstrap will only seed these when explicitly opted in.

| Package              | Source                                                                                                                                             | Installed via                    |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `libtmux==0.36.0`    | [`data/zsh.yaml`](../../data/zsh.yaml) `languages.python.pip.requirements`, [`config/langs/requirements.txt`](../../config/langs/requirements.txt) | `uv pip install --python <venv>` |
| `requests==2.32.5`   | [`requirements.txt`](../../requirements.txt) (used by [`bin/git-import-org.py`](../../bin/git-import-org.py))                                      | `uv pip install`                 |
| `@google/gemini-cli` | [`data/zsh.yaml`](../../data/zsh.yaml) `languages.node.npm.requirements`                                                                           | `npm install -g`                 |
| `@openai/codex`      | [`data/zsh.yaml`](../../data/zsh.yaml) `languages.node.npm.requirements`                                                                           | `npm install -g`                 |

---

## 🍎 Apple-only system commands

`dot` assumes these are present on macOS — no install action needed.

| Command          | Used by                                                                                                                  | Purpose                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| `defaults`       | [`scripts/dot-bootstrap.sh`](../../scripts/dot-bootstrap.sh) `dry_defaults_write`                                        | macOS preference writes               |
| `dscl`           | [`preflight`](../../scripts/dot-bootstrap.sh)                                                                        | Resolve login shell                   |
| `sw_vers`        | [`preflight`](../../scripts/dot-bootstrap.sh)                                                                        | macOS version banner                  |
| `osascript`      | Various helpers                                                                                                          | AppleScript bridges                   |
| `pmset`          | macOS power helpers                                                                                                      | Battery / sleep state                 |
| `arch`           | [`modules/000-a-emulation.sh`](../../modules/000-a-emulation.sh), [`modules/001-d-node.sh`](../../modules/001-d-node.sh) | `arch -arm64` / `arch -x86_64` shells |
| `xcrun`, `swift` | [`bin/apple-vm-helper/`](../../bin/apple-vm-helper/)                                                                     | Native Apple VM helper build          |
| `/usr/bin/stat`  | Anywhere using BSD `stat -f` (see user notes)                                                                            | Always BSD on macOS                   |

---

## 🔤 Fonts

[`powerlevel10k`](https://github.com/romkatv/powerlevel10k) requires a [Nerd Font](https://www.nerdfonts.com) in your terminal emulator (iTerm2, kitty, VS Code terminal, Apple Terminal). Recommended:

```bash
brew install --cask font-meslo-lg-nerd-font
```

---

## ☁️ Optional services

- **iCloud Drive** — when `~/Library/Mobile Documents/com~apple~CloudDocs` exists, [`check_cloud`](../../scripts/dot-bootstrap.sh) symlinks it as `~/iCloud` and `dot` uses `$ICLOUD/dot/` for splash images, override Brewfiles, and shared secrets. Disable: leave iCloud off; the bootstrap step will warn and continue with local-only data.
- **GitHub SSH agent** — [`scripts/submodule-sync.sh`](../../scripts/submodule-sync.sh) auto-rewrites SSH submodule URLs to HTTPS when no agent is loaded, but having a key loaded is faster.

---

## 🌐 Platform notes

### Apple Silicon vs Intel vs Linuxbrew

[`modules/000-a-homebrew.sh`](../../modules/000-a-homebrew.sh) selects the prefix from `$OPERATING_SYSTEM` × `$CPU_ARCHITECTURE`:

| OS / arch           | Homebrew prefix              | Notes                                                            |
| ------------------- | ---------------------------- | ---------------------------------------------------------------- |
| macOS arm64         | `/opt/homebrew`              | Default for M-series                                             |
| macOS x86_64 / i386 | `/usr/local`                 | Intel Macs and Rosetta shells                                    |
| Linux               | `/home/linuxbrew/.linuxbrew` | Best-effort; macOS-specific modules guard with capability checks |

The Brewfile is also resolved per-arch by `resolveBrewfilePath` — it looks for `${ICLOUD}/dot/Brewfile.${arch}` before falling back to `data/Brewfile`. Keep arch-specific package overrides in iCloud, the canonical minimal list in the repo.

### Rosetta caveats

[`spawnIntel`](../../modules/000-a-emulation.sh) requires Rosetta 2 (`softwareupdate --install-rosetta --agree-to-license`) plus an x86_64 Homebrew install at `/usr/local`. Without both, it errors at exec time.

### macOS-only assumptions

`scripts/dot-bootstrap.sh` calls `defaults`, `dscl`, `sw_vers`. On Linux these will fail; the bootstrapper currently treats macOS as the primary target.

### bash version

macOS ships `/bin/bash` 3.2. The bootstrap script was written to work on 3.2, but [`vendor/bash-commons`](../../vendor/bash-commons) requires bash ≥ 4. Install GNU bash via `brew install bash` and either `chsh` to it for scripts that need it or invoke directly.

---

## 🛠️ Auditing your system

```bash
./scripts/dot-deps-report.sh             # full tier audit
./scripts/dot-deps-report.sh --tier 0    # essentials only
./scripts/dot-deps-report.sh -q          # missing items only
./scripts/dot-deps-report.sh --json | jq # machine-readable
```

Exit code is non-zero **only** when a Tier 0 required tool is missing — safe to gate CI on.

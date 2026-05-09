# ⚫️ dot

![dot](./data/images/black-sun.jpg)

> _A shell deserves a better fate than dad jokes._

[![macOS](https://img.shields.io/badge/macOS-12%2B-black?logo=apple)](https://www.apple.com/macos/)
[![ZSH](https://img.shields.io/badge/zsh-5.8%2B-89e051?logo=gnu-bash&logoColor=white)](https://www.zsh.org)
[![Vendor-first](https://img.shields.io/badge/vendoring-submodules-orange?logo=git)](./vendor/README.md)
[![YAML config](https://img.shields.io/badge/config-YAML-cb171e?logo=yaml&logoColor=white)](./data/zsh.yaml)

---

## 🌑 About

**`dot`** is a ZSH configuration automation framework that turns a bare shell into a productivity powerhouse in seconds. It provides an opinionated, modular, and extensible shell environment with sensible defaults, curated tooling, and a clean structure that scales from personal use to team adoption.

**`dot`** is **not** another shell framework — it is _configuration layered_ on top of proven open-source frameworks. It vendors them as git submodules, wires them together, adds quality-of-life helpers, and gets out of your way.

> See the [FAQ](./docs/FAQ.md) for the _why_.

---

## 🎯 Goals

- 🚀 **Zero friction onboarding** — a single `dot-bootstrap.sh` run sets up everything from scratch
- 🔋 **Batteries included** — the tools you actually reach for are already there
- 🧩 **Composable** — enable or disable individual modules with one env var
- ♻️ **Reproducible** — same setup on any supported machine, every time
- 🪞 **Transparent** — every module is plain shell you can read, fork, or delete
- 🔒 **Vendored** — every third-party dependency is a pinned submodule under [`vendor/`](./vendor/README.md)

---

## ✨ Features

| 🪶   | Feature               | Description                                                                                                                      |
| --- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 🔋   | Batteries Included    | `fzf`, `bat`, `thefuck`, `tmux`, `zsh-autosuggestions`, `navi`, `zsh_codex` wired up out of the box                              |
| 🎨   | Sleek Prompt          | `powerlevel10k` with a pre-baked configuration — no wizard, no waiting                                                           |
| 🧩   | Modular Library       | 30+`modules/` files loaded in lex order; disable any with a `DOT_DISABLE_*` flag                                                 |
| 🗂   | YAML-first Config     | [`data/zsh.yaml`](./data/zsh.yaml) is the single source of truth, parsed with `yq`                                               |
| 🔐   | Secrets Management    | Load**and mask** secrets from JSON without leaking them in history or output                                                     |
| 🛠   | Language Environments | Python (`uv`), Node.js (`fnm`/`n`), Rust (`rustup`), Java (`jenv`) all from one place                                            |
| 🌱   | Vendor-first          | Submodules pin every upstream — no surprises when a project moves or breaks                                                      |
| 🔄   | Submodule Sync        | [`scripts/submodule-sync.sh`](./scripts/submodule-sync.sh) inits/updates root + nested submodules in parallel                    |
| 🛡   | SBOM + OSV Scanner    | [`data/sbom/`](./data/sbom/) — VS Code extension that generates CycloneDX/SPDX SBOMs and scans them via OSV.dev                  |
| 🤖   | Automation Profile    | [`config/automation/.zshrc`](./config/automation/.zshrc) — minimal headless ZSH for Copilot/CI (no p10k, no plugins, no banners) |
| 🖥   | VM Control            | [`bin/ivm.py`](./bin/ivm.py) — unified VM lifecycle for UTM, QEMU, Podman, and Apple Virtualization.framework                    |
| 🍎   | Apple VM Helper       | [`bin/applevm-helper`](./bin/apple-vm-helper/README.md) — native Swift binary using `Virtualization.framework`                   |
| 🥷   | Dry-run Mode          | `DOT_DRY_RUN=1` (or `-n`) on bootstrap — preview every action before it touches your machine                                     |

---

## 📋 Requirements

| Tool       | Version      | Purpose                                           |
| ---------- | ------------ | ------------------------------------------------- |
| 🍎 macOS    | 12 Monterey+ | Primary platform                                  |
| 🐚 ZSH      | 5.8+         | Required shell                                    |
| 🌳 Git      | 2.x+         | Submodule support                                 |
| 🍺 Homebrew | latest       | Package manager (auto-installed)                  |
| 🔧`yq`      | 4.x          | YAML parsing for `data/zsh.yaml` (auto-installed) |
| 🦅`gh`      | 2.x          | GitHub CLI for plugin install (auto-installed)    |

> 🐧 Linux is _partially_ supported. ❌ Windows is **not** supported.

---

## 🚀 Installation

```bash
# 1. Clone to ~/.dot (with submodules)
git clone --recurse-submodules https://github.com/apsamuel/dot.git ~/.dot

# 2. (Optional) Preview every bootstrap action without changing your system
cd ~/.dot && DOT_DRY_RUN=1 source ./bin/dot-bootstrap.sh

# 3. Run bootstrap for real (installs dependencies, symlinks configs)
cd ~/.dot && source ./bin/dot-bootstrap.sh

# 4. Make ZSH your default shell if it isn't
chsh -s "$(which zsh)"

# 5. Reload your shell
exec zsh
```

> Already cloned without `--recurse-submodules`? Run [`scripts/submodule-sync.sh init`](./scripts/README.md) to fetch every submodule (root and nested) in parallel.

See [BOOTSTRAP.md](./docs/details/BOOTSTRAP.md) for a step-by-step walkthrough of what bootstrap does.

---

## 🗺️ Directory Structure

```
.dot/
├── zshrc                  # 🐚 Main ZSH entry point — symlinked to ~/.zshrc
├── modules/               # 🧩 ZSH modules: all loaded at shell startup
│   └── static/            #     Foundational helpers sourced before numbered modules
├── bin/                   # 🛠  Scripts on $PATH (dot-bootstrap, ivm, ictl, applevm-helper, …)
│   └── apple-vm-helper/   #     Swift sources for the native Apple VM helper binary
├── config/                # ⚙️  Runtime configuration
│   ├── shell/             #     p10k preset
│   ├── langs/             #     Python requirements seed
│   └── automation/        # 🤖  Minimal headless ZSH profile for Copilot / CI
├── data/                  # 📦 Data assets
│   ├── zsh.yaml           # 🗂  Source of truth (plugins, theme, options, language deps)
│   ├── Brewfile           # 🍺 Homebrew bundle
│   ├── quotes.yaml        # 💭 Splash quotes
│   ├── images/            # 🖼  Branding (black-sun)
│   ├── configs/           #     Terminal + shell config snapshots
│   └── sbom/              # 🛡  VS Code SBOM + OSV scanner extension
├── vendor/                # 🌱 Vendored submodules (oh-my-zsh, oh-my-tmux, fzf-git, …)
├── scripts/               # 🔄 Submodule sync + repo automation
├── modules/               # 🧠 (covered above)
├── test/                  # 🧪 Smoke tests for toolchains and shell behaviour
└── docs/                  # 📚 Documentation tree
```

> The `turtle/` path is **scheduled for excision** and is not part of `dot`'s supported surface.

---

## 🧰 `dot.shell` Command

After loading, the `dot.shell` command is available in your shell:

```text
dot.shell [command]

Commands:
  version       Print branch, revision, date, and author
  update        Pull the latest changes from the remote
  reload          Re-source all modules
  changelog       Print the git changelog
  printenv        Print dot-related environment variables
  refresh-modules Re-source all modules manually
```

---

## 🎚️ Customization

`dot` is controlled through environment variables. Set any of these before sourcing `~/.zshrc` to change behaviour:

| 🔧 Variable               | Default | Effect                                                            |
| ------------------------ | ------- | ----------------------------------------------------------------- |
| `DOT_DEBUG`              | `0`     | Print each module as it loads                                     |
| `DOT_DRY_RUN`            | `0`     | Bootstrap prints actions without executing them                   |
| `DOT_DEPS`               | `0`     | Force re-installation of bootstrap dependencies (brew, gh, yq, …) |
| `DOT_INSTALL_LANG_DEPS`  | `0`     | Install language deps (pip, npm, cargo) listed in `data/zsh.yaml` |
| `DOT_NVM_INSTALL_LTS`    | `0`     | Install Node.js LTS during bootstrap                              |
| `DOT_DISABLE_BREW`       | `0`     | Skip Homebrew setup                                               |
| `DOT_DISABLE_EXTENSIONS` | `0`     | Skip iTerm2 / thefuck / autosuggestions / syntax highlighting     |
| `DOT_DISABLE_GIT`        | `0`     | Skip git module                                                   |
| `DOT_DISABLE_NODE`       | `0`     | Skip Node.js environment setup                                    |
| `DOT_DISABLE_MAC`        | `0`     | Skip macOS-specific helpers                                       |
| `DOT_DISABLE_OUTPUTS`    | `0`     | Skip splash, quotes, ascii art                                    |
| `DOT_DISABLE_P10K`       | `0`     | Skip Powerlevel10k prompt                                         |

> Full reference: [`docs/details/DOT_VARS.md`](./docs/details/DOT_VARS.md)

---

## 🌱 Open Source — Vendored as Submodules

Every third-party dependency below is pinned as a git submodule under [`vendor/`](./vendor/README.md). This guarantees reproducible installs even when upstream repos move, rename, or break.

| 🧩 Project                                                                | Purpose                                                    | Location                                                |
| ------------------------------------------------------------------------ | ---------------------------------------------------------- | ------------------------------------------------------- |
| 🐚[oh-my-zsh](https://ohmyz.sh)                                           | ZSH plugin & theme framework                               | `vendor/oh-my-zsh/`                                     |
| 🪟[oh-my-tmux](https://github.com/gpakosz/.tmux)                          | Tmux config framework (TPM at `$TMUX_PLUGIN_MANAGER_PATH`) | `vendor/oh-my-tmux/`                                    |
| 🔍[fzf-git](https://github.com/junegunn/fzf-git.sh)                       | fzf bindings for git ops                                   | `vendor/fzf-git/`                                       |
| 🛠[bash-commons](https://github.com/gruntwork-io/bash-commons)            | Reusable bash helpers                                      | `vendor/bash-commons/`                                  |
| 🔠[figlet-fonts](https://github.com/xero/figlet-fonts)                    | Figlet fonts for `toFiglet`                                | `vendor/figlet-fonts/`                                  |
| ⚡[powerlevel10k](https://github.com/romkatv/powerlevel10k)               | ZSH prompt theme                                           | `vendor/oh-my-zsh/custom/themes/powerlevel10k/`         |
| 💡[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style suggestions                                     | `vendor/oh-my-zsh/custom/plugins/zsh-autosuggestions/`  |
| ⌨️[fzf-tab](https://github.com/Aloxaf/fzf-tab)                            | Replace ZSH completion menu with fzf                       | `vendor/oh-my-zsh/custom/plugins/fzf-tab/`              |
| ✏️[zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode)                | Enhanced vi mode                                           | `vendor/oh-my-zsh/custom/plugins/zsh-vi-mode/`          |
| 🌈[F-Sy-H](https://github.com/z-shell/F-Sy-H)                             | Feature-rich syntax highlighting                           | `vendor/oh-my-zsh/custom/plugins/F-Sy-H/`               |
| 🤖[zsh_codex](https://github.com/tom-doerr/zsh_codex)                     | LLM-powered shell completion                               | `vendor/oh-my-zsh/custom/plugins/zsh_codex/`            |
| 🧭[navi](https://github.com/denisidoro/navi)                              | Interactive cheatsheet                                     | `vendor/oh-my-zsh/custom/plugins/navi/`                 |
| 🐍[conda-zsh-completion](https://github.com/esc/conda-zsh-completion)     | Conda completion                                           | `vendor/oh-my-zsh/custom/plugins/conda-zsh-completion/` |

Each plugin entry in [`data/zsh.yaml`](./data/zsh.yaml) carries an `enabled` flag that controls **selective initialisation** at shell start, _without_ deinit'ing the submodule on disk.

> Initialise / update them all in parallel:
>
> ```bash
> ./scripts/submodule-sync.sh init     # first-time fetch
> ./scripts/submodule-sync.sh update   # pull latest tracked branches
> ./scripts/submodule-sync.sh status   # show clean/dirty/missing
> ```

Also reached via Homebrew: 🍺 [`fzf`](https://github.com/junegunn/fzf), 🐈 [`bat`](https://github.com/sharkdp/bat), 💢 [`thefuck`](https://github.com/nvbn/thefuck).

---

## 🤝 Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on adding modules, reporting issues, and submitting pull requests.

---

## 📚 Further Reading

| 📄 Document                                 | Description                           |
| ------------------------------------------ | ------------------------------------- |
| [FAQ](./docs/FAQ.md)                       | Common questions answered             |
| [BOOTSTRAP](./docs/details/BOOTSTRAP.md)   | Full bootstrap walkthrough            |
| [FRAMEWORKS](./docs/details/FRAMEWORKS.md) | Frameworks used and why               |
| [SECRETS](./docs/details/SECRETS.md)       | Loading & masking secrets             |
| [DOT_VARS](./docs/details/DOT_VARS.md)     | Every `DOT_*` env var, audited        |
| [modules/README](./modules/README.md)      | ZSH modules reference                 |
| [bin/README](./bin/README.md)              | Scripts available on `$PATH`          |
| [vendor/README](./vendor/README.md)        | Vendored submodules                   |
| [scripts/README](./scripts/README.md)      | Submodule sync & repo automation      |
| [data/README](./data/README.md)            | Data assets, Brewfile, SBOM extension |
| [config/README](./config/README.md)        | Runtime configuration & deploys       |

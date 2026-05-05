# Dot

![dot](./data/images/black-sun.jpg)

> Because a shell deserves better than dad jokes, plain defaults and endless plugins.

## About

**`dot`** is a ZSH configuration automation framework that turns a bare shell into a productivity powerhouse in seconds. It provides an opinionated, modular, and extensible shell environment with sensible defaults, curated tooling, and a clean structure that scales from personal use to team adoption.

**`dot`** is not another shell framework — it is configuration layered on top of proven open-source frameworks. It wires them together, adds missing quality-of-life features, and gets out of your way. See [FAQ](./docs/FAQ.md) for more.

---

## Goals

- **Zero friction onboarding** — a single `bootstrap.sh` run sets up everything from scratch
- **Batteries included** — the tools you actually reach for are already there
- **Composable** — enable or disable individual modules without breaking the rest
- **Reproducible** — the same setup on any supported machine, every time
- **Transparent** — every module is a plain shell file you can read, fork, or delete

---

## Features

| Feature                  | Description                                                                              |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| 🔋 Batteries Included    | `fzf`, `bat`, `thefuck`, `tmux`, `zsh-autosuggestions` wired up out of the box |
| 🎨 Sleek Prompt          | `powerlevel10k` with pre-baked configuration                                           |
| ⚙️ Modular Library     | `zlib/` modules loaded in numbered order; disable any with an env var                  |
| 🔐 Secrets Management    | Load and mask secrets from JSON without leaking them in history                          |
| 🐢 Turtle Shell          | Experimental Rust-powered shell interpreter built alongside this framework               |
| 🛠 Language Environments | Python (`uv`), Node.js, Rust (`rustup`), Java (`jenv`) all managed from one place  |
| 🌐 Vendor-first          | Key dependencies are vendored so installs don't break when upstreams move                |

---

## Requirements

| Requirement  | Version                                 |
| ------------ | --------------------------------------- |
| macOS        | 12 Monterey or later (primary platform) |
| ZSH          | 5.8 or higher                           |
| Git          | 2.x                                     |
| Homebrew     | Latest                                  |
| Rust / Cargo | For building [Turtle](./turtle/README.md) |

Linux is *partially* supported. **Windows is NOT**.

---

## Installation

```bash
# 1. Clone to ~/.dot
git clone https://github.com/apsamuel/dot.git ~/.dot

# 2. Run bootstrap (installs dependencies, symlinks configs)
pushd ~/.dot && source ./bin/dot-bootstrap.sh

# 3. Set ZSH as your default shell if it isn't already
chsh -s $(which zsh)

# 4. Reload your shell
exec zsh
```

See [BOOTSTRAP.md](./docs/details/BOOTSTRAP.md) for a detailed walkthrough of what bootstrap does.

---

## Directory Structure

```
.dot/
├── zshrc                  # Main ZSH entry point — symlinked to ~/.zshrc
├── zlib/                  # ZSH library: all modules loaded at shell startup
│   └── static/            # Static helpers sourced before zlib modules
├── bin/                   # Scripts added to $PATH
├── config/                # Configuration files (data.json / data.yaml)
├── data/                  # Static data: quotes, images
├── vendor/                # Vendored third-party libraries
├── scripts/               # Utility and automation scripts
├── turtle/                # Turtle: Rust-based experimental shell interpreter
├── test/                  # Test suite for shell modules and language targets
└── docs/                  # Documentation
```

Full directory details are covered in [BOOTSTRAP.md](./docs/details/BOOTSTRAP.md).

---

## Customization

`dot` is controlled through environment variables. Set any of these before or inside `~/.zshrc` to change behaviour:

| Variable                            | Default | Effect                                  |
| ----------------------------------- | ------- | --------------------------------------- |
| `DOT_DEBUG`                       | `0`   | Print each module as it loads           |
| `DOT_DISABLE_BREW`                | `0`   | Skip Homebrew setup                     |
| `DOT_DISABLE_EXTENSIONS`          | `0`   | Skip iTerm2 / thefuck / autosuggestions |
| `DOT_DISABLE_GIT`                 | `0`   | Skip git module                         |
| `DOT_DISABLE_NODE`                | `0`   | Skip Node.js environment setup          |
| `DOT_DISABLE_MAC`                 | `0`   | Skip macOS-specific helpers             |
| `DOT_DISABLE_THEFUCK`             | `0`   | Skip thefuck command corrector          |
| `DOT_DISABLE_ZSH_AUTOSUGGESTIONS` | `0`   | Skip zsh-autosuggestions                |
| `DOT_ANACONDA_ENABLED`            | `0`   | Enable Anaconda instead of uv venvs     |

Per-module configuration lives in the module file itself (e.g. `zlib/000-c-git.sh` for git defaults).

---

## `dot.shell` Command

After loading, the `dot.shell` command is available in your shell:

```
dot.shell [command]

Commands:
  version       Print branch, revision, date, and author
  update        Pull the latest changes from the remote
  reload        Re-source all zlib modules
  changelog     Print the git changelog
  printenv      Print dot-related environment variables
  source-zlib   Source all zlib modules manually
```

---

## Open Source Utilities

`dot` vendors or integrates the following open-source projects:

| Utility                                                              | Purpose                                      | Location                 |
| -------------------------------------------------------------------- | -------------------------------------------- | ------------------------ |
| [oh-my-zsh](https://ohmyz.sh)                                           | ZSH plugin and theme framework               | `vendor/ohmyzsh/`      |
| [oh-my-tmux](https://github.com/gpakosz/.tmux)                          | Tmux configuration framework                 | `vendor/tmux/`         |
| [fzf](https://github.com/junegunn/fzf)                                  | Fuzzy finder for the terminal                | installed via Homebrew   |
| [fzf-git](https://github.com/junegunn/fzf-git.sh)                       | fzf bindings for git operations              | `vendor/fzf-git/`      |
| [bash-commons](https://github.com/gruntwork-io/bash-commons)            | Reusable bash utilities                      | `vendor/bash-commons/` |
| [powerlevel10k](https://github.com/romkatv/powerlevel10k)               | ZSH prompt theme                             | installed via oh-my-zsh  |
| [bat](https://github.com/sharkdp/bat)                                   | `cat` replacement with syntax highlighting | installed via Homebrew   |
| [thefuck](https://github.com/nvbn/thefuck)                              | Autocorrects mistyped commands               | installed via Homebrew   |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-style command suggestions               | installed via oh-my-zsh  |

---

## Turtle

[Turtle](./turtle/README.md) is an experimental shell interpreter written in Rust, developed alongside `dot`. It is not required to use `dot` but lives in the same repository.

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to add modules, report issues, and submit pull requests.

---

## Further Reading

| Document                                   | Description                    |
| ------------------------------------------ | ------------------------------ |
| [FAQ.md](./docs/FAQ.md)                       | Common questions answered      |
| [BOOTSTRAP.md](./docs/details/BOOTSTRAP.md)   | Full bootstrap walkthrough     |
| [FRAMEWORKS.md](./docs/details/FRAMEWORKS.md) | Frameworks used and why        |
| [SECRETS.md](./docs/details/SECRETS.md)       | How secrets management works   |
| [zlib/README.md](./zlib/README.md)            | ZSH library module reference   |
| [bin/README.md](./bin/README.md)              | Scripts available on `$PATH` |

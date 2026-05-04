# FAQ

## General

> **Is this another shell framework?**

No. `dot` is configuration layered on top of existing, well-maintained frameworks — it does not reinvent the wheel. It wires together [oh-my-zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [oh-my-tmux](https://github.com/gpakosz/.tmux), and other utilities with sensible defaults so you don't have to. See [FRAMEWORKS.md](./details/FRAMEWORKS.md) for the full list.

> **What about [🐢 Turtle](../turtle/README.md)?**

Turtle is a separate project — an experimental shell interpreter written in Rust — that lives inside this repository. It is optional and independent of the ZSH configuration. You can use `dot` without ever touching Turtle.

---

## Installation

> **What does `bootstrap.sh` actually do?**

It installs dependencies (via Homebrew), symlinks `zshrc` to `~/.zshrc`, sets up the vendor libraries, and ensures your shell is configured to load `dot`. See [BOOTSTRAP.md](./details/BOOTSTRAP.md) for a step-by-step breakdown.

> **Do I need Homebrew?**

On macOS, yes — Homebrew is the primary package manager used by `dot`. You can disable it with `DOT_DISABLE_BREW=1` if you manage packages yourself, but several modules assume Homebrew-installed paths.

> **Can I use this on Linux?**

Partially. The core ZSH modules work on any system with ZSH 5.8+. macOS-specific modules (iTerm2 integration, `sysctl`-based CPU detection, etc.) are guarded by capability checks and should be silently skipped on Linux. Homebrew on Linux (`linuxbrew`) is supported but not tested regularly.

---

## Usage

> **How do I disable a module I don't want?**

Set the relevant `DOT_DISABLE_*` environment variable to `1` before your shell sources `zshrc`:

```bash
export DOT_DISABLE_THEFUCK=1
export DOT_DISABLE_NODE=1
```

All disable flags are listed in the [README](../README.md#customization).

> **How do I enable debug output to see what loads?**

```bash
DOT_DEBUG=1 zsh
```

Each module prints its name as it loads.

> **How do I add my own module?**

Drop a `.sh` file in `zlib/` following the naming convention `NNN-x-name.sh` where `NNN` is the load order (e.g. `050`), `x` is a letter for sub-ordering, and `name` is a descriptive identifier. It will be sourced automatically on the next shell start. See [zlib/README.md](../zlib/README.md) for details.

> **Where should I put secrets and tokens?**

Never commit secrets. Use the secrets management system: store them in a JSON file outside the repo and reference them via the `loadSecrets` / `maskSecrets` functions in `zlib/000-a-secrets.sh`. See [SECRETS.md](./details/SECRETS.md).

---

## Troubleshooting

> **My shell is slow to start — what do I do?**

Enable debug mode (`DOT_DEBUG=1 zsh`) to see which modules are loading and how long the startup takes. Common culprits are heavy completions, slow `brew` calls, or Python venv activation. Disable unused language modules with the `DOT_DISABLE_*` flags.

> **`dot.shell` command not found**

Your shell didn't source the `dot` library. Make sure `~/.zshrc` is symlinked to `~/.dot/zshrc`. You can re-run bootstrap or check with:

```bash
ls -la ~/.zshrc
```

> **Powerlevel10k shows garbled characters**

Install a [Nerd Font](https://www.nerdfonts.com) and configure your terminal emulator to use it. iTerm2 users can set this under Preferences → Profiles → Text → Font.

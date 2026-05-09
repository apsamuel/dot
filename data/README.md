# 📦 data/

> Static assets and runtime data for the `dot` framework.
> Anything that isn't code lives here: YAML config, Brewfile, SBOMs, branding, and pre-baked terminal/shell snapshots.

---

## 🗂️ Layout

| Path                                          | Purpose                                                                                                                                                |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 🧾 [`zsh.yaml`](./zsh.yaml)                   | **Source of truth** for the ZSH environment — theme, plugins (with `enabled` flags), splash screen settings, language deps. Parsed at runtime by `yq`. |
| 🪞 [`zsh.json`](./zsh.json)                   | Legacy JSON mirror of `zsh.yaml` (kept for backward compatibility — _YAML wins_).                                                                      |
| 🍺 [`Brewfile`](./Brewfile)                   | Homebrew bundle consumed by `bin/dot-bootstrap.sh` (and resolvable from iCloud).                                                                       |
| 💭 [`quotes.yaml`](./quotes.yaml)             | Splash-screen quotes (rendered by `termQuote`).                                                                                                        |
| 🪞 `quotes.json`                              | Legacy JSON mirror of `quotes.yaml`.                                                                                                                   |
| 🖼 [`images/`](./images/)                     | Branding assets (`black-sun.jpg`, etc.) used in docs.                                                                                                  |
| 🛡 [`sbom/`](./sbom/)                         | VS Code extension — generates CycloneDX/SPDX SBOMs and scans them for vulnerabilities via OSV.dev. See [`sbom/README.md`](./sbom/README.md).           |
| 🖥 [`configs/terminal/`](./configs/terminal/) | Pre-baked terminal emulator profiles (iTerm2 dynamic profiles, color schemes).                                                                         |
| 🐚 [`configs/shell/`](./configs/shell/)       | Snapshot of shell-level config drops (referenced by the deploy scripts).                                                                               |

---

## 🧾 `zsh.yaml` — the heart

`zsh.yaml` defines the shape of every interactive `dot` shell. It is parsed by `yq` (a hard bootstrap dependency) and consulted by:

- 🐚 `zshrc` → reads `.theme` to set `$ZSH_THEME`
- 🚀 `bin/dot-bootstrap.sh` → reads `.zsh.plugins.builtin` & `.zsh.plugins.custom` to enable / disable oh-my-zsh modules
- 🐍 `bin/dot-bootstrap.sh` → reads `.languages.python.packages` (when `DOT_INSTALL_LANG_DEPS=1`) to seed the base venv
- 🪟 `bin/dot-bootstrap.sh` → reads `.tmux.*` to wire up oh-my-tmux + TPM

Top-level keys:

```yaml
theme: powerlevel10k
zsh:
  plugins:
    builtin: [git, fzf, ssh-agent, …] # ships with oh-my-zsh
    custom: # vendored under vendor/oh-my-zsh/custom
      - { name: powerlevel10k, enabled: true, type: theme }
      - { name: zsh-autosuggestions, enabled: true, type: plugin }
      - { name: zsh_codex, enabled: false, type: plugin }
tmux:
  plugins:
    - tmux-plugins/tpm
    - tmux-plugins/tmux-sensible
languages:
  python:
    packages: [uv, pipx, ruff, …]
```

> Each `enabled` flag controls _runtime activation_ — you can disable a plugin without removing the submodule from disk.

---

## 🚚 Deployment

Two scripts under `bin/` ship local data into the iCloud-backed live config tree (so multiple machines stay in sync):

| Script                                                       | Effect                                              |
| ------------------------------------------------------------ | --------------------------------------------------- |
| 🌥 [`bin/dot-deploy-config.sh`](../bin/dot-deploy-config.sh) | `cp data/zsh.yaml → $ICLOUD/dot/shell/zsh/zsh.yaml` |
| 🌥 [`bin/dot-deploy-rc.sh`](../bin/dot-deploy-rc.sh)         | `cp zshrc → $ICLOUD/dot/shell/zsh/rc`               |

---

## 🛡️ SBOM Subproject

[`data/sbom/`](./sbom/) is a self-contained TypeScript VS Code extension. It uses [Syft](https://github.com/anchore/syft) to generate **CycloneDX** and **SPDX** SBOMs and scans them against [OSV.dev](https://osv.dev/) for known CVEs. See its [own README](./sbom/README.md) for build & install instructions.

---

## 🖼️ Images

Branding lives in [`images/`](./images/) — `black-sun.jpg` is the canonical logo (`⚫️`).

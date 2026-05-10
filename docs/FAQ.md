# ❓ FAQ

## 🌑 General

> **Is this another shell framework?**

Nope. `dot` is **configuration** layered on top of well-maintained, _vendored_ frameworks. It does not reinvent the wheel — it pins [oh-my-zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [oh-my-tmux](https://github.com/gpakosz/.tmux), and friends as **git submodules** under [`vendor/`](../vendor/README.md) and wires them together with sensible defaults. See [FRAMEWORKS.md](./details/FRAMEWORKS.md) for the full list.

> **Why vendor everything as submodules?**

🛡️ Reproducibility. Upstream projects rename, move, archive, and break. By pinning a SHA, every machine that runs `dot` gets the _exact_ same plugin set. Updates are explicit, opt-in actions through [`scripts/submodule-sync.sh`](../scripts/README.md).

> **What's the YAML file for?**

[`data/zsh.yaml`](../data/zsh.yaml) is the runtime source of truth — theme, plugin list (with per-plugin `enabled` flags), tmux config, language packages. It's parsed by `yq` (which `dot-bootstrap.sh` installs for you).

---

## 🚀 Installation

> **What does `dot-bootstrap.sh` actually do?**

Installs dependencies via Homebrew (incl. `yq`, `gh`), initialises every submodule under `vendor/`, symlinks `zshrc` → `~/.zshrc`, builds the Apple VM helper if Xcode is present, and (optionally) installs language deps from `data/zsh.yaml`. Walk-through: [BOOTSTRAP.md](./details/BOOTSTRAP.md).

> **Can I preview what bootstrap will do without changing anything?**

Yes — that's exactly what `DOT_DRY_RUN` is for:

```bash
DOT_DRY_RUN=1 source ./scripts/dot-bootstrap.sh
# or
./scripts/dot-bootstrap.sh -n
```

Every action is printed instead of executed.

> **I forgot `--recurse-submodules` when cloning. Now what?**

Run [`scripts/submodule-sync.sh init`](../scripts/README.md). It fetches every root submodule **and** every nested submodule under `vendor/oh-my-zsh/custom/` in parallel.

> **How do I keep the vendored projects up to date?**

```bash
./scripts/submodule-sync.sh update     # pull latest tracked branches
./scripts/submodule-sync.sh status     # see what changed
```

> **Do I need Homebrew?**

On macOS, yes. Disable it with `DOT_DISABLE_BREW=1` if you manage packages yourself, but several modules assume Homebrew paths.

> **What system dependencies does `dot` actually expect?**

The full tier-by-tier reference lives in [`docs/details/DEPENDENCIES.md`](./details/DEPENDENCIES.md). To audit your machine right now: `./scripts/dot-deps-report.sh`.

> **Can I use this on Linux?**

Partially. Core ZSH modules work on any ZSH 5.8+. macOS-specific modules are guarded by capability checks. `linuxbrew` is supported but not regularly tested.

---

## 🤖 Automation / CI / Copilot

> **My agent / runner spawns interactive shells and chokes on splash output. Help.**

Use the headless profile:

```bash
ZDOTDIR="$HOME/.dot/config/automation" zsh
```

It disables `p10k`, splashes, plugin loading, and the language envs. See [`config/automation/README.md`](../config/automation/README.md).

---

## 🛡️ SBOM & CVEs

> **What's in `data/sbom/`?**

A self-contained VS Code extension that wraps [Syft](https://github.com/anchore/syft) (SBOM generation) and [OSV.dev](https://osv.dev/) (vulnerability scanning). Generates **CycloneDX** _or_ **SPDX** SBOMs and reports CVEs against them. See [`data/sbom/README.md`](../data/sbom/README.md).

---

## 🍎 Apple VM Helper

> **What does `vmctl backends` show for Apple?**

If Apple is `no`, neither the native `applevm-helper` nor the `vz` CLI is on `$PATH`. Either:

- 🥇 **Native (recommended):** build [`bin/apple-vm-helper`](../bin/apple-vm-helper/README.md) (requires Xcode).
- 🥈 **Fallback:** `brew install Code-Hex/tap/vz`.

> **Force the native helper:**

```bash
IVM_APPLE_PROVIDER=swift-native python3 ~/.dot/bin/ivm.py <command>
```

> **Why are `suspend` / `resume` not available with vz?**

The vz CLI doesn't expose pause/resume. Only the native helper does.

---

## 🎚️ Usage

> **How do I disable a module?**

```bash
export DOT_DISABLE_THEFUCK=1
export DOT_DISABLE_NODE=1
```

Full list: [`docs/details/DOT_VARS.md`](./details/DOT_VARS.md).

> **How do I disable a plugin without removing the submodule?**

Flip its `enabled: true|false` in [`data/zsh.yaml`](../data/zsh.yaml). The submodule stays on disk; only its activation at shell start changes.

> **Debug output?**

```bash
DOT_DEBUG=1 zsh
```

> **Where do secrets go?**

Never in the repo. Use [`modules/000-a-secrets.sh`](../modules/000-a-secrets.sh) + the helpers in [`bin/zsh-mask-secret.sh`](../bin/zsh-mask-secret.sh). See [SECRETS.md](./details/SECRETS.md).

---

## 🧪 Troubleshooting

> **Slow shell start?**

`DOT_DEBUG=1 zsh` to see what's loading. Disable unused language modules.

> **`dot.shell` command not found?**

`ls -la ~/.zshrc` — should symlink to `~/.dot/zshrc`. Re-run bootstrap if not.

> **Powerlevel10k shows garbled glyphs?**

Install a [Nerd Font](https://www.nerdfonts.com) and configure your terminal to use it.

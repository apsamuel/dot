# ⚫️ config/

> Repo-side configuration templates. The **runtime** source-of-truth lives at [`data/zsh.yaml`](../data/zsh.yaml) and (when deployed) at `$ICLOUD/dot/shell/zsh/zsh.yaml`.

---

## 🧭 How Config Flows

```text
data/zsh.yaml  ──►  bin/dot-deploy-config.sh  ──►  $ICLOUD/dot/shell/zsh/zsh.yaml
       │                                                       │
       └────────────► parsed by `yq` at shell start ◄───────────┘
                          • zshrc      → .theme  → $ZSH_THEME
                          • bootstrap  → .zsh.plugins.{builtin,custom}
                          • bootstrap  → .languages.python.packages
                          • bootstrap  → .tmux.plugins
```

> 🪦 **Legacy:** earlier versions of `dot` read `config/data.json` (and its `data.yaml` mirror) via `jq`. Both files are retained as a reference, but **runtime now consumes `data/zsh.yaml`** through `yq`. New options and plugins should be added to `data/zsh.yaml`.

---

## 🗂️ Files in `config/`

| 📄 File                                                 | Purpose                                                                                           |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| 🐍 [`langs/requirements.txt`](./langs/requirements.txt) | Python packages installed into the base `uv` venv when `DOT_INSTALL_LANG_DEPS=1`                  |
| 🎨 [`shell/p10k.zsh`](./shell/p10k.zsh)                 | Pre-baked Powerlevel10k prompt configuration                                                      |
| 🤖 [`automation/`](./automation/)                       | Headless ZSH profile for Copilot / CI runners — see its [README](./automation/README.md)          |
| 🧾 [`data.json`](./data.json)                           | **Legacy** runtime config (JSON). Kept for back-compat; not consumed by current `modules/` files. |
| 🧾 [`data.yaml`](./data.yaml)                           | **Legacy** YAML mirror of `data.json`.                                                            |

---

## 🚚 Deploy

| Script                                                      | Action                                                                        |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------- |
| 🌥 [`bin/dot-deploy-config.sh`](../bin/dot-deploy-config.sh) | Pushes [`data/zsh.yaml`](../data/zsh.yaml) → `$ICLOUD/dot/shell/zsh/zsh.yaml` |
| 🌥 [`bin/dot-deploy-rc.sh`](../bin/dot-deploy-rc.sh)         | Pushes the repo's [`zshrc`](../zshrc) → `$ICLOUD/dot/shell/zsh/rc`            |

Both require `$ICLOUD` (set by `zshrc` from `~/Library/Mobile Documents/com~apple~CloudDocs`).

---

## 🧪 Editing the Active Plugin Set

To enable / disable a plugin **at runtime**, flip its `enabled` flag in `data/zsh.yaml`:

```yaml
zsh:
  plugins:
    custom:
      - { name: zsh_codex, type: plugin, enabled: false } # ← turn off
      - { name: navi, type: plugin, enabled: true } # ← turn on
```

The submodule remains on disk under `vendor/oh-my-zsh/custom/plugins/`; only its activation by `bin/dot-bootstrap.sh` / oh-my-zsh changes.

To **add** a new custom plugin, register it as a submodule under `vendor/oh-my-zsh/custom/{plugins,themes}/<name>` and append a stanza to `zsh.plugins.custom` (or `themes.custom`).

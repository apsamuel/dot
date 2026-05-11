# config/

Repository-side configuration templates and presets.

Runtime shell behavior is driven by `data/zsh.yaml` (repo copy) and optionally by the deployed iCloud copy (`$ICLOUD/dot/shell/zsh/zsh.yaml`).

## What Lives Here

| Path | Purpose |
| --- | --- |
| `shell/p10k.zsh` | Powerlevel10k prompt preset symlinked to `~/.p10k.zsh` by bootstrap. |
| `langs/requirements.txt` | Python package seed list used by language bootstrap flows. |
| `automation/` | Minimal non-interactive shell profile for CI/Copilot automation. |
| `data.json` | Legacy config snapshot retained for compatibility/reference. |
| `data.yaml` | Legacy YAML mirror of `data.json`. |

## Config Flow

```text
repo data/zsh.yaml
   ├── parsed at runtime by zshrc/modules
   └── deployed via scripts/dot-deploy-config.sh
         -> $ICLOUD/dot/shell/zsh/zsh.yaml
```

## Deploy Commands

| Script | Action |
| --- | --- |
| `scripts/dot-deploy-config.sh` | Deploy `data/zsh.yaml` to iCloud runtime path. |
| `scripts/dot-deploy-rc.sh` | Deploy `zshrc` to iCloud runtime path. |

## Notes

- Add new runtime shell options/plugins/themes to `data/zsh.yaml`, not `config/data.json`.
- Keep `config/data.json` and `config/data.yaml` only for legacy compatibility.

# data/

Runtime data and static assets consumed by `dot`.

## Directory Map

| Path | Purpose |
| --- | --- |
| `zsh.yaml` | Canonical shell runtime config (theme, paths, conditions, languages, options, plugins, themes). |
| `zsh.json` | Legacy JSON mirror of shell config values. |
| `Brewfile` | Homebrew formula bundle used by bootstrap. |
| `Brewfile.cask` | Homebrew cask bundle for GUI apps/tools. |
| `quotes.yaml` / `quotes.json` | Quote sources for splash/output helpers. |
| `images/` | Branding and visual assets. |
| `configs/` | Shell/terminal config snapshots and related files. |
| `sbom/` | SBOM + vulnerability scanning extension project. |

## `zsh.yaml` Schema (Current)

`data/zsh.yaml` is parsed directly by runtime modules and bootstrap tooling.

Current top-level keys:

- `theme`
- `path`
- `conditions`
- `languages`
- `options`
- `plugins`
- `themes`

Example shape:

```yaml
theme: powerlevel10k/powerlevel10k
path: []
conditions:
  network:
    home: 192.168.0.1
languages:
  python:
    version: 3.11.13
    pip:
      requirements:
        - libtmux==0.36.0
plugins:
  builtin:
    - git
    - fzf
  custom:
    - owner: zsh-users
      repo: zsh-autosuggestions
      enabled: true
themes:
  custom:
    - owner: romkatv
      repo: powerlevel10k
      enabled: true
```

## Where `zsh.yaml` Is Used

- `zshrc`: reads `.theme` to set `ZSH_THEME`.
- `modules/static/foundation.sh`: `loadZshOptions` reads `.options[]`.
- `scripts/dot-bootstrap.sh`: installs language dependencies from `.languages.*`.

## Deploy Flow

Use scripts in `scripts/` to mirror runtime config to iCloud-backed locations.

| Script | Effect |
| --- | --- |
| `scripts/dot-deploy-config.sh` | Copies `data/zsh.yaml` to `$ICLOUD/dot/shell/zsh/zsh.yaml`. |
| `scripts/dot-deploy-rc.sh` | Copies `zshrc` to `$ICLOUD/dot/shell/zsh/rc`. |

## Notes

- `data/zsh.yaml` is the source-of-truth for shell behavior.
- Legacy JSON/YAML mirrors are kept for compatibility/reference.

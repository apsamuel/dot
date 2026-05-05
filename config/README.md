# ⚫️ Configuration

The `config/` directory holds the **source-of-truth configuration template** that controls shell behaviour, plugin selection, theme, and language tooling. The live copy that runs at shell startup lives in iCloud (`$ICLOUD/dot/data.json`).

---

## How Config Is Used

```
config/data.json  ──►  scripts/deploy-config.sh  ──►  $ICLOUD/dot/data.json
                                                             │
                                         zlib/static/config.sh reads it
                                         zlib/000-a-config.sh reads it (via jq)
```

1. **Edit** `config/data.json` in the repo.
2. **Deploy** it to iCloud by running `scripts/deploy-config.sh` (or `bootstrap.sh -d`).
3. **At shell startup**, `zlib/static/config.sh` sets `$DOT_CONFIGURATION` pointing at the iCloud copy, and `zlib/000-a-config.sh` reads values from it with `jq`.

> `config/data.yaml` is a YAML-format mirror of the same data kept for human readability. It is **not** read at runtime — all runtime reads use `data.json`.

---

## Files

| File | Description |
|------|-------------|
| `data.json` | Primary configuration file — plugins, options, theme, language requirements |
| `data.yaml` | YAML mirror of `data.json` (human reference only, not loaded at runtime) |
| `langs/requirements.txt` | Python packages installed into the base venv by bootstrap |
| `shell/p10k.zsh` | Powerlevel10k prompt configuration template |

---

## `data.json` Field Reference

Below is an example configuration file in JSON format that demonstrates how to set up various options, plugins, themes, and language requirements.

```json
{
    "conditions": {
        "network": {
            "home": "192.168.0.1"
        }
    },
    "languages": {
        "python": {
            "pip": {
                "requirements": [
                    "libtmux==0.36.0"
                ]
            }
        },
        "node": {
            "npm": {
                "requirements": [
                    "@google/gemini-cli",
                    "@openai/codex"
                ]
            }
        }
    },
    "options": [
        "autopushd",
        "BANG_HIST",
        "extendedglob",
        "extendedhistory",
        "hist_ignore_all_dups",
        "histexpiredupsfirst",
        "histfindnodups",
        "histignorealldups",
        "histignoredups",
        "histignorespace",
        "histnostore",
        "histreduceblanks",
        "histsavenodups",
        "histverify",
        "incappendhistory",
        "share_history",
        "sharehistory"
    ],
    "path": [],
    "plugins": {
        "builtin": [
            "alias-finder",
            "autopep8",
            "brew",
            "colored-man-pages",
            "colorize",
            "copybuffer",
            "copypath",
            "dash",
            "direnv",
            "docker-compose",
            "docker",
            "emoji-clock",
            "emoji",
            "fzf",
            "gh",
            "git-extras",
            "git",
            "gitignore",
            "gnu-utils",
            "kubectl",
            "nmap",
            "node",
            "npm",
            "python",
            "ssh-agent",
            "thefuck",
            "vi-mode",
            "web-search"
        ],
        "custom": [
            {
                "exec": "",
                "owner": "conda-incubator",
                "post": "",
                "pre": "",
                "repo": "conda-zsh-completion"
            },
            {
                "exec": "",
                "owner": "zsh-users",
                "post": "",
                "pre": "",
                "repo": "zsh-autosuggestions"
            },
            {
                "exec": "",
                "owner": "z-shell",
                "post": "",
                "pre": "",
                "repo": "F-Sy-H"
            }
        ]
    },
    "theme": "powerlevel10k/powerlevel10k",
    "themes": {
        "builtin": [],
        "custom": [
            {
                "exec": "",
                "owner": "",
                "repo": ""
            }
        ]
    }
}
```

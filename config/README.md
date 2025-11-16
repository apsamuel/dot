# ⚫️ Configuration

The dot configuration framework allows you to easily manage and customize your shell environment. Below is an example configuration file in JSON format that demonstrates how to set up various options, plugins, themes, and language requirements.

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

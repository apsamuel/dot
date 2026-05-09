# 🤖 config/automation/

A **headless ZSH profile** for non-interactive use cases — Copilot Workspace, CI runners, scripted automation, or any context where banners, splash screens, p10k prompts, and plugin chains would only get in the way.

> ⚫️ Same `$DOT_ROOT`, same `$PATH`, **none of the noise**.

---

## 🧭 When to Use

- 🤖 GitHub Copilot / agent task runners
- 🧪 CI / GitHub Actions shells
- 🪛 `ssh user@host -t zsh` automation harnesses
- 🐳 Container builds where `~/.zshrc` is mounted from `dot`
- 📦 Tooling that wants Homebrew + language runtimes but no prompt decoration

For interactive day-to-day use, you want the full [`zshrc`](../../zshrc) and [`modules/`](../../modules/README.md) chain instead.

---

## 🚀 Activation

Set `ZDOTDIR` to this directory before launching `zsh`:

```bash
ZDOTDIR=~/.dot/config/automation zsh -i
# or for an entire automation session
export ZDOTDIR=~/.dot/config/automation
exec zsh
```

ZSH will read [`config/automation/.zshrc`](.zshrc) instead of `~/.zshrc`.

---

## 🔇 What It Disables

| 🔧 Variable                             | Effect                          |
| --------------------------------------- | ------------------------------- |
| `DOT_SPLASH_SCREEN=false`               | No banner                       |
| `DOT_DISABLE_OUTPUTS=1`                 | No decorative `echo` chatter    |
| `DOT_DISABLE_P10K=1`                    | Plain `%~ $` prompt             |
| `DOT_DISABLE_THEFUCK=1`                 | No `thefuck` shell hook         |
| `DOT_DISABLE_ZSH_AUTOSUGGESTIONS=1`     | No autosuggestions buffer       |
| `DOT_DISABLE_ZSH_SYNTAX_HIGHLIGHTING=1` | No F-Sy-H                       |
| `DOT_DISABLE_EXTENSIONS=1`              | Skip the extensions module      |
| `DOT_INTERACTIVE=0`                     | Mark session as non-interactive |

---

## ✅ What It Keeps

- 🍺 Homebrew shellenv (Apple Silicon + Intel paths)
- 🛣 `$DOT_ROOT`, `$DOT_BIN` on `$PATH`
- 🐍 `~/.local/bin`, pyenv, [`uv`](https://github.com/astral-sh/uv)
- 🟢 Node via [`fnm`](https://github.com/Schniz/fnm) (fast-path, no `cd` hook)
- 🦀 Rust / cargo (`~/.cargo/env`)
- 🔑 GPG TTY for signed-commit automation
- 🌐 Locale + `$EDITOR`

---

## 🔗 Related

| Doc                                                          | Purpose                            |
| ------------------------------------------------------------ | ---------------------------------- |
| [`config/README.md`](../README.md)                           | Configuration overview             |
| [`zshrc`](../../zshrc)                                       | Full interactive shell entry point |
| [`docs/details/DOT_VARS.md`](../../docs/details/DOT_VARS.md) | All `DOT_*` variables              |

# Secrets Management

`dot` provides a simple system for loading and masking secrets (API keys, tokens, passwords) so they are available in your shell without being committed to the repository or appearing in shell history.

---

## How It Works

Secrets are stored in a JSON file **outside the repository** (e.g. `~/.secrets.json` or in iCloud). The `dot::secrets::load` function reads the file and exports each key–value pair as an environment variable. The `dot::secrets::mask` function then replaces the values in any shell output so they are never accidentally printed.

### Secret File Format

```json
{
  "GITHUB_TOKEN": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "OPENAI_API_KEY": "sk-xxxxxxxxxxxxxxxxxxxx",
  "MY_WORK_PASSWORD": "hunter2"
}
```

---

## Functions

All functions are defined in `modules/000-a-secrets.sh`.

| Function             | Description                                                                                               |
| -------------------- | --------------------------------------------------------------------------------------------------------- |
| `dot::secrets::load [path]` | Loads a JSON secrets file and exports each key as an environment variable. Defaults to `~/.secrets.json`. |
| `dot::secrets::mask`        | Masks the values of all loaded secrets in subsequent shell output.                                        |
| `__mask_secrets__`   | Internal function called by `dot::secrets::mask`.                                                                |
| `dot::secrets::reload-options`      | Reloads shell options after secrets are masked.                                                           |

---

## Usage

```bash
# Load secrets from the default location (~/.secrets.json)
dot::secrets::load

# Load from a specific path
dot::secrets::load ~/iCloud/secrets/work.json

# Mask secrets in output
dot::secrets::mask

# Your secret is now available
echo $GITHUB_TOKEN   # Output will be masked: ****
```

---

## Best Practices

- **Never commit your secrets file.** Add it to `.gitignore` or store it outside the repo entirely.
- **Use iCloud or a password manager** to sync secrets across machines rather than committing them.
- **Scope secrets** — use separate JSON files for work and personal secrets and load them conditionally.
- **Rotate frequently** — the masking system protects against accidental printing, but it is not a substitute for proper secret rotation.

---

## How `dot::secrets::mask` Works

`dot::secrets::mask` iterates over all known secret variable names loaded by `dot::secrets::load` and registers a ZSH preexec hook that replaces their values with `****` in command output. This prevents secrets from appearing in `set`, `env`, or accidental `echo $VAR` calls.

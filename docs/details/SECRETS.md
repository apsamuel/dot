# Secrets Management

`dot` provides a simple system for loading and masking secrets (API keys, tokens, passwords) so they are available in your shell without being committed to the repository or appearing in shell history.

---

## How It Works

Secrets are stored in a JSON file **outside the repository** (e.g. `~/.secrets.json` or in iCloud). The `loadSecrets` function reads the file and exports each key–value pair as an environment variable. The `maskSecrets` function then replaces the values in any shell output so they are never accidentally printed.

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
| `loadSecrets [path]` | Loads a JSON secrets file and exports each key as an environment variable. Defaults to `~/.secrets.json`. |
| `maskSecrets`        | Masks the values of all loaded secrets in subsequent shell output.                                        |
| `__mask_secrets__`   | Internal function called by `maskSecrets`.                                                                |
| `reloadOptions`      | Reloads shell options after secrets are masked.                                                           |

---

## Usage

```bash
# Load secrets from the default location (~/.secrets.json)
loadSecrets

# Load from a specific path
loadSecrets ~/iCloud/secrets/work.json

# Mask secrets in output
maskSecrets

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

## How `maskSecrets` Works

`maskSecrets` iterates over all known secret variable names loaded by `loadSecrets` and registers a ZSH preexec hook that replaces their values with `****` in command output. This prevents secrets from appearing in `set`, `env`, or accidental `echo $VAR` calls.

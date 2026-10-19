# Secrets Management

`dot` provides shell functions for loading secrets and explicitly filtering output. Loading does not prevent secrets from appearing in command history, logs, or unfiltered output.

---

## How It Works

Secrets are stored **outside the repository** at `$ICLOUD/dot/secrets.json`. The `dot::secrets::load` function reads this file into shell variables without adding export attributes; already-exported variables retain that attribute. It accepts no path argument. The `dot::secrets::mask` function separately reads the same JSON file and filters only the text passed to it.

Both operations require `jq`. Loading validates all names and reads all values before assignment, without generating or sourcing a temporary shell script. Values remain literal, including shell metacharacters. An assignment failure, such as a readonly variable, returns nonzero but can leave earlier assignments applied.

### Secret File Format

Use a JSON object with string values and valid shell identifier keys. The `_dot_secrets_` prefix is reserved; NUL characters are not supported.

```json
{
  "GITHUB_TOKEN": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "OPENAI_API_KEY": "sk-xxxxxxxxxxxxxxxxxxxx",
  "MY_WORK_PASSWORD": "hunter2"
}
```

---

## Functions

The dynamic family is defined in [modules/000-a-secrets.sh](../../modules/000-a-secrets.sh). See [Command Discovery](../../modules/README.md#command-discovery) for the shared interface conventions.

| Function                       | Description                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `dot::secrets help [command]`  | Shows help without reading credentials.                                                                 |
| `dot::secrets::load`           | Loads shell variables from `$ICLOUD/dot/secrets.json`.                                                  |
| `dot::secrets::mask [text...]` | Filters arguments and piped stdin using literal values from the JSON file.                              |
| `dot::secrets::reload-options` | Applies ZSH options from iCloud configuration, falling back to `DOT_SHELL_DATA`; requires ZSH and `yq`. |

The separate `dot::static::foundation::load-user-secrets` command **exports** loaded values and records names in `DOT_SECRET_KEYS`. Use `dot::static::foundation help load-user-secrets` for its listing options. It is distinct from the legacy `dot::static::foundation::load-secrets` loader.

---

## Usage

```bash
# Discover options without reading credentials
dot::secrets help load

# Load shell variables from $ICLOUD/dot/secrets.json
dot::secrets::load

# Export only variables needed by child processes
export GITHUB_TOKEN

# Explicitly filter output
printf '%s\n' "$GITHUB_TOKEN" | dot::secrets::mask

# Pass text literally, even when it resembles an option
dot::secrets mask -- '--help'
```

---

## Best Practices

- **Never commit your secrets file.** Add it to `.gitignore` or store it outside the repo entirely.
- **Use iCloud or a password manager** to sync secrets across machines rather than committing them.
- **Limit exposure**: export only values required by child processes. Never assume an ordinary `echo`, `env`, or `set` invocation is filtered.
- **Rotate frequently**: explicit filtering is not a substitute for secret rotation or access controls.

---

## How `dot::secrets::mask` Works

`dot::secrets::mask` replaces nonempty string values from the JSON file, longest first, with `**************`. Matching is literal rather than regular-expression based. The compatibility placeholder `SuperSecretPassword` is also masked. Loading variables first is not required.

Arguments are processed one per line, followed by piped stdin. Filtering is line-oriented, so multiline secrets are not reliably masked. The function installs no hook and does not intercept other commands, shell history, or stderr. Its direct arguments are always literal, including `--help`; request help with `dot::secrets help mask` instead.

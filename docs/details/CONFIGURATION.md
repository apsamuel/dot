# Configuration

define the desired state of a shell in the `shell.yaml`

```yaml
- name: Bash
  default: true
  tool: false
  type: Shell
  image: xxx.io/bash
  posix: true
  spec:
    secrets:
    - source: fromFile
      params:
        type: json
        path: null
    - source: fromUrl
      params:
        type: https
        url: null
    theme: robbyrussel
    framework: oh-my-bash
    plugins:
      - git
      - zsh-autosuggestions
      - zsh-syntax-highlighting
    zstyle:
      # identify configuration for zstyle definition
```

securely integrate sensitive settings from your `secrets.json`

```json
{
"FOO_SECRET": "bar_1234567891011121213"
}
```

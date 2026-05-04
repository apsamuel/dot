# Contributing

Thanks for your interest in improving `dot`. Contributions are welcome in the form of bug reports, new modules, documentation improvements, and fixes.

---

## Getting Started

1. Fork the repository and clone your fork:
   ```bash
   git clone https://github.com/<your-username>/dot.git ~/.dot
   ```

2. Run bootstrap to set up your environment:
   ```bash
   pushd ~/.dot && source ./bin/bootstrap.sh
   ```

3. Create a branch for your change:
   ```bash
   git checkout -b feat/my-improvement
   ```

---

## Types of Contributions

### Adding a `zlib` Module

Shell modules live in `zlib/`. To add one:

1. Choose a filename that fits the load order: `NNN-x-name.sh`
   - Use a tier appropriate to when your module needs to run (see [zlib/README.md](./zlib/README.md))
   - Use a letter sub-order that doesn't conflict with existing files
2. Start with the standard header:
   ```bash
   #shellcheck shell=bash
   # shellcheck source=/dev/null

   directory=$(dirname "$0")
   library=$(basename "$0")

   if [[ "${DOT_DEBUG}" -eq 1 ]]; then
       echo "loading: ${library} (${directory})"
   fi
   ```
3. If your module can be disabled, add a guard:
   ```bash
   if [[ "${DOT_DISABLE_MYMODULE:-0}" -eq 1 ]]; then return; fi
   ```
4. Test by opening a new shell and confirming your functions/aliases are available.
5. Document your module with a row in the [zlib/README.md](./zlib/README.md) module table.

### Adding a `bin/` Script

1. Add your script to `bin/`
2. Make it executable: `chmod +x bin/my-script.sh`
3. Add a row to [bin/README.md](./bin/README.md)
4. The script will be on `$PATH` after the next shell start

### Updating Configuration Defaults

Default options, plugins, and paths are configured in `config/data.json` and `config/data.yaml`. To add a new oh-my-zsh plugin, for example, add it to `plugins.builtin` in `config/data.json`.

### Documenting Changes

- Update the relevant `README.md` (root, `zlib/`, `bin/`, etc.)
- For feature additions, add an entry to `docs/`
- Keep entries concise — this is a reference, not a tutorial

---

## Code Style

- **Shell**: Follow existing conventions — use `#shellcheck shell=bash` and address shellcheck warnings where practical. Prefer `[[ ]]` over `[ ]`. Quote all variable expansions.
- **Function names**: Use `camelCase` for helper functions, `dot.namespace` for top-level commands, and `module::action` for module-scoped utilities.
- **Guards**: Wrap optional functionality in `DOT_DISABLE_*` guards so the module can be skipped.
- **Debug output**: Emit debug lines only when `DOT_DEBUG -eq 1`.

---

## Testing

Run the test suite before submitting:

```bash
cd test && bash run.sh
```

Tests cover shell basics, language target builds (C, C++, Go, Rust, Java), and user/sudo flows. Add a test file if your change introduces new shell behaviour.

---

## Submitting a Pull Request

1. Ensure your branch is up to date with `main`
2. Run shellcheck on any modified `.sh` files:
   ```bash
   shellcheck zlib/your-module.sh
   ```
3. Push your branch and open a pull request against `main`
4. Describe what the change does and why in the PR description
5. Link to any relevant issues

---

## Reporting Issues

Open a GitHub issue with:
- Your OS and ZSH version (`uname -a`, `zsh --version`)
- Steps to reproduce
- Expected vs actual behaviour
- Any relevant output from `DOT_DEBUG=1 zsh`

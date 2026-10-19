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
   pushd ~/.dot && source ./scripts/dot-bootstrap.sh
   ```

3. Create a branch for your change:

   ```bash
   git checkout -b feat/my-improvement
   ```

---

## Types of Contributions

### Adding a Module

Shell modules live in `modules/`. To add one:

1. Choose a filename that fits the load order: `NNN-x-name.sh`
   - Use a tier appropriate to when your module needs to run (see [modules/README.md](./modules/README.md))
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

4. Add isolated module tests and run the matching suite as described below. A real-shell smoke check is optional and may invoke host integrations.
5. Document your module with a row in the [modules/README.md](./modules/README.md) module table.

### Adding a `bin/` Script

1. Add your script to `bin/`
2. Make it executable: `chmod +x bin/my-script.sh`
3. Add a row to [bin/README.md](./bin/README.md)
4. The script will be on `$PATH` after the next shell start

### Updating Configuration Defaults

Default options, plugins, and paths are configured in `data/zsh.yaml`. To add a new oh-my-zsh plugin, for example, add it to `plugins.builtin` in `data/zsh.yaml`.

### Documenting Changes

- Update the relevant `README.md` (root, `modules/`, `bin/`, etc.)
- For feature additions, add an entry to `docs/`
- Keep entries concise — this is a reference, not a tutorial

---

## Code Style

- **Shell**: Follow existing conventions — use `#shellcheck shell=bash` and address shellcheck warnings where practical. Prefer `[[ ]]` over `[ ]`. Quote all variable expansions.
- **Function names**: Use `dot::<family>` for dispatchers and `dot::<family>::<action>` for public functions. Keep private helpers in the owning namespace with an underscore-prefixed action.
- **Guards**: Wrap optional functionality in `DOT_DISABLE_*` guards so the module can be skipped.
- **Debug output**: Emit debug lines only when `DOT_DEBUG -eq 1`.

---

## Testing

Run the isolated module suite from the repository root:

```bash
./test/run_unit.sh
./test/run_unit.sh test_000-a-config
DOT_TEST_SHELL=bash ./test/run_unit.sh test_000-a-config
bash -n modules/000-a-config.sh
zsh -n modules/000-a-config.sh
```

The default runner uses ZSH. Use an installed modern Bash for portable functions, not macOS's bundled Bash 3.2; ZSH-only builtins remain ZSH-only. Tests source real modules with isolated HOME/iCloud paths and mocked commands. Do not run real package managers, authentication, SSH agents, tmux sessions, VM operations, or bootstrap from unit tests. See [test/README.md](./test/README.md) for harness conventions and separately invoked manual smoke checks.

## Public Command Interfaces

- Keep shell functions and small explicit dispatchers; do not add parser runtimes or dispatch through `eval`.
- Support family help, topic help, and leaf `-h`/`--help` before checking operational dependencies. New dispatchers default to help; preserve established defaults and direct function names.
- Help must return 0 on stdout without backend work, credentials, writes, or TTY interaction. Describe actual flags, defaults, dependencies, effects, and failure behavior in source-local help.
- Validate wrapper-owned arguments before mutation. Guard missing values before `shift 2`, initialize local `OPTIND`/parser state, and preserve quoting, negative numbers, documented `--` boundaries, and delegated backend options.
- Keep successful stdout composable and send new diagnostics to stderr. Return backend failures; retain existing usage and predicate codes. Never `exit` from a sourced module or abort the caller with `${arg:?}`.
- Preserve literal-data helpers, predicates, logging, and lifecycle contracts. Document exceptions in the [family inventory](./modules/README.md#compatibility-boundaries), rather than forcing flag parsing into every helper.
- Keep definitions/help available when optional tools are absent, while preserving explicit disable flags and startup guards. Use only meaningful fallbacks; do not introduce blanket retries or automatic installs.
- Test repeated parsing, missing values/tools, quoted arguments, legacy output, help without side effects, and injected backend failures. Keep tests in the existing family suite where possible.

---

## Submitting a Pull Request

1. Ensure your branch is up to date with `main`
2. Run shellcheck on any modified `.sh` files:

   ```bash
   shellcheck modules/your-module.sh
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

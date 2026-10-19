# test

The `test/` directory contains isolated module unit tests and separate manual host/toolchain smoke checks. Unit tests exercise real shell functions with fixtures and mocked operational commands; they do not require installing the feature toolchains.

---

## Module Unit Tests

```bash
./test/run_unit.sh
./test/run_unit.sh -v
./test/run_unit.sh test_000-a-output
DOT_TEST_SHELL=bash ./test/run_unit.sh test_000-a-output
```

The runner discovers `modules/test_*.sh`, starts a separate ZSH process for each suite, and reports TAP results. Its optional filename substring selects a suite. `DOT_TEST_SHELL` selects another installed shell for portable tests; macOS Bash 3.2 is not the portable test target. ZSH builtin-specific assertions are skipped under Bash.

GNU Make 4.4+ also exposes `make test`, `make test-verbose`, and `make test-module MODULE=000-a-output` at the repository root.

### Harness and Isolation

- [framework.sh](framework.sh) provides `describe`, `it`, assertions, `source_module`, and `tap_summary`.
- [mocks/env.sh](mocks/env.sh) isolates HOME, iCloud, XDG paths and temporary files, and defaults `DOT_DRY_RUN=1`.
- [mocks/tools.sh](mocks/tools.sh) supplies backend mocks and call tracking. Semantic JSON tests use real `jq` against generated fixtures, never real secrets.
- Keep operational commands mocked, including absolute-path initialization where relevant. Do not touch real package, credential, SSH, tmux, VM, or history state.

### Adding a Module Test

1. Extend the matching `modules/test_<module>.sh`, or add it only when that family has no suite.
2. Copy a neighboring suite's portable bootstrap, source the harness and mocks, then load the real module with `source_module` where applicable.
3. Group cases with `describe`, register them using `it`, and end with `tap_summary`.
4. Check help equivalence and absence of backend calls; malformed inputs must fail before mutation. Cover repeated parser use, literal `--`, quoted/negative operands, dependency absence, and backend status propagation where relevant.
5. Run the filtered suite in ZSH and portable cases in a modern Bash, plus syntax checks and scoped ShellCheck.

Detailed command contracts and exceptions are maintained in [modules/README.md](../modules/README.md#command-discovery).

## Manual Smoke Checks

The scripts below inspect the real host or compile installed toolchains; the unit runner does not execute them. VM checks change VM state and require deliberate user action. `run.sh` still contains a stub `run_tests()` function and is not the unit-test entry point.

---

## Test Files

### Context Guards

These scripts are intended to be sourced at the top of other test scripts to assert the execution context before running.

| File         | What it checks                                                                |
| ------------ | ----------------------------------------------------------------------------- |
| `_group_.sh` | Current user is a member of the `admin` group (uses `dscl`)                   |
| `_sudo_.sh`  | Script is running as `root` (for tests that require elevated privileges)      |
| `_user_.sh`  | Script is **not** running as `root` (guard against accidental root execution) |

### Language Toolchain Tests

Each test compiles a minimal source file to confirm the toolchain is installed and working. They do not test runtime behaviour.

| File            | Language | What it does                                       |
| --------------- | -------- | -------------------------------------------------- |
| `_test_c.sh`    | C        | Compiles `test/main.c` with `clang`                |
| `_test_cpp.sh`  | C++      | Compiles `test/main.cpp` with `clang++`            |
| `_test_go.sh`   | Go       | Builds `test/main.go` with `go build`              |
| `_test_rust.sh` | Rust     | Builds `test/main.rs` with `rustc` / `cargo build` |
| `_test_java.sh` | Java     | Compiles a minimal Java source file with `javac`   |

### Source Fixtures

Minimal source files used as compile targets by the toolchain tests.

| File       | Language |
| ---------- | -------- |
| `main.c`   | C        |
| `main.cpp` | C++      |
| `main.go`  | Go       |
| `main.rs`  | Rust     |

---

## VM Control (vmctl) Tests

Smoke tests for the unified VM control tool (`bin/ivm.py`).

### Manual Smoke Test Sequence

If Apple VMs are configured (bundles present in `~/.vmctl/apple/`), test the full lifecycle:

```bash
# Check backend availability and version
python3 ~/.dot/bin/ivm.py backends

# List all configured VMs
python3 ~/.dot/bin/ivm.py list

# Start a VM (replace <vm> with actual bundle name)
python3 ~/.dot/bin/ivm.py start <vm>

# Check status (should show running)
python3 ~/.dot/bin/ivm.py status <vm>

# Test suspend (native helper only; will fail with vz)
python3 ~/.dot/bin/ivm.py suspend <vm>

# Test resume (native helper only)
python3 ~/.dot/bin/ivm.py resume <vm>

# Stop the VM
python3 ~/.dot/bin/ivm.py stop <vm>

# Verify stopped
python3 ~/.dot/bin/ivm.py status <vm>
```

### Provider Testing

Test fallback behavior and provider selection:

```bash
# Force native provider (fails if helper not installed)
IVM_APPLE_PROVIDER=swift-native python3 ~/.dot/bin/ivm.py backends

# Force vz fallback (fails if vz not installed)
IVM_APPLE_PROVIDER=vz python3 ~/.dot/bin/ivm.py backends

# Test invalid provider setting
IVM_APPLE_PROVIDER=invalid python3 ~/.dot/bin/ivm.py backends
```

---

## Adding a Manual Smoke Check

1. Create `test/_test_<name>.sh`.
2. Source a context guard at the top if the test requires a specific execution context.
3. Run the command under test and `exit 0` on success, `exit 1` on failure.
4. Register it in `run.sh` once `run_tests()` is implemented.

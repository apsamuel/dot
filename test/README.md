# test

The `test/` directory contains smoke tests that verify the environment is correctly configured and that each supported language toolchain is present and functional.

Tests are not a full unit-test suite — they are **presence/compile checks** intended to catch missing dependencies after a fresh bootstrap or OS upgrade.

---

## Running Tests

```bash
bash test/run.sh
```

> `run.sh` currently defines a stub `run_tests()` function. Individual test scripts can also be sourced or executed directly.

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

## Adding a Test

1. Create `test/_test_<name>.sh`.
2. Source a context guard at the top if the test requires a specific execution context.
3. Run the command under test and `exit 0` on success, `exit 1` on failure.
4. Register it in `run.sh` once `run_tests()` is implemented.

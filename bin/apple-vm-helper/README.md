# applevm-helper

Native Swift helper for Apple Virtualization.framework VM control.

## Building

Requires Xcode command-line tools (macOS 13+).

```bash
cd ~/.dot/bin/apple-vm-helper
swift build -c release
```

Binary output: `.build/release/applevm-helper`

## Command Contract

All commands output JSON to stdout. Errors print to stderr and exit with code 1.

### version

Returns helper version.

```bash
applevm-helper version
# Output: {"version":"0.1.0-swift"}
```

### list --root <dir>

Discover VM bundles in a root directory and return their status.

```bash
applevm-helper list --root ~/.vmctl/apple
# Output: {"vms":[{"name":"ubuntu","status":"stopped","id":"ubuntu"},...]}
```

### start --bundle <path> --name <vm>

Launch a VM bundle and return runtime state.

```bash
applevm-helper start --bundle ~/.vmctl/apple/ubuntu --name ubuntu
# Output: {"state":"running"}
```

### stop --name <vm> --grace <seconds>

Stop a running VM with graceful shutdown timeout.

```bash
applevm-helper stop --name ubuntu --grace 20
# Output: {"state":"stopped"}
```

### suspend --name <vm>

Pause a running VM (if supported).

```bash
applevm-helper suspend --name ubuntu
# Output: {"state":"suspended"}
```

### resume --name <vm>

Resume a suspended VM (if supported).

```bash
applevm-helper resume --name ubuntu
# Output: {"state":"running"}
```

### status --name <vm>

Query VM runtime state.

```bash
applevm-helper status --name ubuntu
# Output: {"state":"running","detail":null}
```

## Fallback

If helper is unavailable, `ivm.py` falls back to the `vz` CLI. Use `IVM_APPLE_PROVIDER=vz` to force fallback explicitly.

## Implementation Notes

- This is a scaffolded MVP that parses commands and returns JSON stubs.
- TODO: Implement actual Virtualization.framework calls.
- TODO: Implement VM bundle discovery and state persistence.
- TODO: Add macOS version compatibility checks and feature detection.

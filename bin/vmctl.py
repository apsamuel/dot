#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vmctl - unified VM/machine control across multiple backends.

Supported backends:
  utm    — UTM (utmctl)
  qemu   — QEMU (qemu-system-*), VMs defined in ~/.vmctl/qemu/*.json
  podman — Podman Machine (podman machine)
  apple  — Apple Virtualization.framework via vz CLI, bundles in ~/.vmctl/apple/

Usage examples:
  vmctl backends
  vmctl list [--backend utm|qemu|podman|apple]
  vmctl start  <vm> [--backend <name>]
  vmctl stop   <vm> [--backend <name>]
  vmctl suspend <vm> [--backend <name>]
  vmctl resume  <vm> [--backend <name>]
  vmctl status  <vm> [--backend <name>]
  vmctl shell   <vm> [--backend <name>]
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from abc import ABC, abstractmethod
from typing import Optional

SCRIPT_VERSION = "2.0.0"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(
    cmd: list[str], *, capture: bool = True, check: bool = False
) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        text=True,
        check=check,
    )


def _which(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def _print_table(headers: list[str], rows: list[list[str]]) -> None:
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    print(fmt.format(*headers))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        print(fmt.format(*[str(c) for c in row]))


# ---------------------------------------------------------------------------
# Backend base class
# ---------------------------------------------------------------------------


class VMBackend(ABC):
    name: str = "base"

    @abstractmethod
    def is_available(self) -> bool: ...

    @abstractmethod
    def list_vms(self) -> list[dict]: ...

    @abstractmethod
    def start(self, vm: str) -> None: ...

    @abstractmethod
    def stop(self, vm: str) -> None: ...

    @abstractmethod
    def status(self, vm: str) -> None: ...

    def suspend(self, vm: str) -> None:
        print(f"[{self.name}] suspend is not supported", file=sys.stderr)

    def resume(self, vm: str) -> None:
        print(f"[{self.name}] resume is not supported", file=sys.stderr)

    def shell(self, vm: str) -> None:
        print(f"[{self.name}] shell/ssh is not supported", file=sys.stderr)

    def version(self) -> str:
        return "unknown"


# ---------------------------------------------------------------------------
# UTM backend
# ---------------------------------------------------------------------------


class UTMBackend(VMBackend):
    """Wraps utmctl — the official UTM CLI (macOS only)."""

    name = "utm"

    def is_available(self) -> bool:
        return _which("utmctl")

    def version(self) -> str:
        r = _run(["utmctl", "version"])
        return r.stdout.strip() if r.returncode == 0 else "unknown"

    def list_vms(self) -> list[dict]:
        r = _run(["utmctl", "list"])
        if r.returncode != 0:
            print(f"[utm] error: {r.stderr.strip()}", file=sys.stderr)
            return []
        vms = []
        for line in r.stdout.strip().splitlines():
            # Format: "<uuid>: <name> (<status>)"
            parts = line.split(": ", 1)
            if len(parts) < 2:
                continue
            uuid = parts[0].strip()
            rest = parts[1]
            if "(" in rest and rest.endswith(")"):
                vm_name, status_part = rest.rsplit("(", 1)
                status = status_part.rstrip(")")
            else:
                vm_name, status = rest, "unknown"
            vms.append({"name": vm_name.strip(), "status": status.strip(), "id": uuid})
        return vms

    def start(self, vm: str) -> None:
        _run(["utmctl", "start", vm], capture=False)

    def stop(self, vm: str) -> None:
        _run(["utmctl", "stop", vm], capture=False)

    def suspend(self, vm: str) -> None:
        _run(["utmctl", "suspend", vm], capture=False)

    def resume(self, vm: str) -> None:
        # UTM has no explicit resume; starting a suspended VM resumes it.
        _run(["utmctl", "start", vm], capture=False)

    def status(self, vm: str) -> None:
        r = _run(["utmctl", "status", vm])
        print(
            r.stdout.strip()
            if r.returncode == 0
            else f"[utm] error: {r.stderr.strip()}"
        )

    def shell(self, vm: str) -> None:
        os.execvp("utmctl", ["utmctl", "attach", vm])


# ---------------------------------------------------------------------------
# QEMU backend
# ---------------------------------------------------------------------------


class QEMUBackend(VMBackend):
    """Manages QEMU VMs defined as JSON configs in ~/.vmctl/qemu/<name>.json.

    Minimal config schema:
      {
        "name": "myvm",
        "cmd":  ["qemu-system-aarch64", "-machine", "virt", ...],
        "qmp_socket": "/tmp/myvm.qmp",   // optional, for stop/suspend/status
        "ssh_port":   2222,               // optional, for shell
        "ssh_user":   "root"              // optional
      }
    """

    name = "qemu"
    CONFIG_DIR = os.path.expanduser("~/.vmctl/qemu")

    def is_available(self) -> bool:
        return any(
            _which(f"qemu-system-{a}") for a in ("x86_64", "aarch64", "arm", "riscv64")
        )

    def version(self) -> str:
        for arch in ("aarch64", "x86_64", "arm"):
            if _which(f"qemu-system-{arch}"):
                r = _run([f"qemu-system-{arch}", "--version"])
                if r.returncode == 0:
                    return r.stdout.splitlines()[0].strip()
        return "unknown"

    # -- internal helpers --

    def _configs(self) -> list[dict]:
        if not os.path.isdir(self.CONFIG_DIR):
            return []
        cfgs = []
        for fname in sorted(os.listdir(self.CONFIG_DIR)):
            if not fname.endswith(".json"):
                continue
            try:
                with open(os.path.join(self.CONFIG_DIR, fname)) as fh:
                    cfgs.append(json.load(fh))
            except (json.JSONDecodeError, OSError):
                pass
        return cfgs

    def _cfg_for(self, name: str) -> Optional[dict]:
        return next((c for c in self._configs() if c.get("name") == name), None)

    def _qmp(
        self, socket_path: str, execute: str, arguments: Optional[dict] = None
    ) -> Optional[dict]:
        """Send a single QMP command over a UNIX socket."""
        import socket as _sock

        payload = json.dumps(
            {"execute": execute, **({"arguments": arguments} if arguments else {})}
        ).encode()
        try:
            with _sock.socket(_sock.AF_UNIX, _sock.SOCK_STREAM) as s:
                s.settimeout(3)
                s.connect(socket_path)
                buf = b""
                # Read QMP greeting
                while b'"QMP"' not in buf:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                # Negotiate capabilities
                s.sendall(json.dumps({"execute": "qmp_capabilities"}).encode())
                s.recv(4096)
                # Send command and collect response
                s.sendall(payload)
                buf = b""
                while True:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                    try:
                        return json.loads(buf)
                    except json.JSONDecodeError:
                        pass
        except (OSError, TimeoutError):
            return None

    def _is_running(self, cfg: dict) -> bool:
        sock = cfg.get("qmp_socket")
        if sock and os.path.exists(sock):
            return bool(self._qmp(sock, "query-status"))
        return False

    # -- public interface --

    def list_vms(self) -> list[dict]:
        return [
            {
                "name": c.get("name", "(unnamed)"),
                "status": "running" if self._is_running(c) else "stopped",
                "id": c.get("name", ""),
            }
            for c in self._configs()
        ]

    def start(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if not cfg:
            print(f"[qemu] no config for '{vm}' in {self.CONFIG_DIR}", file=sys.stderr)
            return
        cmd = cfg.get("cmd")
        if not cmd:
            print(f"[qemu] 'cmd' missing in config for '{vm}'", file=sys.stderr)
            return
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"[qemu] started '{vm}'")

    def stop(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if not cfg:
            print(f"[qemu] no config for '{vm}'", file=sys.stderr)
            return
        sock = cfg.get("qmp_socket")
        if sock and os.path.exists(sock):
            self._qmp(sock, "system_powerdown")
            print(f"[qemu] sent powerdown to '{vm}'")
        else:
            print(f"[qemu] no QMP socket available for '{vm}'", file=sys.stderr)

    def suspend(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if cfg:
            sock = cfg.get("qmp_socket")
            if sock and os.path.exists(sock):
                self._qmp(sock, "stop")
                print(f"[qemu] paused '{vm}'")
                return
        print(f"[qemu] cannot suspend '{vm}'", file=sys.stderr)

    def resume(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if cfg:
            sock = cfg.get("qmp_socket")
            if sock and os.path.exists(sock):
                self._qmp(sock, "cont")
                print(f"[qemu] resumed '{vm}'")
                return
        print(f"[qemu] cannot resume '{vm}'", file=sys.stderr)

    def status(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if not cfg:
            print(f"[qemu] no config for '{vm}'", file=sys.stderr)
            return
        sock = cfg.get("qmp_socket")
        if sock and os.path.exists(sock):
            resp = self._qmp(sock, "query-status")
            if resp and "return" in resp:
                print(f"[qemu] {vm}: {resp['return']}")
                return
        print(f"[qemu] {vm}: stopped (no QMP socket)")

    def shell(self, vm: str) -> None:
        cfg = self._cfg_for(vm)
        if not cfg:
            print(f"[qemu] no config for '{vm}'", file=sys.stderr)
            return
        ssh_port = cfg.get("ssh_port")
        if not ssh_port:
            print(f"[qemu] 'ssh_port' not set in config for '{vm}'", file=sys.stderr)
            return
        ssh_user = cfg.get("ssh_user", "root")
        os.execvp("ssh", ["ssh", "-p", str(ssh_port), f"{ssh_user}@localhost"])


# ---------------------------------------------------------------------------
# Podman Machine backend
# ---------------------------------------------------------------------------


class PodmanBackend(VMBackend):
    """Wraps `podman machine` — lightweight VMs for running container workloads."""

    name = "podman"

    def is_available(self) -> bool:
        return _which("podman")

    def version(self) -> str:
        r = _run(["podman", "--version"])
        return r.stdout.strip() if r.returncode == 0 else "unknown"

    def list_vms(self) -> list[dict]:
        r = _run(["podman", "machine", "list", "--format", "json"])
        if r.returncode != 0:
            print(f"[podman] error: {r.stderr.strip()}", file=sys.stderr)
            return []
        try:
            data = json.loads(r.stdout)
            machines = data if isinstance(data, list) else [data]
            result = []
            for m in machines:
                if m.get("Running"):
                    status = "running"
                elif m.get("Starting"):
                    status = "starting"
                else:
                    status = "stopped"
                result.append(
                    {
                        "name": m.get("Name", ""),
                        "status": status,
                        "id": m.get("Name", ""),
                        "cpus": str(m.get("CPUs", "")),
                        "memory": str(m.get("Memory", "")),
                    }
                )
            return result
        except json.JSONDecodeError:
            return []

    def start(self, vm: str) -> None:
        _run(["podman", "machine", "start", vm], capture=False)

    def stop(self, vm: str) -> None:
        _run(["podman", "machine", "stop", vm], capture=False)

    def status(self, vm: str) -> None:
        r = _run(["podman", "machine", "inspect", vm])
        print(
            r.stdout.strip()
            if r.returncode == 0
            else f"[podman] error: {r.stderr.strip()}"
        )

    def shell(self, vm: str) -> None:
        os.execvp("podman", ["podman", "machine", "ssh", vm])


# ---------------------------------------------------------------------------
# Apple Virtualization.framework backend
# ---------------------------------------------------------------------------


class AppleBackend(VMBackend):
    """Wraps the `vz` CLI (https://github.com/Code-Hex/vz) built on Apple's
    Virtualization.framework.  VM bundles live in ~/.vmctl/apple/<name>/ with
    an optional config.json for SSH access details.

    Minimal ~/.vmctl/apple/<name>/config.json:
      { "ssh_port": 2222, "ssh_user": "admin" }
    """

    name = "apple"
    CONFIG_DIR = os.path.expanduser("~/.vmctl/apple")
    _cli: Optional[str] = None

    def is_available(self) -> bool:
        if _which("vz"):
            self._cli = "vz"
            return True
        return False

    def version(self) -> str:
        if not self._cli:
            return "not installed (install vz: https://github.com/Code-Hex/vz)"
        r = _run([self._cli, "version"])
        return r.stdout.strip() if r.returncode == 0 else "unknown"

    # -- internal --

    def _vm_names(self) -> list[str]:
        if not os.path.isdir(self.CONFIG_DIR):
            return []
        return sorted(
            d
            for d in os.listdir(self.CONFIG_DIR)
            if os.path.isdir(os.path.join(self.CONFIG_DIR, d))
        )

    def _cfg_path(self, name: str) -> Optional[str]:
        p = os.path.join(self.CONFIG_DIR, name, "config.json")
        return p if os.path.isfile(p) else None

    def _load_cfg(self, name: str) -> dict:
        p = self._cfg_path(name)
        if p:
            try:
                with open(p) as fh:
                    return json.load(fh)
            except (json.JSONDecodeError, OSError):
                pass
        return {}

    # -- public interface --

    def list_vms(self) -> list[dict]:
        return [
            {
                "name": n,
                "status": "unknown",
                "id": n,
                "config": self._cfg_path(n) or "(none)",
            }
            for n in self._vm_names()
        ]

    def start(self, vm: str) -> None:
        if not self._cli:
            print("[apple] vz is not installed", file=sys.stderr)
            return
        bundle = os.path.join(self.CONFIG_DIR, vm)
        if not os.path.isdir(bundle):
            print(f"[apple] bundle not found: {bundle}", file=sys.stderr)
            return
        subprocess.Popen(
            [self._cli, "run", bundle],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(f"[apple] started '{vm}'")

    def stop(self, vm: str) -> None:
        # vz has no stop subcommand; signal the spawned process.
        print(
            f"[apple] graceful stop not yet implemented — "
            f"find the vz process for '{vm}' and send SIGTERM",
            file=sys.stderr,
        )

    def status(self, vm: str) -> None:
        cfg_path = self._cfg_path(vm)
        bundle = os.path.join(self.CONFIG_DIR, vm)
        if os.path.isdir(bundle):
            print(
                f"[apple] {vm}: bundle at {bundle}"
                + (f", config: {cfg_path}" if cfg_path else "")
            )
        else:
            print(f"[apple] {vm}: not found in {self.CONFIG_DIR}", file=sys.stderr)

    def shell(self, vm: str) -> None:
        cfg = self._load_cfg(vm)
        ssh_port = cfg.get("ssh_port", 22)
        ssh_user = cfg.get("ssh_user", os.environ.get("USER", "root"))
        os.execvp("ssh", ["ssh", "-p", str(ssh_port), f"{ssh_user}@localhost"])


# ---------------------------------------------------------------------------
# Backend registry
# ---------------------------------------------------------------------------

_ALL_BACKENDS: list[VMBackend] = [
    UTMBackend(),
    QEMUBackend(),
    PodmanBackend(),
    AppleBackend(),
]

_BACKEND_MAP: dict[str, VMBackend] = {b.name: b for b in _ALL_BACKENDS}


def _available_backends() -> list[VMBackend]:
    return [b for b in _ALL_BACKENDS if b.is_available()]


def _resolve_backend(name: Optional[str]) -> list[VMBackend]:
    """Return the requested backend(s), or all available if name is None."""
    if name:
        b = _BACKEND_MAP.get(name)
        if not b:
            print(
                f"Unknown backend '{name}'. Choose from: {', '.join(_BACKEND_MAP)}",
                file=sys.stderr,
            )
            sys.exit(1)
        if not b.is_available():
            print(f"Backend '{name}' is not available on this system.", file=sys.stderr)
            sys.exit(1)
        return [b]
    return _available_backends()


def _find_backend_for_vm(
    vm_name: str, backends: list[VMBackend]
) -> Optional[VMBackend]:
    """Return the first backend that lists a VM matching vm_name."""
    matches = []
    for b in backends:
        try:
            vms = b.list_vms()
        except Exception:
            continue
        if any(v["name"] == vm_name for v in vms):
            matches.append(b)
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        names = ", ".join(m.name for m in matches)
        print(
            f"Ambiguous: '{vm_name}' found in multiple backends ({names}). "
            "Use --backend to specify.",
            file=sys.stderr,
        )
        sys.exit(1)
    return None


# ---------------------------------------------------------------------------
# Sub-command handlers
# ---------------------------------------------------------------------------


def cmd_backends(_args: argparse.Namespace) -> None:
    rows = []
    for b in _ALL_BACKENDS:
        avail = b.is_available()
        ver = b.version() if avail else "—"
        rows.append([b.name, "yes" if avail else "no", ver])
    _print_table(["BACKEND", "AVAILABLE", "VERSION"], rows)


def cmd_list(args: argparse.Namespace) -> None:
    backends = _resolve_backend(args.backend)
    if not backends:
        print("No VM backends are available on this system.", file=sys.stderr)
        sys.exit(1)
    all_rows: list[list[str]] = []
    for b in backends:
        try:
            for v in b.list_vms():
                all_rows.append(
                    [b.name, v.get("name", ""), v.get("status", ""), v.get("id", "")]
                )
        except Exception as exc:
            print(f"[{b.name}] error listing VMs: {exc}", file=sys.stderr)
    if not all_rows:
        print("No VMs found.")
        return
    _print_table(["BACKEND", "NAME", "STATUS", "ID"], all_rows)


def _dispatch(args: argparse.Namespace, action: str) -> None:
    """Resolve backend and call action(vm) on the right backend."""
    backends = _resolve_backend(args.backend)
    b = _find_backend_for_vm(args.vm, backends)
    if b is None:
        scope = f"backend '{args.backend}'" if args.backend else "any available backend"
        print(f"VM '{args.vm}' not found in {scope}.", file=sys.stderr)
        sys.exit(1)
    getattr(b, action)(args.vm)


def cmd_start(args: argparse.Namespace) -> None:
    _dispatch(args, "start")


def cmd_stop(args: argparse.Namespace) -> None:
    _dispatch(args, "stop")


def cmd_suspend(args: argparse.Namespace) -> None:
    _dispatch(args, "suspend")


def cmd_resume(args: argparse.Namespace) -> None:
    _dispatch(args, "resume")


def cmd_status(args: argparse.Namespace) -> None:
    _dispatch(args, "status")


def cmd_shell(args: argparse.Namespace) -> None:
    _dispatch(args, "shell")


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------


def _backend_choices() -> list[str]:
    return list(_BACKEND_MAP.keys())


def _add_vm_arg(p: argparse.ArgumentParser) -> None:
    p.add_argument("vm", metavar="VM", help="VM name")


def _add_backend_opt(p: argparse.ArgumentParser) -> None:
    p.add_argument(
        "--backend",
        "-b",
        choices=_backend_choices(),
        metavar="BACKEND",
        default=None,
        help=f"backend to use ({', '.join(_backend_choices())})",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vmctl",
        description="Unified VM control — UTM, QEMU, Podman Machine, Apple VZ",
    )
    parser.add_argument(
        "--version", action="version", version=f"vmctl {SCRIPT_VERSION}"
    )

    sub = parser.add_subparsers(dest="command", metavar="COMMAND")
    sub.required = True

    # backends
    p_be = sub.add_parser("backends", help="list available backends and their versions")
    p_be.set_defaults(func=cmd_backends)

    # list
    p_ls = sub.add_parser("list", help="list VMs")
    _add_backend_opt(p_ls)
    p_ls.set_defaults(func=cmd_list)

    # start / stop / suspend / resume / status / shell
    for name, hlp, fn in [
        ("start", "start a VM", cmd_start),
        ("stop", "stop a VM", cmd_stop),
        ("suspend", "suspend/pause a VM", cmd_suspend),
        ("resume", "resume a paused VM", cmd_resume),
        ("status", "show VM status", cmd_status),
        ("shell", "open shell/SSH into VM", cmd_shell),
    ]:
        p = sub.add_parser(name, help=hlp)
        _add_vm_arg(p)
        _add_backend_opt(p)
        p.set_defaults(func=fn)

    return parser


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

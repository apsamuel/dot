#!/usr/bin/env python3

import argparse
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path
from typing import Any

VERSION = "0.1.0"

ICLOUD_ROOT = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs"
ICLOUD_DOCUMENTS = ICLOUD_ROOT / "Documents"
MOBILE_ME_PLIST = Path.home() / "Library/Preferences/MobileMeAccounts.plist"
NOTES_GROUP_CONTAINER = Path.home() / "Library/Group Containers/group.com.apple.notes"
NOTES_APP_CONTAINER = Path.home() / "Library/Containers/com.apple.Notes"
MUSIC_LIBRARY = Path.home() / "Music"

ANSI_RESET = "\033[0m"
ANSI_BOLD = "\033[1m"
ANSI_RED = "\033[31m"
ANSI_GREEN = "\033[32m"
ANSI_CYAN = "\033[36m"


def _result(
    *,
    command: str,
    ok: bool,
    data: dict[str, Any] | None = None,
    warnings: list[str] | None = None,
    errors: list[str] | None = None,
) -> dict[str, Any]:
    return {
        "status": "ok" if ok else "error",
        "command": command,
        "data": data or {},
        "warnings": warnings or [],
        "errors": errors or [],
    }


def _print_json(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if payload["status"] == "ok" else 1


def _print_text(
    payload: dict[str, Any], verbosity: str, *, color: bool, no_headers: bool
) -> int:
    status = payload.get("status", "unknown")
    command = payload.get("command", "unknown")
    data = payload.get("data", {})
    warnings = payload.get("warnings", [])
    errors = payload.get("errors", [])

    print(f"status: {_style_status(str(status), color)}")
    print(f"{_style_label('command', color)}: {command}")
    if isinstance(data, dict):
        _render_text_data(command, data, verbosity, color=color, no_headers=no_headers)

    if warnings and (verbosity == "verbose" or status != "ok"):
        print(_style_label("warnings", color) + ":")
        for warning in warnings:
            print(f"- {warning}")

    if errors:
        print(_style_label("errors", color) + ":")
        for error in errors:
            print(f"- {error}")

    return 0 if status == "ok" else 1


def _supports_color(enabled: bool) -> bool:
    if not enabled:
        return False
    return os.environ.get("TERM", "") not in {"", "dumb"}


def _style(text: str, code: str, enabled: bool) -> str:
    if not enabled:
        return text
    return f"{code}{text}{ANSI_RESET}"


def _style_label(text: str, enabled: bool) -> str:
    return _style(text, ANSI_BOLD + ANSI_CYAN, enabled)


def _style_status(text: str, enabled: bool) -> str:
    if not enabled:
        return text
    if text == "ok":
        return _style(text, ANSI_BOLD + ANSI_GREEN, enabled)
    if text == "error":
        return _style(text, ANSI_BOLD + ANSI_RED, enabled)
    return _style(text, ANSI_BOLD, enabled)


def _print_table(
    headers: list[str], rows: list[list[Any]], *, no_headers: bool
) -> None:
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    if not no_headers:
        print(fmt.format(*headers))
        print("  ".join("-" * w for w in widths))
    for row in rows:
        print(fmt.format(*[str(c) for c in row]))


def _print_paging(data: dict[str, Any], verbosity: str, *, color: bool) -> None:
    if verbosity != "verbose":
        return
    paging = data.get("paging")
    if not isinstance(paging, dict):
        return
    print(
        f"{_style_label('paging', color)}: "
        f"offset={paging.get('offset')} "
        f"limit={paging.get('limit')} "
        f"returned={paging.get('returned')} "
        f"total={paging.get('total')}"
    )


def _print_kv(label: str, value: Any, *, color: bool) -> None:
    print(f"{_style_label(label, color)}: {value}")


def _render_text_data(
    command: str, data: dict[str, Any], verbosity: str, *, color: bool, no_headers: bool
) -> None:
    if command == "icloud enabled":
        _print_kv("enabled", data.get("enabled"), color=color)
        if verbosity == "verbose":
            _print_kv("reliability", data.get("reliability"), color=color)
        accounts = data.get("accounts", [])
        rows: list[list[Any]] = []
        for account in accounts if isinstance(accounts, list) else []:
            services = account.get("services", [])
            enabled_count = sum(1 for s in services if s.get("enabled"))
            rows.append([account.get("apple_id", ""), enabled_count, len(services)])
        if rows:
            _print_table(
                ["apple_id", "enabled_services", "total_services"],
                rows,
                no_headers=no_headers,
            )
        return

    if command == "icloud documents list":
        _print_kv("folder_count", data.get("folder_count"), color=color)
        if verbosity == "verbose":
            _print_kv("documents_path", data.get("documents_path"), color=color)
            _print_kv("reliability", data.get("reliability"), color=color)
        folders = data.get("folders", [])
        if isinstance(folders, list) and folders:
            offset = 0
            paging = data.get("paging")
            if isinstance(paging, dict):
                offset = int(paging.get("offset", 0))
            rows = [[offset + idx + 1, name] for idx, name in enumerate(folders)]
            _print_table(["index", "folder"], rows, no_headers=no_headers)
        _print_paging(data, verbosity, color=color)
        return

    if command == "notes folders":
        _print_kv("folder_count", data.get("folder_count"), color=color)
        _print_kv("total_notes", data.get("total_notes"), color=color)
        if verbosity == "verbose":
            _print_kv("reliability", data.get("reliability"), color=color)
        folders = data.get("folders", [])
        if isinstance(folders, list) and folders:
            rows = [
                [
                    item.get("account", ""),
                    item.get("folder", ""),
                    item.get("note_count", 0),
                ]
                for item in folders
                if isinstance(item, dict)
            ]
            if rows:
                _print_table(
                    ["account", "folder", "note_count"], rows, no_headers=no_headers
                )
        _print_paging(data, verbosity, color=color)
        return

    if command == "music list":
        _print_kv("entity", data.get("entity"), color=color)
        _print_kv("count", data.get("count"), color=color)
        if verbosity == "verbose":
            _print_kv("reliability", data.get("reliability"), color=color)
        items = data.get("items", [])
        if isinstance(items, list) and items:
            offset = 0
            paging = data.get("paging")
            if isinstance(paging, dict):
                offset = int(paging.get("offset", 0))
            rows = [[offset + idx + 1, item] for idx, item in enumerate(items)]
            _print_table(["index", "item"], rows, no_headers=no_headers)
        _print_paging(data, verbosity, color=color)
        return

    if command in {"icloud usage", "notes usage", "music usage"}:
        local = data.get("local", {})
        cloud = data.get("cloud", {})
        if "path" in data:
            _print_kv("path", data.get("path"), color=color)
        elif verbosity == "verbose":
            _print_kv("path", "(multiple paths)", color=color)
        if "paths" in data and verbosity == "verbose":
            paths = data.get("paths", [])
            if isinstance(paths, list):
                for p in paths:
                    print(f"- path: {p}")
        if isinstance(local, dict):
            _print_kv(
                "local",
                f"{local.get('human')} ({local.get('bytes')} bytes)",
                color=color,
            )
            if verbosity == "verbose":
                _print_kv("local_reliability", local.get("reliability"), color=color)
        if isinstance(cloud, dict):
            _print_kv(
                "cloud",
                f"{cloud.get('human')} ({cloud.get('bytes')} bytes)",
                color=color,
            )
            if verbosity == "verbose":
                _print_kv("cloud_reliability", cloud.get("reliability"), color=color)
            if cloud.get("message") and verbosity == "verbose":
                _print_kv("cloud_message", cloud.get("message"), color=color)
        return

    if command == "notes attachments export":
        _print_kv("destination", data.get("destination"), color=color)
        _print_kv("dry_run", data.get("dry_run"), color=color)
        _print_kv("files_exported", data.get("files_exported"), color=color)
        _print_kv("files_skipped", data.get("files_skipped"), color=color)
        _print_kv("files_considered", data.get("files_considered"), color=color)
        exts = data.get("only_extensions")
        if isinstance(exts, list) and exts:
            _print_kv("only_extensions", ", ".join(exts), color=color)
        exported = data.get("exported", [])
        if isinstance(exported, list) and exported and verbosity == "verbose":
            preview = [[idx + 1, path] for idx, path in enumerate(exported[:20])]
            _print_table(["index", "exported_path"], preview, no_headers=no_headers)
            if len(exported) > 20:
                print(f"... {len(exported) - 20} more exported paths")
        failures = data.get("failures", [])
        if isinstance(failures, list) and failures:
            rows = [
                [f.get("source", ""), f.get("error", "")]
                for f in failures
                if isinstance(f, dict)
            ]
            if rows:
                _print_table(["source", "error"], rows, no_headers=no_headers)
        return

    for key, value in data.items():
        if isinstance(value, list):
            _print_kv(key, f"{len(value)} item(s)", color=color)
        elif isinstance(value, dict):
            _print_kv(key, "object", color=color)
        else:
            _print_kv(key, value, color=color)


def _paginate(
    items: list[Any], offset: int, limit: int
) -> tuple[list[Any], dict[str, int]]:
    start = max(0, offset)
    if limit <= 0:
        end = len(items)
    else:
        end = start + limit
    paged = items[start:end]
    meta = {
        "offset": start,
        "limit": limit,
        "returned": len(paged),
        "total": len(items),
    }
    return paged, meta


def _run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )


def _osascript(script: str) -> tuple[bool, str, str]:
    cp = _run(["osascript", "-e", script])
    return cp.returncode == 0, cp.stdout.strip(), cp.stderr.strip()


def _load_mobile_me_accounts(
    plist_path: Path,
) -> tuple[list[dict[str, Any]], list[str]]:
    warnings: list[str] = []
    if not plist_path.exists():
        warnings.append(f"plist not found: {plist_path}")
        return [], warnings
    try:
        with plist_path.open("rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:
        warnings.append(f"failed to read plist: {exc}")
        return [], warnings
    accounts = data.get("Accounts", [])
    if not isinstance(accounts, list):
        warnings.append("invalid plist shape: Accounts is not a list")
        return [], warnings
    return accounts, warnings


def _du_bytes(path: Path) -> int | None:
    if not path.exists():
        return None
    cp = _run(["du", "-sk", str(path)])
    if cp.returncode != 0:
        return None
    try:
        kib = int(cp.stdout.split()[0])
    except (IndexError, ValueError):
        return None
    return kib * 1024


def _human_size(num_bytes: int | None) -> str | None:
    if num_bytes is None:
        return None
    value = float(num_bytes)
    units = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    while value >= 1024 and i < len(units) - 1:
        value /= 1024.0
        i += 1
    return f"{value:.2f} {units[i]}"


def _icloud_quota_hint() -> tuple[dict[str, Any], list[str]]:
    warnings: list[str] = []
    if shutil.which("brctl") is None:
        return (
            {
                "reliability": "unavailable",
                "message": "brctl not available",
                "raw_excerpt": None,
            },
            warnings,
        )

    cp = _run(["brctl", "status"])
    if cp.returncode != 0:
        warnings.append(cp.stderr.strip() or "brctl status failed")
        return (
            {
                "reliability": "unavailable",
                "message": "unable to query iCloud daemon status",
                "raw_excerpt": None,
            },
            warnings,
        )

    lines = [line.strip() for line in cp.stdout.splitlines() if line.strip()]
    excerpt = "\n".join(lines[:20]) if lines else None
    return (
        {
            "reliability": "inferred",
            "message": "macOS does not expose exact per-service cloud quota via local public APIs",
            "raw_excerpt": excerpt,
        },
        warnings,
    )


def cmd_icloud_enabled(args: argparse.Namespace) -> dict[str, Any]:
    accounts, warnings = _load_mobile_me_accounts(Path(args.plist))
    summary: list[dict[str, Any]] = []
    service_enabled_count = 0
    cloud_docs_enabled = False

    for account in accounts:
        services = account.get("Services", [])
        parsed_services: list[dict[str, Any]] = []
        for service in services:
            name = str(service.get("Name", ""))
            enabled = bool(service.get("Enabled", False))
            parsed_services.append({"name": name, "enabled": enabled})
            service_enabled_count += 1 if enabled else 0
            if name.lower() in {"cloud docs", "icloud drive", "clouddocs"} and enabled:
                cloud_docs_enabled = True
        summary.append(
            {"apple_id": account.get("AccountID"), "services": parsed_services}
        )

    enabled = bool(accounts) and (cloud_docs_enabled or service_enabled_count > 0)
    return _result(
        command="icloud enabled",
        ok=True,
        warnings=warnings,
        data={"enabled": enabled, "reliability": "exact", "accounts": summary},
    )


def cmd_icloud_sync_status(_args: argparse.Namespace) -> dict[str, Any]:
    warnings: list[str] = []
    docs_exists = ICLOUD_DOCUMENTS.exists()
    docs_readable = os.access(ICLOUD_DOCUMENTS, os.R_OK) if docs_exists else False

    total_files = 0
    zero_byte_files = 0
    if docs_exists and docs_readable:
        for root, _, files in os.walk(ICLOUD_DOCUMENTS):
            for file_name in files:
                total_files += 1
                try:
                    size = (Path(root) / file_name).stat().st_size
                except OSError:
                    continue
                if size == 0:
                    zero_byte_files += 1
                if total_files >= 20000:
                    warnings.append("file scan capped at 20000 entries")
                    break
            if total_files >= 20000:
                break

    quota_hint, quota_warnings = _icloud_quota_hint()
    warnings.extend(quota_warnings)

    sync_state = "unknown"
    excerpt = quota_hint.get("raw_excerpt")
    if isinstance(excerpt, str):
        lowered = excerpt.lower()
        if "sync up to date" in lowered or "idle" in lowered:
            sync_state = "idle"
        elif "upload" in lowered or "download" in lowered or "sync" in lowered:
            sync_state = "syncing"

    return _result(
        command="icloud sync-status",
        ok=True,
        warnings=warnings,
        data={
            "sync_state": sync_state,
            "reliability": "inferred",
            "documents_path": str(ICLOUD_DOCUMENTS),
            "documents_path_exists": docs_exists,
            "documents_path_readable": docs_readable,
            "file_scan": {
                "total_files_seen": total_files,
                "zero_byte_files_seen": zero_byte_files,
                "zero_byte_ratio": (
                    (zero_byte_files / total_files) if total_files else 0.0
                ),
            },
            "quota_hint": quota_hint,
        },
    )


def cmd_icloud_documents_list(args: argparse.Namespace) -> dict[str, Any]:
    if not ICLOUD_DOCUMENTS.exists():
        return _result(
            command="icloud documents list",
            ok=False,
            errors=[f"path not found: {ICLOUD_DOCUMENTS}"],
        )

    folders = sorted(
        [
            p.name
            for p in ICLOUD_DOCUMENTS.iterdir()
            if p.is_dir() and not p.name.startswith(".")
        ]
    )
    paged, paging = _paginate(folders, args.offset, args.limit)
    return _result(
        command="icloud documents list",
        ok=True,
        data={
            "documents_path": str(ICLOUD_DOCUMENTS),
            "folder_count": len(folders),
            "folders": paged,
            "paging": paging,
            "reliability": "exact",
        },
    )


def cmd_icloud_usage(_args: argparse.Namespace) -> dict[str, Any]:
    warnings: list[str] = []
    local_bytes = _du_bytes(ICLOUD_ROOT)
    if local_bytes is None:
        warnings.append(f"could not compute local usage for: {ICLOUD_ROOT}")

    quota_hint, quota_warnings = _icloud_quota_hint()
    warnings.extend(quota_warnings)
    return _result(
        command="icloud usage",
        ok=True,
        warnings=warnings,
        data={
            "path": str(ICLOUD_ROOT),
            "local": {
                "bytes": local_bytes,
                "human": _human_size(local_bytes),
                "reliability": "exact" if local_bytes is not None else "unavailable",
            },
            "cloud": {
                "bytes": None,
                "human": None,
                "reliability": "unavailable",
                "message": "exact iCloud cloud-space consumed is not exposed by public local macOS APIs",
                "hint": quota_hint,
            },
        },
    )


def cmd_notes_folders(args: argparse.Namespace) -> dict[str, Any]:
    script = """
tell application "Notes"
  set outLines to {}
  repeat with acct in accounts
    repeat with fold in folders of acct
      set end of outLines to ((name of acct as string) & "\t" & (name of fold as string) & "\t" & (count of notes of fold as string))
    end repeat
  end repeat
  set AppleScript's text item delimiters to linefeed
  return outLines as text
end tell
""".strip()
    ok, stdout, stderr = _osascript(script)
    if not ok:
        return _result(
            command="notes folders", ok=False, errors=[stderr or "osascript failed"]
        )

    rows = []
    for line in stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        account_name, folder_name, note_count = parts
        try:
            count = int(note_count)
        except ValueError:
            count = 0
        rows.append(
            {"account": account_name, "folder": folder_name, "note_count": count}
        )

    paged, paging = _paginate(rows, args.offset, args.limit)
    return _result(
        command="notes folders",
        ok=True,
        data={
            "reliability": "exact",
            "folders": paged,
            "folder_count": len(rows),
            "paging": paging,
            "total_notes": sum(item["note_count"] for item in rows),
        },
    )


def cmd_notes_transcription_status(_args: argparse.Namespace) -> dict[str, Any]:
    # Apple Notes does not currently expose first-class transcription status in AppleScript.
    media_dir = NOTES_GROUP_CONTAINER / "Media"
    media_files = 0
    if media_dir.exists():
        for _root, _dirs, files in os.walk(media_dir):
            media_files += len(files)

    return _result(
        command="notes transcription-status",
        ok=True,
        warnings=[
            "Apple Notes transcription status is not exposed as an exact AppleScript field; returning best-effort metadata only"
        ],
        data={
            "transcription_status": "unavailable",
            "reliability": "unavailable",
            "notes_media_path": str(media_dir),
            "notes_media_file_count": media_files,
        },
    )


def _copy_file_with_policy(
    src: Path, dest_dir: Path, overwrite: bool
) -> tuple[bool, str]:
    target = dest_dir / src.name
    if target.exists() and not overwrite:
        stem = target.stem
        suffix = target.suffix
        i = 1
        while target.exists():
            target = dest_dir / f"{stem}-{i}{suffix}"
            i += 1
    try:
        shutil.copy2(src, target)
    except OSError as exc:
        return False, str(exc)
    return True, str(target)


def _is_likely_notes_attachment(path: Path) -> bool:
    name = path.name.lower()
    if name.startswith("notesv") and ".storedata" in name:
        return False
    if any(
        name.endswith(s)
        for s in (
            ".sqlite",
            ".sqlite-wal",
            ".sqlite-shm",
            ".plist",
            ".db",
            ".storedata",
            ".storedata-wal",
            ".storedata-shm",
        )
    ):
        return False
    # Keep extensionless files out to avoid copying internal metadata blobs.
    if path.suffix == "":
        return False
    return True


def _normalize_extensions(values: list[str] | None) -> set[str]:
    if not values:
        return set()
    normalized: set[str] = set()
    for value in values:
        for part in value.split(","):
            ext = part.strip().lower()
            if not ext:
                continue
            if not ext.startswith("."):
                ext = f".{ext}"
            normalized.add(ext)
    return normalized


def cmd_notes_attachments_export(args: argparse.Namespace) -> dict[str, Any]:
    source_dirs = [
        NOTES_GROUP_CONTAINER / "Media",
        NOTES_APP_CONTAINER / "Data/Library/Notes/Media",
        NOTES_APP_CONTAINER / "Data/Library/Notes",
    ]
    sources = [p for p in source_dirs if p.exists()]
    if not sources:
        return _result(
            command="notes attachments export",
            ok=False,
            errors=["notes attachment storage paths not found"],
            data={"checked_paths": [str(p) for p in source_dirs]},
        )

    dest = Path(args.dest).expanduser().resolve()
    dest.mkdir(parents=True, exist_ok=True)
    max_files = args.max_files
    copied: list[str] = []
    skipped = 0
    failed: list[dict[str, str]] = []
    seen = 0
    requested_extensions = _normalize_extensions(args.only_extensions)

    for source in sources:
        for root, _dirs, files in os.walk(source):
            for file_name in files:
                src = Path(root) / file_name
                if not _is_likely_notes_attachment(src):
                    skipped += 1
                    continue
                if (
                    requested_extensions
                    and src.suffix.lower() not in requested_extensions
                ):
                    skipped += 1
                    continue
                seen += 1
                if max_files and len(copied) >= max_files:
                    break
                if args.dry_run:
                    copied.append(str(dest / src.name))
                    continue
                ok, info = _copy_file_with_policy(src, dest, overwrite=args.overwrite)
                if ok:
                    copied.append(info)
                else:
                    failed.append({"source": str(src), "error": info})
            if max_files and len(copied) >= max_files:
                break
        if max_files and len(copied) >= max_files:
            break

    warnings: list[str] = []
    warnings.append(
        "attachments are exported from Notes container storage paths; exact note-to-attachment mapping is not guaranteed"
    )
    if max_files and len(copied) >= max_files:
        warnings.append(f"export limited to max_files={max_files}")

    return _result(
        command="notes attachments export",
        ok=True,
        warnings=warnings,
        data={
            "destination": str(dest),
            "dry_run": bool(args.dry_run),
            "overwrite": bool(args.overwrite),
            "only_extensions": sorted(requested_extensions),
            "sources": [str(p) for p in sources],
            "files_considered": seen,
            "files_skipped": skipped,
            "files_exported": len(copied),
            "exported": copied,
            "failures": failed,
        },
    )


def cmd_notes_usage(_args: argparse.Namespace) -> dict[str, Any]:
    warnings: list[str] = []
    local_bytes_group = _du_bytes(NOTES_GROUP_CONTAINER)
    local_bytes_app = _du_bytes(NOTES_APP_CONTAINER)
    local_bytes = None
    if local_bytes_group is not None or local_bytes_app is not None:
        local_bytes = (local_bytes_group or 0) + (local_bytes_app or 0)
    else:
        warnings.append("could not compute local Notes storage usage")

    return _result(
        command="notes usage",
        ok=True,
        warnings=warnings,
        data={
            "paths": [str(NOTES_GROUP_CONTAINER), str(NOTES_APP_CONTAINER)],
            "local": {
                "bytes": local_bytes,
                "human": _human_size(local_bytes),
                "reliability": "exact" if local_bytes is not None else "unavailable",
            },
            "cloud": {
                "bytes": None,
                "human": None,
                "reliability": "unavailable",
                "message": "exact cloud-space used by Notes is not exposed by public local macOS APIs",
            },
        },
    )


def _music_list_script(entity: str, limit: int) -> str:
    if entity == "playlists":
        return f"""
tell application "Music"
    set outLines to {{}}
    set itemsRef to playlists
    set n to count of itemsRef
    set m to {limit}
    if m > n then set m to n
    repeat with i from 1 to m
        set end of outLines to (name of item i of itemsRef as string)
    end repeat
    set AppleScript's text item delimiters to linefeed
    return outLines as text
end tell
""".strip()

    if entity == "albums":
        return f"""
tell application "Music"
    set outLines to {{}}
    set lib to library playlist 1
    set itemsRef to albums of lib
    set n to count of itemsRef
    set m to {limit}
    if m > n then set m to n
    repeat with i from 1 to m
        set end of outLines to (name of item i of itemsRef as string)
    end repeat
    set AppleScript's text item delimiters to linefeed
    return outLines as text
end tell
""".strip()

    return f"""
tell application "Music"
    set outLines to {{}}
    set lib to library playlist 1
    set itemsRef to artists of lib
    set n to count of itemsRef
    set m to {limit}
    if m > n then set m to n
    repeat with i from 1 to m
        set end of outLines to (name of item i of itemsRef as string)
    end repeat
    set AppleScript's text item delimiters to linefeed
    return outLines as text
end tell
""".strip()


def _music_total_count_script(entity: str) -> str:
    if entity == "playlists":
        return """
tell application "Music"
    return (count of playlists) as string
end tell
""".strip()

    if entity == "albums":
        return """
tell application "Music"
    set lib to library playlist 1
    return (count of albums of lib) as string
end tell
""".strip()

    return """
tell application "Music"
    set lib to library playlist 1
    return (count of artists of lib) as string
end tell
""".strip()


def cmd_music_list(args: argparse.Namespace) -> dict[str, Any]:
    if args.limit <= 0:
        fetch_limit = 100000
    else:
        fetch_limit = args.offset + args.limit
    script = _music_list_script(args.entity, fetch_limit)
    ok, stdout, stderr = _osascript(script)
    if not ok:
        return _result(
            command="music list",
            ok=False,
            errors=[stderr or "osascript failed"],
            data={"entity": args.entity},
        )
    items = [line for line in stdout.splitlines() if line.strip()]
    paged, paging = _paginate(items, args.offset, args.limit)

    total_count = len(items)
    total_ok, total_stdout, _total_stderr = _osascript(
        _music_total_count_script(args.entity)
    )
    if total_ok:
        try:
            total_count = int(total_stdout.strip())
        except ValueError:
            pass
    paging["total"] = total_count

    return _result(
        command="music list",
        ok=True,
        data={
            "entity": args.entity,
            "limit": args.limit,
            "count": total_count,
            "items": paged,
            "paging": paging,
            "reliability": "exact",
        },
    )


def cmd_music_usage(_args: argparse.Namespace) -> dict[str, Any]:
    warnings: list[str] = []
    local_bytes = _du_bytes(MUSIC_LIBRARY)
    if local_bytes is None:
        warnings.append(f"could not compute local usage for: {MUSIC_LIBRARY}")

    return _result(
        command="music usage",
        ok=True,
        warnings=warnings,
        data={
            "path": str(MUSIC_LIBRARY),
            "local": {
                "bytes": local_bytes,
                "human": _human_size(local_bytes),
                "reliability": "exact" if local_bytes is not None else "unavailable",
            },
            "cloud": {
                "bytes": None,
                "human": None,
                "reliability": "unavailable",
                "message": "exact cloud-space used by Music is not exposed by public local macOS APIs",
            },
        },
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="macctl - macOS iCloud/Notes/Music utility"
    )
    parser.add_argument("--version", action="version", version=f"macctl {VERSION}")
    parser.add_argument(
        "--plist",
        default=str(MOBILE_ME_PLIST),
        help="Path to MobileMeAccounts.plist (default: %(default)s)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "text"],
        default="json",
        help="output format (default: %(default)s)",
    )
    parser.add_argument(
        "--verbosity",
        choices=["brief", "verbose"],
        default="brief",
        help="text output detail level (default: %(default)s)",
    )
    parser.add_argument(
        "--color", action="store_true", help="enable ANSI colors in text output"
    )
    parser.add_argument(
        "--no-headers", action="store_true", help="omit text table headers"
    )

    sub = parser.add_subparsers(dest="area", required=True)

    # iCloud
    icloud = sub.add_parser("icloud", help="iCloud-related actions")
    icloud_sub = icloud.add_subparsers(dest="icloud_cmd", required=True)

    p_icloud_enabled = icloud_sub.add_parser(
        "enabled", help="check if iCloud is enabled"
    )
    p_icloud_enabled.set_defaults(func=cmd_icloud_enabled)

    p_icloud_sync = icloud_sub.add_parser(
        "sync-status", help="check iCloud sync status"
    )
    p_icloud_sync.set_defaults(func=cmd_icloud_sync_status)

    p_icloud_docs = icloud_sub.add_parser(
        "documents", help="iCloud Documents operations"
    )
    icloud_docs_sub = p_icloud_docs.add_subparsers(
        dest="icloud_docs_cmd", required=True
    )
    p_icloud_docs_list = icloud_docs_sub.add_parser(
        "list", help="list folders in iCloud/Documents"
    )
    p_icloud_docs_list.add_argument(
        "--offset", type=int, default=0, help="pagination offset"
    )
    p_icloud_docs_list.add_argument(
        "--limit", type=int, default=100, help="pagination limit, 0 for all"
    )
    p_icloud_docs_list.set_defaults(func=cmd_icloud_documents_list)

    p_icloud_docs_ls = icloud_docs_sub.add_parser(
        "ls", help="alias for list folders in iCloud/Documents"
    )
    p_icloud_docs_ls.add_argument(
        "--offset", type=int, default=0, help="pagination offset"
    )
    p_icloud_docs_ls.add_argument(
        "--limit", type=int, default=100, help="pagination limit, 0 for all"
    )
    p_icloud_docs_ls.set_defaults(func=cmd_icloud_documents_list)

    p_icloud_usage = icloud_sub.add_parser(
        "usage", help="get local and cloud space consumed for iCloud"
    )
    p_icloud_usage.set_defaults(func=cmd_icloud_usage)

    # Notes
    notes = sub.add_parser("notes", help="Notes-related actions")
    notes_sub = notes.add_subparsers(dest="notes_cmd", required=True)

    p_notes_folders = notes_sub.add_parser(
        "folders", help="list note folders and note counts"
    )
    p_notes_folders.add_argument(
        "--offset", type=int, default=0, help="pagination offset"
    )
    p_notes_folders.add_argument(
        "--limit", type=int, default=100, help="pagination limit, 0 for all"
    )
    p_notes_folders.set_defaults(func=cmd_notes_folders)

    p_notes_ls = notes_sub.add_parser(
        "ls", help="alias for listing note folders and note counts"
    )
    p_notes_ls.add_argument("--offset", type=int, default=0, help="pagination offset")
    p_notes_ls.add_argument(
        "--limit", type=int, default=100, help="pagination limit, 0 for all"
    )
    p_notes_ls.set_defaults(func=cmd_notes_folders)

    p_notes_transcription = notes_sub.add_parser(
        "transcription-status", help="check note transcription status (best-effort)"
    )
    p_notes_transcription.set_defaults(func=cmd_notes_transcription_status)

    p_notes_attachments = notes_sub.add_parser(
        "attachments", help="notes attachment actions"
    )
    notes_att_sub = p_notes_attachments.add_subparsers(
        dest="notes_att_cmd", required=True
    )

    p_notes_att_export = notes_att_sub.add_parser(
        "export", help="save note attachments to Downloads or custom destination"
    )
    p_notes_att_export.add_argument(
        "--dest",
        default=str(Path.home() / "Downloads"),
        help="destination directory (default: %(default)s)",
    )
    p_notes_att_export.add_argument(
        "--max-files",
        type=int,
        default=0,
        help="max files to export, 0 means unlimited",
    )
    p_notes_att_export.add_argument(
        "--dry-run",
        action="store_true",
        help="show what would be exported without copying files",
    )
    p_notes_att_export.add_argument(
        "--overwrite",
        action="store_true",
        help="overwrite destination files when names conflict",
    )
    p_notes_att_export.add_argument(
        "--only-extensions",
        action="append",
        default=[],
        help="comma-separated or repeated extension filter (example: --only-extensions jpg,png --only-extensions pdf)",
    )
    p_notes_att_export.set_defaults(func=cmd_notes_attachments_export)

    p_notes_usage = notes_sub.add_parser(
        "usage", help="get local and cloud space consumed for Notes"
    )
    p_notes_usage.set_defaults(func=cmd_notes_usage)

    # Music
    music = sub.add_parser("music", help="Music-related actions")
    music_sub = music.add_subparsers(dest="music_cmd", required=True)

    p_music_list = music_sub.add_parser(
        "list", help="list artists, albums, or playlists"
    )
    p_music_list.add_argument(
        "--entity",
        choices=["artists", "albums", "playlists"],
        default="artists",
        help="entity type to list",
    )
    p_music_list.add_argument(
        "--limit", type=int, default=100, help="max rows to return"
    )
    p_music_list.add_argument("--offset", type=int, default=0, help="pagination offset")
    p_music_list.set_defaults(func=cmd_music_list)

    p_music_ls = music_sub.add_parser(
        "ls", help="alias for listing artists, albums, or playlists"
    )
    p_music_ls.add_argument(
        "--entity",
        choices=["artists", "albums", "playlists"],
        default="artists",
        help="entity type to list",
    )
    p_music_ls.add_argument("--limit", type=int, default=100, help="max rows to return")
    p_music_ls.add_argument("--offset", type=int, default=0, help="pagination offset")
    p_music_ls.set_defaults(func=cmd_music_list)

    p_music_usage = music_sub.add_parser(
        "usage", help="get local and cloud space consumed for Music"
    )
    p_music_usage.set_defaults(func=cmd_music_usage)

    return parser


def main() -> int:
    args = build_parser().parse_args()
    payload = args.func(args)
    if args.format == "text":
        return _print_text(
            payload,
            args.verbosity,
            color=_supports_color(args.color),
            no_headers=bool(args.no_headers),
        )
    return _print_json(payload)


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6.0"]
# ///
"""Generate Brewfile(s) from .dependencies.yml.

This script renders canonical Brewfile(s) from a YAML source-of-truth manifest.
It extends the devel project pattern with:
- tier support (0-4)
- split mode (separate formula+tap vs cask outputs)
- optional tier filtering
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

SUPPORTED_TYPES = ("tap", "brew", "cask", "mas", "whalebrew", "vscode")
SECTION_ORDER = ("tap", "brew", "cask", "mas", "whalebrew", "vscode")
FORMULA_TYPES = ("tap", "brew")
CASK_TYPES = ("cask",)


@dataclass(frozen=True)
class Entry:
    type: str
    name: str
    required: bool
    description: str
    category: str
    tier: int
    evidence: str
    args: dict[str, Any] = field(default_factory=dict)

    @property
    def dedupe_key(self) -> tuple[str, str]:
        return (self.type, self.name)


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Manifest not found: {path}") from exc
    except yaml.YAMLError as exc:
        raise SystemExit(f"Invalid YAML in {path}: {exc}") from exc

    if not isinstance(raw, dict):
        raise SystemExit(f"Manifest must be a mapping at top-level: {path}")
    return raw


def parse_entries(raw: dict[str, Any]) -> list[Entry]:
    entries = raw.get("entries")
    if not isinstance(entries, list) or not entries:
        raise SystemExit("Manifest must define a non-empty 'entries' list")

    parsed: list[Entry] = []
    seen: set[tuple[str, str]] = set()

    for idx, item in enumerate(entries, start=1):
        if not isinstance(item, dict):
            raise SystemExit(f"entries[{idx}] must be a mapping")

        entry_type = item.get("type")
        name = item.get("name")
        required = item.get("required", True)
        description = item.get("description", "").strip()
        category = str(item.get("category", "general")).strip()
        tier = item.get("tier", 2)
        evidence = str(item.get("evidence", "")).strip()
        args = item.get("args", {})

        if entry_type not in SUPPORTED_TYPES:
            raise SystemExit(
                f"entries[{idx}] has unsupported type '{entry_type}'. "
                f"Supported: {', '.join(SUPPORTED_TYPES)}"
            )
        if not isinstance(name, str) or not name.strip():
            raise SystemExit(f"entries[{idx}] must include non-empty string 'name'")
        if not isinstance(required, bool):
            raise SystemExit(f"entries[{idx}] field 'required' must be boolean")
        if not isinstance(tier, int) or tier < 0 or tier > 4:
            raise SystemExit(
                f"entries[{idx}] field 'tier' must be integer 0-4, got: {tier}"
            )
        if not isinstance(args, dict):
            raise SystemExit(
                f"entries[{idx}] field 'args' must be a mapping when present"
            )

        entry = Entry(
            type=entry_type,
            name=name.strip(),
            required=required,
            description=description,
            category=category,
            tier=tier,
            evidence=evidence,
            args=args if args else {},
        )

        if entry.dedupe_key in seen:
            raise SystemExit(
                f"Duplicate entry detected for type/name: {entry.type}/{entry.name}"
            )
        seen.add(entry.dedupe_key)
        parsed.append(entry)

    return parsed


def format_args(entry_type: str, args: dict[str, Any]) -> str:
    if not args:
        return ""

    allowed_by_type = {
        "brew": {"restart_service", "link", "conflicts_with", "start_service"},
        "cask": {"greedy"},
        "mas": {"id"},
        "tap": {"clone_target", "force_auto_update"},
        "whalebrew": set(),
        "vscode": set(),
    }

    allowed = allowed_by_type.get(entry_type, set())
    unknown = sorted(set(args) - allowed)
    if unknown:
        raise SystemExit(
            f"Unsupported args for type '{entry_type}': {', '.join(unknown)}"
        )

    if entry_type == "mas":
        if "id" not in args:
            raise SystemExit("mas entries require args.id")
        return f", id: {int(args['id'])}"

    rendered_items: list[str] = []
    for key in sorted(args):
        value = args[key]
        if isinstance(value, bool):
            rendered_items.append(f"{key}: {str(value).lower()}")
        elif isinstance(value, int):
            rendered_items.append(f"{key}: {value}")
        elif isinstance(value, str):
            rendered_items.append(f"{key}: {json.dumps(value)}")
        elif isinstance(value, list):
            rendered_items.append(f"{key}: {json.dumps(value)}")
        else:
            raise SystemExit(
                f"Unsupported arg value type for {key}: {type(value).__name__}"
            )

    return ", " + ", ".join(rendered_items)


def stanza_line(entry: Entry) -> str:
    args_suffix = format_args(entry.type, entry.args)
    return f'{entry.type} "{entry.name}"{args_suffix}'


def build_output(
    entries: list[Entry],
    manifest_path: Path,
    type_filter: set[str] | None = None,
) -> str:
    if type_filter:
        entries = [e for e in entries if e.type in type_filter]

    grouped: dict[str, dict[bool, list[Entry]]] = defaultdict(
        lambda: {True: [], False: []}
    )

    for entry in entries:
        grouped[entry.type][entry.required].append(entry)

    for entry_type in grouped:
        grouped[entry_type][True].sort(key=lambda item: (item.tier, item.name.lower()))
        grouped[entry_type][False].sort(key=lambda item: (item.tier, item.name.lower()))

    lines: list[str] = []
    lines.append("# Generated file. Do not edit directly.")
    lines.append(f"# Source of truth: {manifest_path.name}")
    lines.append("# Regenerate with: make brewfile")
    lines.append("")

    for entry_type in SECTION_ORDER:
        if entry_type not in grouped:
            continue

        required_entries = grouped[entry_type][True]
        optional_entries = grouped[entry_type][False]
        if not required_entries and not optional_entries:
            continue

        lines.append(f"# {'═' * 72}")
        lines.append(f"# {entry_type} entries")
        lines.append(f"# {'═' * 72}")
        lines.append("")

        if required_entries:
            lines.append("# ── Required ──────────────────────────────────────────────────────────")
            for entry in required_entries:
                if entry.description:
                    lines.append(f"# {entry.description}")
                lines.append(stanza_line(entry))
            lines.append("")

        if optional_entries:
            lines.append("# ── Optional ──────────────────────────────────────────────────────────")
            current_tier: int | None = None
            for entry in optional_entries:
                if entry.tier != current_tier:
                    current_tier = entry.tier
                    lines.append(f"# tier {current_tier}")
                if entry.description:
                    lines.append(f"# {entry.description}")
                lines.append(stanza_line(entry))
            lines.append("")

    if lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + "\n"


def check_brew_bundle(file_path: Path) -> bool:
    proc = subprocess.run(
        ["brew", "bundle", "list", "--file", str(file_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        print(f"⚠️  brew bundle validation warning:\n{proc.stderr.strip()}", file=sys.stderr)
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Brewfile(s) from YAML manifest"
    )
    parser.add_argument(
        "--manifest",
        default=".dependencies.yml",
        type=Path,
        help="Path to dependency YAML manifest",
    )
    parser.add_argument(
        "--output",
        default="data/Brewfile",
        type=Path,
        help="Path to generated Brewfile (formula+taps)",
    )
    parser.add_argument(
        "--cask-output",
        default="data/Brewfile.cask",
        type=Path,
        help="Path to generated cask Brewfile",
    )
    parser.add_argument(
        "--split",
        action="store_true",
        default=True,
        help="Split output into formula and cask files (default: true)",
    )
    parser.add_argument(
        "--no-split",
        action="store_true",
        help="Write all entries to a single output file",
    )
    parser.add_argument(
        "--max-tier",
        type=int,
        default=4,
        choices=range(0, 5),
        help="Maximum tier to include (0-4, default: 4)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Do not write file; fail if output differs from current file",
    )
    parser.add_argument(
        "--skip-brew-validate",
        action="store_true",
        help="Skip 'brew bundle list' syntax validation",
    )

    args = parser.parse_args()

    raw = load_manifest(args.manifest)
    all_entries = parse_entries(raw)

    # Apply tier filter
    entries = [e for e in all_entries if e.tier <= args.max_tier]

    split = args.split and not args.no_split

    if split:
        formula_rendered = build_output(entries, args.manifest, type_filter=set(FORMULA_TYPES))
        cask_rendered = build_output(entries, args.manifest, type_filter=set(CASK_TYPES))

        if args.check:
            ok = True
            for path, rendered in [
                (args.output, formula_rendered),
                (args.cask_output, cask_rendered),
            ]:
                current = ""
                if path.exists():
                    current = path.read_text(encoding="utf-8")
                if current != rendered:
                    print(f"Out of sync: {path}", file=sys.stderr)
                    ok = False
            if not ok:
                raise SystemExit(
                    "Brewfile(s) out of sync with manifest. Run: make brewfile"
                )
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.cask_output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(formula_rendered, encoding="utf-8")
            args.cask_output.write_text(cask_rendered, encoding="utf-8")
            formula_count = len([e for e in entries if e.type in FORMULA_TYPES])
            cask_count = len([e for e in entries if e.type in CASK_TYPES])
            print(f"Wrote {args.output} ({formula_count} entries)")
            print(f"Wrote {args.cask_output} ({cask_count} entries)")

        if not args.skip_brew_validate:
            check_brew_bundle(args.output)
            check_brew_bundle(args.cask_output)
    else:
        rendered = build_output(entries, args.manifest)

        if args.check:
            current = ""
            if args.output.exists():
                current = args.output.read_text(encoding="utf-8")
            if current != rendered:
                raise SystemExit(
                    "Brewfile is out of sync with manifest. Run: make brewfile"
                )
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered, encoding="utf-8")
            print(f"Wrote {args.output} ({len(entries)} entries)")

        if not args.skip_brew_validate:
            check_brew_bundle(args.output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

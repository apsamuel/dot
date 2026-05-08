#!/usr/bin/env python3

import argparse
import os
import plistlib


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Show iCloud account and service enablement from MobileMeAccounts.plist."
    )
    parser.add_argument(
        "--plist",
        default=os.path.expanduser("~/Library/Preferences/MobileMeAccounts.plist"),
        help="Path to MobileMeAccounts.plist (default: %(default)s)",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        with open(args.plist, "rb") as handle:
            data = plistlib.load(handle)
    except FileNotFoundError:
        print("No iCloud account found")
        return 1

    accounts = data.get("Accounts", [])
    for account in accounts:
        print(f"Apple ID: {account.get('AccountID')}")
        for service in account.get("Services", []):
            print(f"  {service.get('Name')}: enabled={service.get('Enabled', False)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

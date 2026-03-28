#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import subprocess


def get_version():
    try:
        result = subprocess.run(
            ["utmctl", "version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        version_info = result.stdout.strip()
        return version_info
    except subprocess.CalledProcessError as e:
        print(f"Error getting UTM version: {e.stderr}")
        return "Unknown Version"

def main():
    parser = argparse.ArgumentParser(description='UTM Improved Control Script')
    parser.add_argument(
        "--version",
        action="version",
        version=f"UTM Control Script 1.0 (UTM Version: {get_version()})",
        # type=str
    )

    args = parser.parse_args()
    # print("UTM Control Script is running...")



main()
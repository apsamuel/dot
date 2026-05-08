#!/usr/bin/env bash

# shellcheck source=/dev/null
# shellcheck shell=bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	echo "Usage: import-git-org.sh"
	echo "Reads GITHUB_HOST and GITHUB_ORG from environment and reports import target."
	exit 0
fi

github_host="${GITHUB_HOST:-github.com}"
github_org="${GITHUB_ORG:-my-org}"

echo "Importing repositories from GitHub organization: ${github_org} on ${github_host}"
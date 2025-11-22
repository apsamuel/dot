# shellcheck source=/dev/null
# shellcheck shell=bash

github_host="${GITHUB_HOST:-github.com}"
github_org="${GITHUB_ORG:-my-org}"

echo "Importing repositories from GitHub organization: ${github_org} on ${github_host}"
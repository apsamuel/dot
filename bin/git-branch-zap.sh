#!/usr/bin/env bash
# This script deletes a local and remote Git branch.
# Usage: git-branch-zap.sh <branch-name>
# Arguments:
#   <branch-name> - The name of the branch to delete.
# Actions:
#   - Deletes the specified branch locally using 'git branch -d'.
#   - Deletes the specified branch from the remote 'origin' using 'git push origin --delete'.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	echo "Usage: git-branch-zap.sh <branch-name>"
	echo "Delete a local and remote branch named <branch-name>."
	exit 0
fi

branch="${1}"

if [[ -z "$branch" ]]; then
	echo "Error: branch name is required"
	echo "Usage: git-branch-zap.sh <branch-name>"
	exit 1
fi

echo "deleting ${branch}"
git branch -d "${branch}"
git push origin --delete "${branch}"

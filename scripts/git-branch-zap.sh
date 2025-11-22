#!/usr/bin/env bash
# This script deletes a local and remote Git branch.
# Usage: git-branch-zap.sh <branch-name>
# Arguments:
#   <branch-name> - The name of the branch to delete.
# Actions:
#   - Deletes the specified branch locally using 'git branch -d'.
#   - Deletes the specified branch from the remote 'origin' using 'git push origin --delete'.
branch="${1}"
echo "deleting ${branch}"
git branch -d "${branch}"
git push origin --delete "${branch}"

#!/usr/bin/env bash
branch="${1}"
echo "deleting ${branch}"
git branch -d ${branch}
git push origin --delete ${branch}

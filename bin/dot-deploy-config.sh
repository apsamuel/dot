#!/usr/local/bin/env bash

if [[ -z "${ICLOUD}" ]]; then
    echo "ICLOUD is not set"
    exit 1
fi

echo "deploying config files to ${ICLOUD}"
cp -v data/zsh.yaml "${ICLOUD}"/dot/shell/zsh/zsh.yaml
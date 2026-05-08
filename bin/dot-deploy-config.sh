#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: dot-deploy-config.sh"
    echo "Copy data/zsh.yaml into the iCloud dot shell config path."
    exit 0
fi

if [[ -z "${ICLOUD}" ]]; then
    echo "ICLOUD is not set"
    exit 1
fi

echo "deploying config files to ${ICLOUD}"
cp -v data/zsh.yaml "${ICLOUD}"/dot/shell/zsh/zsh.yaml
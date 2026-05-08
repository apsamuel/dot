#!/usr/bin/env bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: dot-deploy-rc.sh"
    echo "Copy zshrc into the iCloud dot shell rc path."
    exit 0
fi

if [[ -z "${ICLOUD}" ]]; then
    echo "ICLOUD is not set"
    exit 1
fi

echo "deploying rc files to ${ICLOUD}"
cp -v zshrc "${ICLOUD}"/dot/shell/zsh/rc
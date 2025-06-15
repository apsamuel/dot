#!/usr/local/bin/env bash

if [[ -z "${ICLOUD}" ]]; then
    echo "ICLOUD is not set"
    exit 1
fi

echo "deploying rc files to ${ICLOUD}"
cp -v zshrc "${ICLOUD}"/dot/shell/zsh/rc
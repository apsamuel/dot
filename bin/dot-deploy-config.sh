#!/usr/local/bin/env bash

if [[ -z "${ICLOUD}" ]]; then
    echo "ICLOUD is not set"
    exit 1
fi

echo "deploying config files to ${ICLOUD}"
cp -v config/data.json "${ICLOUD}"/dot/data.json
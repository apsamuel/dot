#shellcheck shell=bash
#% author: Aaron Samuel
#% description: plumbing functions for the dotfiles ecosystem, plumbing commands are prefixed with __ in this ecosystem
# shellcheck shell=bash
# shellcheck source=/dev/null

CURRENT_FILE="$(basename "${BASH_SOURCE[0]}")"
if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${CURRENT_FILE}"
fi

function __load_configuration () {
  true
}

function __load_secrets () {
    local secret_keys=()
    # declare -A secrets
    while IFS=' ' read -r -d ' ' secret_key; do
        secret_keys+=("${secret_key}")
    done < <(jq -r '. | keys | .[]' "${ICLOUD}"/dot/secrets.json | xargs) # -print0
    touch "${TMPDIR}"/.secrets
    if [[ ${#secret_keys[@]} -gt 0  ]]; then
        echo "#!/bin/bash" > "$TMPDIR"/.secrets
    fi
    for secret_key in "${secret_keys[@]}"; do
        secret_value="$(jq --arg secret_key "${secret_key}" -r '.[$secret_key]' "${ICLOUD}"/dot/secrets.json)"
        echo "${secret_key}=${secret_value}" >> "$TMPDIR"/.secrets
    done
    if [[ -f "$TMPDIR"/.secrets ]]; then
        source "$TMPDIR"/.secrets
        rm -f "$TMPDIR"/.secrets
    else
        echo "no secrets file found"
        exit 1
    fi
    export BOOTSTRAP_SECRETS_LOADED=1
    echo "🛻  loaded ${#secret_keys[@]} secrets"
}

#shellcheck shell=bash
#% note: this runs first!
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207
DOT_DEBUG="${DOT_DEBUG:-0}"
# DOT_DIRECTORY=$(dirname "$0")
# DOT_LIBRARY=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi


function __load_secrets__ () {
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
    fi
}

function __mask_secrets__ () {
    input_data=("${@}")
    safe_word="**************"
    blocked_words=(
        SuperSecretPassword
    )

    [[ -p /dev/stdin ]] && { \
        mapfile -t -O ${#input_data[@]} input_data; set -- "${input_data[@]}"; \
    }

    secret_keys=(
        $(
            jq -r '. | keys | .[]' "$ICLOUD"/dot/secrets.json | xargs
        )
    )


    # if secrets length is greater than 0, write to /tmp/.secrets
    if [[ ${#secret_keys[@]} -gt 0  ]]; then
        # echo $TMPDIR
        touch "${TMPDIR}"/.secrets
        echo "#!/bin/bash" > "$TMPDIR"/.secrets
    fi


    declare -A secrets
    declare secret_word_filter
    declare blocked_word_filter

    secret_word_filter="SuperSecretPassword"
    blocked_word_filter="SuperSecretPassword"

    # rebuild secrets file & associative array
    for secret_key in "${secret_keys[@]}"; do
        secrets["$secret_key"]="$(jq --arg secret_key "${secret_key}" -r '.[$secret_key]' "$ICLOUD"/dot/secrets.json)"
        echo "${secret_key}=${secrets[$secret_key]}" >> "$TMPDIR"/.secrets
    done

    # replace secrets with safe_word value
    for secret_key in "${secret_keys[@]}"; do
        # append to secret_word_filter
        secret_word_filter="${secret_word_filter}|${secrets[$secret_key]}"
    done

    # replace blocked words with safe_word value
    for blocked_word in "${blocked_words[@]}"; do
        # append to blocked_word_filter
        blocked_word_filter="${blocked_word_filter}|${blocked_word}"
    done

    # use sed

    #echo "${input_data[*]}"
    for kv in "${input_data[@]}"; do
        echo "${kv}" | sed -r "s/($blocked_word_filter)/${safe_word}/g" | sed -r "s/($secret_word_filter)/${safe_word}/g"
        # print -P -- "${BG[000]}"
    done

    rm -f "$TMPDIR"/.secrets
}

#!/usr/local/bin/bash
# author: github.com/apsamuel
# description: mask secrets in outputs
# 🕵️ ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

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
        jq -r '. | keys | .[]' "$HOME"/.dot/data/secrets.json | xargs
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
    secrets["$secret_key"]="$(jq --arg secret_key "${secret_key}" -r '.[$secret_key]' "$HOME"/.dot/data/secrets.json)"
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
#% author: Aaron Samuel
#% description: exports SSH_KEYS for future operations
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207

declare -a SSH_KEYS

# prepare SSH keys for export
if [[ -d "$HOME"/.ssh ]]; then
    files=("$HOME"/.ssh/*)
    for file in "${files[@]}"; do
        if [[ "$file" =~ (config|deprecated|.*pub|environment.*|known_hosts.*) ]]; then
            continue
        fi
        base=$(basename "$file")
        SSH_KEYS+=("$base")
    done
fi

export SSH_KEYS
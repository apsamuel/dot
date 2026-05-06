#% author: Aaron Samuel
#% description: foundational functionality leveraged in shell entrypoints, required (early) for using the dotfiles project
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# we need to source the mac.sh file first
source "${DOT_LIBRARY}"/000-c-mac.sh

function getShellName () {
    currentShell="$(command ps -p $$ -ocomm=)"
    echo "$currentShell"
}

function getSecureString () {
    len="${1:-15}"
    secureString="$(pwgen -n -y "${len}" 1)"
    echo "$secureString"
}


function getProcessorCores() {
    sysctl -n machdep.cpu.core_count
}

function getProcessorBrand() {
    sysctl -n machdep.cpu.brand_string
}

function loadZshOptions() {
    # if $ICLOUD is inaccessible, fall back to the .dot directory copy
    if [[ -f "$ICLOUD"/dot/shell/zsh/zsh.yaml ]]; then
        ZSH_OPTIONS=(
            $(
                yq '.options[]' "$ICLOUD"/dot/shell/zsh/zsh.yaml | xargs
            )
        )
    else
        ZSH_OPTIONS=(
            $(
                yq '.options[]' "$DOT_DIRECTORY"/data/zsh.yaml | xargs
            )
        )
    fi

    export ZSH_OPTIONS

    for opt in "${ZSH_OPTIONS[@]}"; do
        if [[ ! "${DOT_DEBUG}x" == "x" && "${DOT_DEBUG}" == true ]]; then
            echo "set option: $opt"
        fi
        setopt "${opt}"
    done
}

function loadZlib() {
    if [ -d "$DOT_LIBS_DIR" ]; then
        for lib in $(find "${DOT_LIBS_DIR}" -maxdepth 1 -type f -name "[0-9][0-9][0-9]-*-*.sh" | sort -d); do
            if [[ ! "${DOT_DEBUG}x" == "x" && "${DOT_DEBUG}" == true ]]; then
                echo "load source: $lib"
            fi
            . "$lib" || true
        done
    else
        echo "Warning: DOT_LIBS_DIR not found: $DOT_LIBS_DIR"
    fi
}

function loadSecrets () {
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

# loadUserSecrets: loads secrets from $ICLOUD/dot/secrets.json into the current
# shell environment. Each JSON key is exported as an environment variable and
# the key names are collected in DOT_SECRET_KEYS. The intermediate file is
# written to $TMPDIR and removed after sourcing so secrets never persist on disk.
function loadUserSecrets () {
    local secrets_file="${ICLOUD}/dot/secrets.json"
    if [[ ! -d "${ICLOUD}/dot" || ! -f "${secrets_file}" ]]; then
        return 0
    fi

    declare -A secrets
    local secretKeys=()
    secretKeys=(
        $(
            jq -r '. | keys | .[]' "${secrets_file}" | xargs
        )
    )
    export DOT_SECRET_KEYS=("${secretKeys[@]}")

    if [[ ${#secretKeys[@]} -gt 0 ]]; then
        touch "${TMPDIR}"/.secrets
        echo "#!/bin/bash" > "${TMPDIR}"/.secrets
    fi

    for secretKey in "${secretKeys[@]}"; do
        secrets[$secretKey]="$(jq --arg secretKey "${secretKey}" -r '.[$secretKey]' "${secrets_file}")"
        echo "export ${secretKey}=${secrets[$secretKey]}" >> "${TMPDIR}"/.secrets
    done

    if [[ -f "${TMPDIR}"/.secrets ]]; then
        . "${TMPDIR}"/.secrets
        rm -f "${TMPDIR}"/.secrets
    fi
}

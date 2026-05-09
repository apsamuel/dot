# shellcheck shell=bash
## TODO: move node setup to DOT_MODULES file


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

if [[ "${DOT_DISABLE_NODE}" -eq 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "node setup is disabled"
    fi
    return
fi

N_PREFIX="${HOME}"/.node-$(arch)
export N_PREFIX
export PATH="${N_PREFIX}/bin:${PATH}"

# resolve desired node version: env override → local zsh.yaml → iCloud zsh.yaml → default
desired_version="${NODE_VERSION:-}"
if [[ -z "${desired_version}" ]] && command -v yq >/dev/null 2>&1; then
    for _cfg in "${DOT_SHELL_DATA}" "${DOT_DIRECTORY}/data/zsh.yaml" "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/dot/shell/zsh/zsh.yaml"; do
        [[ -n "${_cfg}" && -f "${_cfg}" ]] || continue
        desired_version="$(yq -r '.languages.node.version // ""' "${_cfg}" 2>/dev/null)"
        [[ -n "${desired_version}" && "${desired_version}" != "null" ]] && break
    done
    unset _cfg
fi
desired_version="${desired_version:-24.15.0}"

NODE_URL="https://nodejs.org/dist/v${desired_version}/node-v${desired_version}-darwin-x64.tar.xz"
if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
    NODE_URL="https://nodejs.org/dist/v${desired_version}/node-v${desired_version}-darwin-arm64.tar.xz"
fi

# ensure desired node version is active via n
if command -v n >/dev/null 2>&1; then
    mkdir -p "${N_PREFIX}"
    current_node="$(node --version 2>/dev/null | sed 's/^v//')"
    if [[ "${current_node}" != "${desired_version}" ]]; then
        if [[ "${DOT_DEBUG}" -eq 1 ]]; then
            echo "switching node to ${desired_version} via n (current: ${current_node:-none})"
        fi
        n "${desired_version}" >/dev/null 2>&1 || echo "⚠️  failed to activate node ${desired_version} via n"
    fi
fi

# if node is installed via homebrew, update the PATH and LDFLAGS and CPPFLAGS to include the node binary
if brew list | grep node >/dev/null 2>&1 ; then
    node=$(brew list |grep node | sort -n | tail -1)
    # only update the path to node if it is not already set
    if [[ "$PATH" != *"/usr/local/opt/${node}/bin"* ]]; then
        # echo "Updating PATH to include /usr/local/opt/${node}/bin"
        export PATH="/usr/local/opt/${node}/bin:${PATH}"
    fi

    # export LDFLAGS="${LDFLAGS} -L/usr/local/opt/${node}/lib"
    # export CPPFLAGS="${CPPFLAGS} -I/usr/local/opt/${node}/include"

    # if LDFLAGS does not contain /usr/local/opt/${node}/lib
    if [[ "$LDFLAGS" != *"/usr/local/opt/${node}/lib"* ]]; then
        export LDFLAGS="${LDFLAGS} -L/usr/local/opt/${node}/lib"
    fi

    # if CPPFLAGS does not contain /usr/local/opt/${node}/include
    if [[ "$CPPFLAGS" != *"/usr/local/opt/${node}/include"* ]]; then
        export CPPFLAGS="${CPPFLAGS} -I/usr/local/opt/${node}/include"
    fi

fi

function getNodeJS () {
    # download node into a temporary DOT_DIRECTORY
    mkdir -p /tmp/node
    echo "Downloading node from $NODE_URL"
    curl -L "$NODE_URL" | tar -xJ --strip-components=1 -C /tmp/node
}

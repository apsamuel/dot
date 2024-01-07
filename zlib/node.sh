# shellcheck shell=bash
## TODO: move node setup to library file
#export NODE_VERSION=16.13.2
#export N_PREFIX=${HOME}/devops/node
#NODE_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
#export NODE_OS
#export NODE_ARCH=x64
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

N_PREFIX="${HOME}"/.node-$(arch)

NODE_VERSION="${NODE_VERSION:-20.10.0}"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-x64.tar.xz"

if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
    NODE_VERSION="${NODE_VERSION:-20.10.0}"
    NODE_URL="${NODE_URL:-https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.xz}"
fi

function node::install () {
    # download node into a temporary directory
    mkdir -p /tmp/node
    echo "Downloading node from $NODE_URL"
    curl -L "$NODE_URL" | tar -xJ --strip-components=1 -C /tmp/node
}

export N_PREFIX
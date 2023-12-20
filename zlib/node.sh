# shellcheck shell=bash

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
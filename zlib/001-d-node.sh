# shellcheck shell=bash
## TODO: move node setup to DOT_LIBRARY file
#export NODE_VERSION=16.13.2
#export N_PREFIX=${HOME}/devops/node
#NODE_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
#export NODE_OS
#export NODE_ARCH=x64
# DOT_DEBUG="${DOT_DEBUG:-0}"
# DOT_DIRECTORY=$(dirname "$0")
# DOT_LIBRARY=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

N_PREFIX="${HOME}"/.node-$(arch)

NODE_VERSION="${NODE_VERSION:-20.10.0}"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-x64.tar.xz"

if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
    NODE_VERSION="${NODE_VERSION:-20.10.0}"
    NODE_URL="${NODE_URL:-https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.xz}"
fi

# update the path to include the latest node version
if brew list | grep node >/dev/null 2>&1 ; then
    node=$(brew list |grep node | sort -n | tail -1)
    export PATH="/usr/local/opt/${node}/bin:${PATH}"
    export LDFLAGS="${LDFLAGS} -L/usr/local/opt/${node}/lib"
    export CPPFLAGS="${CPPFLAGS} -I/usr/local/opt/${node}/include"
fi

function node::tar::install () {
    # download node into a temporary DOT_DIRECTORY
    mkdir -p /tmp/node
    echo "Downloading node from $NODE_URL"
    curl -L "$NODE_URL" | tar -xJ --strip-components=1 -C /tmp/node
}

export N_PREFIX
# shellcheck shell=bash
## TODO: move node setup to DOT_LIBRARY file


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

NODE_VERSION="${NODE_VERSION:-20.10.0}"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-x64.tar.xz"

if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
    NODE_VERSION="${NODE_VERSION:-20.10.0}"
    NODE_URL="${NODE_URL:-https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.xz}"
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

function node::tar::install () {
    # download node into a temporary DOT_DIRECTORY
    mkdir -p /tmp/node
    echo "Downloading node from $NODE_URL"
    curl -L "$NODE_URL" | tar -xJ --strip-components=1 -C /tmp/node
}

export N_PREFIX
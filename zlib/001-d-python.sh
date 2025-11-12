# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

## we use uv to create python virtual environments by default
## depending on the current shell arch, we should load the correct python version
## we need to source the correct python environment on startup
## venvs are stored in ~/.venvs/<python-version>-<arch>-<category>
## if a venv does not exist, it will be created on demand
desired_version="3.11"
arch="$(uname -m)"


## does the ~/.venv directory exist?
if [[ ! -d "${HOME}/.venv" ]]; then
    mkdir -p "${HOME}/.venv"
fi

# check for our base venv and create it if it does not exist, using uv
venv_name="${desired_version}-${arch}-base"
if [[ ! -d "${HOME}/.venv/${venv_name}" ]]; then
    pushd "${HOME}/.venv" || exit 1
    echo "creating python venv: ${venv_name}"
    uv venv --seed --python "${desired_version}" "${venv_name}"
    popd || exit 1
fi

# now we can source the venv
source "${HOME}/.venv/${venv_name}/bin/activate"
# export PATH
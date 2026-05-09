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

# resolve desired python version: env override → local zsh.yaml → iCloud zsh.yaml → default
desired_version="${PYTHON_VERSION:-}"
if [[ -z "${desired_version}" ]] && command -v yq >/dev/null 2>&1; then
    for _cfg in "${DOT_SHELL_DATA}" "${DOT_DIRECTORY}/data/zsh.yaml" "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/dot/shell/zsh/zsh.yaml"; do
        [[ -n "${_cfg}" && -f "${_cfg}" ]] || continue
        desired_version="$(yq -r '.languages.python.version // ""' "${_cfg}" 2>/dev/null)"
        [[ -n "${desired_version}" && "${desired_version}" != "null" ]] && break
    done
    unset _cfg
fi
desired_version="${desired_version:-3.11}"
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

# by default, we want to source the base venv on startup — but never clobber
# a venv that the user (or a parent shell / direnv) has already activated.
#   - VIRTUAL_ENV is set by `activate` scripts (venv/virtualenv/uv) and direnv layouts
#   - DOT_PY_FORCE_BASE=1 forces re-activation of the base venv anyway
if [[ -n "${VIRTUAL_ENV}" && -x "${VIRTUAL_ENV}/bin/python" && "${DOT_PY_FORCE_BASE:-0}" -ne 1 ]]; then
    if [[ "${DOT_DEBUG}" -eq 1 ]]; then
        echo "python venv already active: ${VIRTUAL_ENV} (skipping base venv activation)"
    fi
else
    source "${HOME}/.venv/${venv_name}/bin/activate"
fi

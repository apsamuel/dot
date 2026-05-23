# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

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
    if ! command -v uv >/dev/null 2>&1; then
        dot::static::logging::error "uv not found — cannot create python venv"
        return 1
    fi
    pushd "${HOME}/.venv" || return 1
    dot::static::logging::info "creating python venv: ${venv_name}"
    if ! uv venv --seed --python "${desired_version}" "${venv_name}"; then
        dot::static::logging::error "failed to create python venv: ${venv_name}"
        popd || return 1
        return 1
    fi
    popd || return 1
fi

# by default, we want to source the base venv on startup — but never clobber
# a venv that the user (or a parent shell / direnv) has already activated.
#   - VIRTUAL_ENV is set by `activate` scripts (venv/virtualenv/uv) and direnv layouts
#   - DOT_PY_FORCE_BASE=1 forces re-activation of the base venv anyway
if [[ -n "${VIRTUAL_ENV}" && -x "${VIRTUAL_ENV}/bin/python" && "${DOT_PY_FORCE_BASE:-0}" -ne 1 ]]; then
    dot::static::logging::debug "python venv already active: ${VIRTUAL_ENV} (skipping base venv activation)"
else
    if [[ -f "${HOME}/.venv/${venv_name}/bin/activate" ]]; then
        source "${HOME}/.venv/${venv_name}/bin/activate"
    else
        dot::static::logging::warn "base venv activate script missing: ${HOME}/.venv/${venv_name}/bin/activate"
    fi
fi

# pyenv — create a python virtual environment using uv (preferred) or venv module
#
# Usage:
#   pyenv [OPTIONS]
#
# Options:
#   -p, --path <dir>      Parent directory for the venv (default: current directory)
#   -n, --name <name>     Name of the venv directory (default: .venv; always prefixed with '.')
#   -P, --python <ver>    Python version or path (default: current $desired_version or 3.11)
#   -s, --seed            Seed the venv with pip/setuptools (uv: --seed, venv: ensurepip)
#   -f, --force           Recreate the venv if it already exists
#   -a, --activate        Activate the venv after creation
#   -d, --discover-requirements  Find and install requirements.txt from --path root
#   -r, --requirements <file>    Install from a specific requirements file
#   --packages "pkg1 pkg2 ..."   Install individual packages (continues on failure)
#   -h, --help            Show this help message
#
dot::python::env() {
    local venv_parent=""
    local venv_name=".venv"
    local python_ver="${desired_version:-3.11}"
    local seed=0
    local force=0
    local activate=0
    local discover_requirements=0
    local requirements_file=""
    local packages=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--path)
                [[ -n "${2:-}" ]] || { echo "dot::python::env: --path requires an argument" >&2; return 1; }
                venv_parent="$2"; shift 2 ;;
            -n|--name)
                [[ -n "${2:-}" ]] || { echo "dot::python::env: --name requires an argument" >&2; return 1; }
                venv_name="$2"; shift 2 ;;
            -P|--python)
                [[ -n "${2:-}" ]] || { echo "dot::python::env: --python requires an argument" >&2; return 1; }
                python_ver="$2"; shift 2 ;;
            -s|--seed)   seed=1; shift ;;
            -f|--force)  force=1; shift ;;
            -a|--activate) activate=1; shift ;;
            -d|--discover-requirements) discover_requirements=1; shift ;;
            -r|--requirements)
                [[ -n "${2:-}" ]] || { echo "dot::python::env: --requirements requires an argument" >&2; return 1; }
                requirements_file="$2"; shift 2 ;;
            --packages)
                [[ -n "${2:-}" ]] || { echo "dot::python::env: --packages requires an argument" >&2; return 1; }
                packages="$2"; shift 2 ;;
            -h|--help)
                cat <<'EOF'
dot::python::env — create a python virtual environment

Usage: dot::python::env [OPTIONS]

Options:
  -p, --path <dir>      Parent directory for the venv (default: $PWD)
  -n, --name <name>     Name of the venv directory (default: .venv)
  -P, --python <ver>    Python version or path (default: module default)
  -s, --seed            Seed with pip/setuptools
  -f, --force           Recreate if already exists
  -a, --activate        Activate after creation
  -d, --discover-requirements  Find and install requirements.txt from --path root
  -r, --requirements <file>    Install from a specific requirements file
  --packages "pkg1 pkg2 ..."   Install individual packages after activation
  -h, --help            Show this help
EOF
                return 0 ;;
            --)
                shift; break ;;
            -*)
                echo "dot::python::env: unknown option: $1" >&2; return 1 ;;
            *)
                break ;;
        esac
    done

    # Ensure venv name is a hidden directory (dot-prefixed)
    if [[ "${venv_name}" != .* ]]; then
        venv_name=".${venv_name}"
    fi

    # Resolve parent directory
    venv_parent="${venv_parent:-$PWD}"
    if [[ ! -d "${venv_parent}" ]]; then
        echo "dot::python::env: directory does not exist: ${venv_parent}" >&2
        return 1
    fi

    local venv_dir="${venv_parent}/${venv_name}"

    # Handle existing venv
    if [[ -d "${venv_dir}" ]]; then
        if [[ "${force}" -eq 1 ]]; then
            echo "dot::python::env: removing existing venv: ${venv_dir}"
            rm -rf "${venv_dir}"
        else
            echo "dot::python::env: venv already exists: ${venv_dir} (use --force to recreate)" >&2
            return 1
        fi
    fi

    # Create the venv — prefer uv, fall back to python -m venv
    if command -v uv &>/dev/null; then
        local uv_args=(venv --python "${python_ver}")
        [[ "${seed}" -eq 1 ]] && uv_args+=(--seed)
        uv_args+=("${venv_dir}")

        echo "dot::python::env: creating venv with uv (python ${python_ver}): ${venv_dir}"
        if ! uv "${uv_args[@]}"; then
            echo "dot::python::env: uv venv creation failed" >&2
            return 1
        fi
    else
        # Resolve python binary
        local py_bin=""
        if [[ "${python_ver}" == /* || "${python_ver}" == ./* ]]; then
            # Absolute or relative path provided
            py_bin="${python_ver}"
        else
            # Try pythonX.Y first, then python3
            py_bin="$(command -v "python${python_ver}" 2>/dev/null || command -v python3 2>/dev/null || true)"
        fi

        if [[ -z "${py_bin}" || ! -x "${py_bin}" ]]; then
            echo "dot::python::env: cannot find python ${python_ver} (install it or install uv)" >&2
            return 1
        fi

        echo "dot::python::env: creating venv with ${py_bin} -m venv: ${venv_dir}"
        if ! "${py_bin}" -m venv "${venv_dir}"; then
            echo "dot::python::env: python -m venv creation failed" >&2
            return 1
        fi

        # Seed with pip/setuptools if requested
        if [[ "${seed}" -eq 1 && -x "${venv_dir}/bin/python" ]]; then
            "${venv_dir}/bin/python" -m ensurepip --upgrade 2>/dev/null || true
        fi
    fi

    echo "dot::python::env: venv created at ${venv_dir}"

    # Activate if requested
    if [[ "${activate}" -eq 1 ]]; then
        if [[ -f "${venv_dir}/bin/activate" ]]; then
            # shellcheck disable=SC1091
            source "${venv_dir}/bin/activate"
            echo "dot::python::env: activated ${venv_dir}"
        else
            echo "dot::python::env: warning — activate script not found at ${venv_dir}/bin/activate" >&2
        fi
    fi

    # Install requirements if requested
    local req_target=""
    if [[ -n "${requirements_file}" ]]; then
        # Resolve relative paths against PWD
        if [[ "${requirements_file}" != /* ]]; then
            requirements_file="${PWD}/${requirements_file}"
        fi
        if [[ -f "${requirements_file}" ]]; then
            req_target="${requirements_file}"
        else
            echo "dot::python::env: requirements file not found: ${requirements_file}" >&2
            return 1
        fi
    elif [[ "${discover_requirements}" -eq 1 ]]; then
        local candidate="${venv_parent}/requirements.txt"
        if [[ -f "${candidate}" ]]; then
            req_target="${candidate}"
            echo "dot::python::env: discovered ${candidate}"
        else
            echo "dot::python::env: no requirements.txt found in ${venv_parent}" >&2
        fi
    fi

    if [[ -n "${req_target}" ]]; then
        echo "dot::python::env: installing requirements from ${req_target}"
        if command -v uv &>/dev/null; then
            if ! uv pip install --python "${venv_dir}/bin/python" -r "${req_target}"; then
                echo "dot::python::env: uv pip install failed" >&2
                return 1
            fi
        elif [[ -x "${venv_dir}/bin/pip" ]]; then
            if ! "${venv_dir}/bin/pip" install -r "${req_target}"; then
                echo "dot::python::env: pip install failed" >&2
                return 1
            fi
        else
            echo "dot::python::env: no pip available in venv (use --seed to include pip)" >&2
            return 1
        fi
    fi

    # Install individual packages if requested
    if [[ -n "${packages}" ]]; then
        local pkg_failed=0
        local pkg=""
        for pkg in ${=packages}; do
            echo "dot::python::env: installing package: ${pkg}"
            if command -v uv &>/dev/null; then
                if ! uv pip install --python "${venv_dir}/bin/python" "${pkg}" 2>&1; then
                    echo "dot::python::env: failed to install ${pkg}" >&2
                    pkg_failed=$((pkg_failed + 1))
                fi
            elif [[ -x "${venv_dir}/bin/pip" ]]; then
                if ! "${venv_dir}/bin/pip" install "${pkg}" 2>&1; then
                    echo "dot::python::env: failed to install ${pkg}" >&2
                    pkg_failed=$((pkg_failed + 1))
                fi
            else
                echo "dot::python::env: no pip available in venv (use --seed to include pip)" >&2
                return 1
            fi
        done
        if [[ "${pkg_failed}" -gt 0 ]]; then
            echo "dot::python::env: ${pkg_failed} package(s) failed to install" >&2
        fi
    fi

    return 0
}

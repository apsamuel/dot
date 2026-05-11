#!/bin/bash
#% description: installs and bootstrap ⚫️
#% notes: because this must work on bash 3.x.x and 4.x.x, some of the syntax is a bit weird
#% usage: ./dot-bootstrap.sh
# 🕵️ ignore shellcheck warnings about source statements
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# globals
ZSH=${ZSH:-$HOME/.dot/vendor/oh-my-zsh}
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.dot/vendor/oh-my-zsh/custom}

# Resolve the project root.
# When sourced in zsh, BASH_SOURCE[0] is empty — use DOT_DIRECTORY if already
# exported (set by zshrc/dotenv.sh before this file is sourced).
# Fall back to BASH_SOURCE only when executed directly under bash.
if [[ -n "${DOT_DIRECTORY}" ]]; then
    dot_bootstrap_directory="${DOT_DIRECTORY}"
else
    dot_bootstrap_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
dot_boostrap_file="${dot_bootstrap_directory}/scripts/dot-bootstrap.sh"
dot_bootstrap_deps=${DOT_DEPS:-0}
DOT_DRY_RUN=${DOT_DRY_RUN:-0}

icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
icloud_link="${HOME}/iCloud"
ICLOUD=${ICLOUD:-${icloud_link}}


# -----------------------------------------------------------------------------
# _dot_bootstrap_is_sourced - detect whether this file is being sourced
#
# Description:
#   Returns 0 (true) when the file is being sourced, 1 when executed
#   directly.  Safe under both bash and zsh; uses BASH_SOURCE / $0
#   comparison (bash) or ZSH_EVAL_CONTEXT (zsh).
#
# Usage:    if _dot_bootstrap_is_sourced; then ...
# Returns:  0 when sourced; 1 when executed directly.
# -----------------------------------------------------------------------------
_dot_bootstrap_is_sourced () {
    # bash: BASH_SOURCE[0] differs from $0 when sourced
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        [ "${BASH_SOURCE[0]}" != "${0}" ]
        return $?
    fi
    # zsh: ZSH_EVAL_CONTEXT contains "file" when sourced
    case "${ZSH_EVAL_CONTEXT:-}" in
        *:file:*|*:file) return 0 ;;
    esac
    return 1
}

if [ ! -d "${dot_bootstrap_directory}" ]; then
    echo "❌  ${dot_bootstrap_directory} does not exist"
    if _dot_bootstrap_is_sourced; then
        return 1 2>/dev/null || true
    else
        exit 1
    fi
fi

if [ -r "${dot_bootstrap_directory}/modules/static/lib/internal.sh" ]; then
    . "${dot_bootstrap_directory}/modules/static/lib/internal.sh"
fi

# -----------------------------------------------------------------------------
# resolveBrewfilePath - resolve path to the in-repo CLI Brewfile
#
# Description:
#   Echoes the absolute path to the CLI-formula Brewfile (data/Brewfile).
#   Accepts an optional override path; falls back to the repo default.
#
# Usage:    resolveBrewfilePath [path]
# Stdout:   Absolute path to the Brewfile, or an error message.
# Returns:  0 when the file exists; 1 otherwise.
# -----------------------------------------------------------------------------
function resolveBrewfilePath () {
    local file="${1:-${dot_bootstrap_directory}/data/Brewfile}"
    if [[ -f "$file" ]]; then
        echo "$file"
        return 0
    else
        echo "Brewfile not found at $file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# resolveBrewfileCaskPath - resolve path to the in-repo cask Brewfile
#
# Description:
#   Echoes the absolute path to the graphical/cask Brewfile
#   (data/Brewfile.cask). Accepts an optional override path; falls back
#   to the repo default.
#
# Usage:    resolveBrewfileCaskPath [path]
# Stdout:   Absolute path to the Brewfile.cask, or an error message.
# Returns:  0 when the file exists; 1 otherwise.
# -----------------------------------------------------------------------------
function resolveBrewfileCaskPath () {
    local file="${1:-${dot_bootstrap_directory}/data/Brewfile.cask}"
    if [[ -f "$file" ]]; then
        echo "$file"
        return 0
    else
        echo "Brewfile.cask not found at $file"
        return 1
    fi
}


# ──────────────────────────────────────────────────────────────────────────────
# 🎨 output palette — keep messages punchy, scannable, and consistent.
#    Every mutating step funnels through `dry_*` so DOT_DRY_RUN=1 = NO writes.
# ──────────────────────────────────────────────────────────────────────────────
DOT_DRY_RUN="${DOT_DRY_RUN:-0}"

# -----------------------------------------------------------------------------
# _is_dry - test whether dry-run mode is active
#
# Usage:    if _is_dry; then ...
# Returns:  0 when DOT_DRY_RUN > 0; 1 otherwise.
# -----------------------------------------------------------------------------
function _is_dry () { [[ "${DOT_DRY_RUN:-0}" -gt 0 ]]; }

# 🗣 status helpers
function say_step () { echo "🚀 $*"; }
function say_info () { echo "🧭 $*"; }
function say_ok   () { echo "🟢 $*"; }
function say_skip () { echo "🌀 $*"; }   # already correct / no-op (idempotent)
function say_work () { echo "🔨 $*"; }
function say_warn () { echo "🟠 $*"; }
function say_err  () { echo "🔴 $*"; }
function say_plan () { echo "🔮 plan » $*"; }   # printed in dry-run instead of acting
function say_done () { echo "🎉 $*"; }

# -----------------------------------------------------------------------------
# dryrun - dry-run wrapper for commands
#
# Description:
#   In DRY mode (DOT_DRY_RUN > 0), prints the planned command via say_plan
#   and returns 0 without executing. Otherwise, runs the command normally.
#
# Usage:    dryrun <command> [args...]
# Returns:  0 in dry-run mode; exit status of command otherwise.
# -----------------------------------------------------------------------------
function dryrun () {
    if _is_dry; then
        say_plan "$*"
        return 0
    fi
    "$@"
}

# -----------------------------------------------------------------------------
# _dot_std_opts - parse the standard bootstrap* option set
#
# Description:
#   Consumes the common `-n` (dry-run), `-x` (xtrace), `-h` (help) flags
#   shared by every bootstrap* function. Writes results into caller-scoped
#   variables so getopts state stays local to the caller.
#
# Usage:
#   local _opt_dry=0 _opt_debug=0 _opt_help=0 OPTIND=1
#   _dot_std_opts "${FUNCNAME[0]:-${funcstack[1]:-bootstrap}}" "$@" || return $?
#   shift $((OPTIND - 1))
#
# Globals set (in caller scope):
#   _opt_dry    1 when -n was supplied
#   _opt_debug  1 when -x was supplied
#   _opt_help   1 when -h was supplied (caller prints its own usage)
#
# Returns:
#   0 on success; 2 on invalid option.
# -----------------------------------------------------------------------------
function _dot_std_opts () {
    local _name="${1:-bootstrap}"; shift
    _opt_dry=0; _opt_debug=0; _opt_help=0
    OPTIND=1
    local opt
    while getopts ":nxh" opt; do
        case "${opt}" in
            n) _opt_dry=1 ;;
            x) _opt_debug=1 ;;
            h) _opt_help=1 ;;
            \?) say_err "${_name}: invalid option -${OPTARG}"; return 2 ;;
        esac
    done
    return 0
}

# -----------------------------------------------------------------------------
# _dot_require_cmd - assert one or more commands are on PATH
#
# Usage:    _dot_require_cmd <fn-name> <cmd> [cmd...]
# Returns:  0 when all commands resolve, 1 otherwise (with say_err per miss).
# -----------------------------------------------------------------------------
function _dot_require_cmd () {
    local _name="${1:?}"; shift
    local _missing=0 _c
    for _c in "$@"; do
        if ! command -v "${_c}" >/dev/null 2>&1; then
            say_err "${_name}: required command not found: ${_c}"
            _missing=1
        fi
    done
    return "${_missing}"
}

# -----------------------------------------------------------------------------
# dry_mkdir / dry_rm / dry_rmrf / dry_mv / dry_cp - idempotent filesystem ops
#
# Description:
#   Dry-run-aware filesystem primitives. Each inspects current state first
#   and only mutates when needed.  In dry-run mode, prints the planned
#   action via say_plan without executing.
#
# Returns:  0 on success or no-op; propagates underlying command errors.
# -----------------------------------------------------------------------------
function dry_mkdir () {
    local d="${1:?dry_mkdir requires a path}"
    if [[ -d "${d}" ]]; then
        return 0
    fi
    if _is_dry; then say_plan "mkdir -p ${d}"; return 0; fi
    mkdir -p "${d}"
}

function dry_rm () {
    local p="${1:?dry_rm requires a path}"
    if [[ ! -e "${p}" && ! -L "${p}" ]]; then
        return 0
    fi
    if _is_dry; then say_plan "rm -f ${p}"; return 0; fi
    rm -f "${p}"
}

function dry_rmrf () {
    local p="${1:?dry_rmrf requires a path}"
    if [[ ! -e "${p}" && ! -L "${p}" ]]; then
        return 0
    fi
    if _is_dry; then say_plan "rm -rf ${p}"; return 0; fi
    rm -rf "${p}"
}

function dry_mv () {
    local src="${1:?}" dst="${2:?}"
    if [[ ! -e "${src}" && ! -L "${src}" ]]; then
        return 0
    fi
    if _is_dry; then say_plan "mv ${src} ${dst}"; return 0; fi
    mv "${src}" "${dst}"
}

function dry_cp () {
    local src="${1:?}" dst="${2:?}"
    if _is_dry; then say_plan "cp ${src} ${dst}"; return 0; fi
    cp "${src}" "${dst}"
}

# -----------------------------------------------------------------------------
# dry_defaults_write - idempotent defaults write (macOS)
#
# Description:
#   Reads the current value of a macOS defaults key; only writes when the
#   value differs.  Normalizes bool representations for comparison.
#   Dry-run aware.
#
# Usage:    dry_defaults_write <domain> <key> <type> <value>
# Returns:  0 on success or no-op.
# -----------------------------------------------------------------------------
function dry_defaults_write () {
    local domain="${1:?}" key="${2:?}" type="${3:?}" value="${4:?}"
    local current
    current="$(defaults read "${domain}" "${key}" 2>/dev/null || true)"
    # normalize "1"/"0" vs "true"/"false" for -bool comparisons
    case "${type}" in
        -bool)
            case "${value}" in true|YES|1) value="1";; false|NO|0) value="0";; esac
            case "${current}" in true|YES) current="1";; false|NO) current="0";; esac
            ;;
    esac
    if [[ "${current}" == "${value}" ]]; then
        say_skip "defaults: ${domain} ${key} = ${value} (already set)"
        return 0
    fi
    if _is_dry; then
        say_plan "defaults write ${domain} ${key} ${type} ${value}"
        return 0
    fi
    defaults write "${domain}" "${key}" "${type}" "${value}"
}

# -----------------------------------------------------------------------------
# ensureSymlink - idempotent symlink creation with backup
#
# Description:
#   Creates a symlink from source_path to target_path. Idempotent: returns
#   immediately if the link already points correctly. Backs up existing
#   files/directories before replacing. Dry-run aware.
#
# Usage:    ensureSymlink <source_path> <target_path>
# Returns:  0 on success; 1 on missing arguments or source.
# -----------------------------------------------------------------------------
function ensureSymlink () {
    local source_path="${1}"
    local target_path="${2}"
    local backup_path="${target_path}.bak"

    if [[ -z "${source_path}" || -z "${target_path}" ]]; then
        say_err "ensureSymlink requires source and target"
        return 1
    fi

    if [[ ! -e "${source_path}" && ! -L "${source_path}" ]]; then
        say_err "source does not exist: ${source_path}"
        return 1
    fi

    # 🌀 idempotent fast-path: link already points where we want.
    if [[ -L "${target_path}" && "$(readlink "${target_path}")" == "${source_path}" ]]; then
        say_skip "🔗 ${target_path} → ${source_path}"
        return 0
    fi

    if [[ -L "${target_path}" ]]; then
        # wrong link — replace
        dry_rm "${target_path}"
    elif [[ -e "${target_path}" ]]; then
        # real file/dir in the way — back it up (with timestamp if .bak exists)
        if [[ -e "${backup_path}" || -L "${backup_path}" ]]; then
            backup_path="${target_path}.bak.$(date +%s)"
        fi
        say_info "📦 backing up ${target_path} → ${backup_path}"
        dry_mv "${target_path}" "${backup_path}"
    fi

    if _is_dry; then
        say_plan "ln -s ${source_path} ${target_path}"
        return 0
    fi
    ln -s "${source_path}" "${target_path}"
}


# -----------------------------------------------------------------------------
# bootstrapInfo - display preflight system information
#
# Description:
#   Prints architecture, macOS version, login shell, ICLOUD status, and
#   versions of critical CLI tools (brew, git, jq, curl). Purely
#   informational; does not mutate state.
#
# Usage:    bootstrapInfo
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapInfo () {
    say_step "preflight"
    echo "🖥️  arch: $(uname -m)"
    echo "🍎 os:   $(sw_vers -productVersion)"

    current_shell="$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")"
    if [[ $current_shell == "zsh" ]]; then
        say_ok "🐚 login shell is zsh 🐢"
    else
        say_warn "🐚 login shell is ${current_shell} (zsh recommended)"
    fi

    if [[ -z "${ICLOUD}" ]]; then
        say_warn "☁️  \$ICLOUD is not set"
    else
        say_ok "☁️  \$ICLOUD → ${ICLOUD}"
    fi

    local cmd ver
    for cmd in brew git jq curl; do
        if command -v "${cmd}" &>/dev/null; then
            case "${cmd}" in
                brew) ver="$(brew --version 2>/dev/null | head -n1)" ;;
                git)  ver="$(git --version 2>/dev/null)" ;;
                jq)   ver="$(jq --version 2>/dev/null)" ;;
                curl) ver="$(curl --version 2>/dev/null | head -n1)" ;;
            esac
            say_ok "🧰 ${cmd}: ${ver}"
        else
            say_err "🧰 ${cmd}: not installed"
        fi
    done
}

# -----------------------------------------------------------------------------
# bootstrapPrint - print the bootstrap start banner
#
# Description:
#   Announces that bootstrap execution has begun. Includes a dry-run
#   notice when DOT_DRY_RUN is active.
#
# Usage:    bootstrapPrint
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapPrint () {
    if _is_dry; then
        echo "🔮 DRY-RUN MODE — no system changes will be made"
    fi
    say_step "executing ${dot_boostrap_file}"
}


# -----------------------------------------------------------------------------
# bootstrapDeps - install CLI dependencies via brew bundle
#
# Description:
#   Resolves the in-repo Brewfile and runs `brew bundle install`.
#   Dry-run aware via the `dryrun` wrapper.
#
# Usage:    bootstrapDeps
# Returns:  0 on success; 1 when Brewfile missing or install fails.
# -----------------------------------------------------------------------------
function bootstrapDeps () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        say_err "📋 no Brewfile found at ${dot_bootstrap_directory}/data/Brewfile"
        return 1
    fi

    if dryrun brew bundle install --file "${brewfile}"; then
        say_ok "📋 dependencies ok"
        return 0
    fi
    say_err "📋 dependencies failed"
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapCheckDependencies - reconcile CLI deps from data/Brewfile
#
# Description:
#   Resolves the in-repo Brewfile and ensures every listed formula is
#   installed. Idempotent: skips work when `brew bundle check` is clean,
#   unless DOT_DEPS is non-zero. Also guarantees `yq` is present because
#   later steps parse data/zsh.yaml.
#
# Usage:    bootstrapCheckDependencies [-n] [-x] [-h]
# Env:      DOT_DEPS     when >0, forces reinstall even if bundle is clean.
#           DOT_DRY_RUN  when >0, plans rather than mutates.
# Returns:  0 on success; 1 on resolve / install failure.
# -----------------------------------------------------------------------------
function bootstrapCheckDependencies () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckDependencies" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckDependencies [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    _dot_require_cmd "bootstrapCheckDependencies" brew || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    local brewfile rc=0
    brewfile="$(resolveBrewfilePath)" || {
        say_err "📋 no Brewfile found at ${dot_bootstrap_directory}/data/Brewfile"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    }

    # yq is a first-class dependency required for parsing data/zsh.yaml
    if ! command -v yq >/dev/null 2>&1; then
        say_work "🧰 yq not found — installing via brew"
        if ! dryrun brew install yq; then
            say_err "failed to install yq"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
        fi
    fi

    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        say_work "📋 reinstalling brew bundle (DOT_DEPS=${dot_bootstrap_deps})"
        installDependencies; rc=$?
    elif brew bundle check --file "${brewfile}" >/dev/null 2>&1; then
        say_skip "📋 brew bundle satisfied (${brewfile})"
    else
        say_work "📋 brew bundle missing items — installing"
        installDependencies; rc=$?
    fi
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# installDependencies - run brew bundle install for CLI formulae
#
# Description:
#   Lower-level helper that resolves the Brewfile and executes
#   `brew bundle install`. Called by bootstrapCheckDependencies.
#   Dry-run aware.
#
# Usage:    installDependencies
# Returns:  0 on success; 1 when Brewfile missing or install fails.
# -----------------------------------------------------------------------------
function installDependencies () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        say_err "📋 no Brewfile found at ${dot_bootstrap_directory}/data/Brewfile"
        return 1
    fi

    if dryrun brew bundle install --file "${brewfile}"; then
        say_ok "📋 dependencies installed"
        return 0
    fi
    say_err "📋 dependencies installation failed"
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapCheckCaskDependencies - reconcile cask deps from data/Brewfile.cask
#
# Description:
#   Mirror of bootstrapCheckDependencies for graphical/cask formulae.
#   Idempotent: skips when `brew bundle check` passes unless DOT_DEPS forces.
#
# Usage:    bootstrapCheckCaskDependencies [-n] [-x] [-h]
# Returns:  0 on success; 1 when no cask Brewfile or install fails.
# -----------------------------------------------------------------------------
function bootstrapCheckCaskDependencies () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckCaskDependencies" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckCaskDependencies [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    _dot_require_cmd "bootstrapCheckCaskDependencies" brew || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    local cask_brewfile rc=0
    cask_brewfile="$(resolveBrewfileCaskPath)" || {
        say_err "🖼  no Brewfile.cask found at ${dot_bootstrap_directory}/data/Brewfile.cask"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    }
    if [[ ! -f "${cask_brewfile}" ]]; then
        say_err "🖼  Brewfile.cask not readable: ${cask_brewfile}"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        say_work "🖼  reinstalling brew cask bundle (DOT_DEPS=${dot_bootstrap_deps})"
        installCaskDependencies; rc=$?
    elif brew bundle check --file "${cask_brewfile}" >/dev/null 2>&1; then
        say_skip "🖼  brew cask bundle satisfied (${cask_brewfile})"
    else
        say_work "🖼  brew cask bundle missing items — installing"
        installCaskDependencies; rc=$?
    fi
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# installCaskDependencies - run brew bundle install for cask formulae
#
# Description:
#   Lower-level helper that resolves the cask Brewfile and executes
#   `brew bundle install`. Called by bootstrapCheckCaskDependencies.
#   Dry-run aware.
#
# Usage:    installCaskDependencies
# Returns:  0 on success; 1 when Brewfile.cask missing or install fails.
# -----------------------------------------------------------------------------
function installCaskDependencies () {
    local cask_brewfile
    cask_brewfile="$(resolveBrewfileCaskPath)"
    if [[ -z "${cask_brewfile}" || ! -f "${cask_brewfile}" ]]; then
        say_err "🖼  no Brewfile.cask found at ${dot_bootstrap_directory}/data/Brewfile.cask"
        return 1
    fi

    if dryrun brew bundle install --file "${cask_brewfile}"; then
        say_ok "🖼  cask dependencies installed"
        return 0
    fi
    say_err "🖼  cask dependencies installation failed"
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapConfigPython - provision the dot python venv
#
# Description:
#   Creates `${HOME}/.venv/<py>-<arch>-base` via `uv venv` when missing, and
#   optionally seeds pip packages from data/zsh.yaml when DOT_INSTALL_LANG_DEPS
#   is set. Idempotent and dry-run aware.
#
# Usage:    bootstrapConfigPython [-n] [-x] [-h]
# Env:      DOT_INSTALL_LANG_DEPS  when >0, installs pip requirements.
# Returns:  0 on success; 1 when uv missing or venv creation fails.
# -----------------------------------------------------------------------------
function bootstrapConfigPython () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigPython" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigPython [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local desired_version="3.11"
    local arch
    arch="$(uname -m)"
    local venv_name="${desired_version}-${arch}-base"
    local venv_path="${HOME}/.venv/${venv_name}"

    _dot_require_cmd "bootstrapConfigPython" uv || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    dry_mkdir "${HOME}/.venv"
    if [[ ! -d "${venv_path}" ]]; then
        say_work "🐍 creating python venv ${venv_name}"
        if ! dryrun uv venv --seed --python "${desired_version}" "${venv_path}"; then
            say_err "🐍 failed to create python venv"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
        fi
    else
        say_skip "🐍 python venv ${venv_name} already exists"
    fi

    say_ok "🐍 python venv ${venv_name} is ready"

    if [[ "${DOT_INSTALL_LANG_DEPS:-0}" -gt 0 ]]; then
        local data_file="${dot_bootstrap_directory}/data/zsh.yaml"
        if [[ ! -f "${data_file}" ]]; then
            say_warn "data/zsh.yaml not found, skipping pip packages"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        if ! command -v yq >/dev/null 2>&1; then
            say_warn "yq not found, skipping pip packages"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        local pip_packages
        pip_packages="$(yq '.languages.python.pip.requirements[]' "${data_file}" 2>/dev/null)"
        if [[ -z "${pip_packages}" ]]; then
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        while IFS= read -r pkg; do
            local pkg_name="${pkg%%==*}"
            if uv pip show --python "${venv_path}" "${pkg_name}" &>/dev/null; then
                say_skip "📦 pip ${pkg_name} already installed"
            else
                say_work "📦 installing pip package ${pkg}"
                dryrun uv pip install --python "${venv_path}" "${pkg}" || say_warn "failed to install ${pkg}"
            fi
        done <<< "${pip_packages}"
    fi

    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapLinkCloud - symlink ~/iCloud to the macOS iCloud Drive root
#
# Description:
#   Resolves the user's iCloud Drive directory and exposes it as a stable
#   path (`${HOME}/iCloud`). Idempotent via ensureSymlink. Exports ICLOUD
#   on success so downstream config steps can locate cloud-backed assets.
#
# Usage:    bootstrapLinkCloud [-n] [-x] [-h]
# Returns:  0 when the link points at the iCloud root; 1 otherwise.
# -----------------------------------------------------------------------------
function bootstrapLinkCloud () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapLinkCloud" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapLinkCloud [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    if [[ ! -d "${icloud_directory}" ]]; then
        say_err "☁️  iCloud directory not found: ${icloud_directory}"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 1
    fi

    if ensureSymlink "${icloud_directory}" "${icloud_link}"; then
        ICLOUD="${icloud_link}"
        export ICLOUD
        say_ok "☁️  ${icloud_link} → ${icloud_directory}"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi

    say_err "☁️  ${icloud_link} is not linked to ${icloud_directory}"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapCheckCloud - verify iCloud Drive is enabled and linked
#
# Description:
#   Confirms the macOS iCloud Drive directory exists and delegates linking
#   to bootstrapLinkCloud. Required before any step that reads cloud-backed
#   config (ssh, git, iterm, p10k).
#
# Usage:    bootstrapCheckCloud [-n] [-x] [-h]
# Returns:  0 when iCloud is available and linked; 1 otherwise.
# -----------------------------------------------------------------------------
function bootstrapCheckCloud () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckCloud" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckCloud [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    if [[ ! -d "${icloud_directory}" ]]; then
        say_err "☁️  iCloud is not enabled (${icloud_directory} missing)"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 1
    fi
    say_ok "☁️  iCloud is enabled"
    bootstrapLinkCloud
    local rc=$?
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# bootstrapCheckOhMyTmux - link oh-my-tmux config + install tpm plugins
#
# Description:
#   Symlinks `~/.tmux.conf` and `~/.tmux.conf.local` to the vendored
#   oh-my-tmux copies, archives any legacy ~/.tmux, and (when not in
#   dry-run) runs a transient tmux session to trigger tpm plugin install.
#
# Usage:    bootstrapCheckOhMyTmux [-n] [-x] [-h]
# Returns:  0 on success; 1 when vendor/oh-my-tmux missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapCheckOhMyTmux () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckOhMyTmux" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckOhMyTmux [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    say_warn "DEPRECATED: use 'make bootstrap-tmux' or 'make tmux-install' instead"

    local vendor_tmux="${dot_bootstrap_directory}/vendor/oh-my-tmux"
    local plugin_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/tmux/plugins"

    if [[ ! -d "${vendor_tmux}" ]]; then
        say_err "🪴 vendor/oh-my-tmux not found — run bootstrapInitSubmodules first"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    ensureSymlink "${vendor_tmux}/.tmux.conf"       "${HOME}/.tmux.conf"       \
        || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }
    ensureSymlink "${vendor_tmux}/.tmux.conf.local" "${HOME}/.tmux.conf.local" \
        || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    dry_mkdir "${plugin_dir}"

    # back up any legacy ~/.tmux directory or symlink
    if [[ -e "${HOME}/.tmux" || -L "${HOME}/.tmux" ]]; then
        say_work "📦 archiving legacy ~/.tmux (plugins now live in ${plugin_dir})"
        dry_rmrf "${HOME}/.tmux.bak"
        dry_mv  "${HOME}/.tmux" "${HOME}/.tmux.bak"
    fi

    # install plugins via a transient tmux session — ONLY when not in dry-run.
    export TMUX_PLUGIN_MANAGER_PATH="${plugin_dir}"
    if _is_dry; then
        say_plan "tmux new-session -d -s bootstrap && send-keys C-I (install tpm plugins)"
    else
        if ! command -v tmux >/dev/null 2>&1; then
            say_warn "🪴 tmux is not installed; skipping plugin install"
        else
            tmux has-session -t bootstrap 2>/dev/null && tmux kill-session -t bootstrap
            tmux new-session -d -s bootstrap \
                && tmux send-keys -t bootstrap C-I \
                && tmux kill-session -t bootstrap \
                || say_warn "🪴 tpm install session did not complete cleanly"
        fi
    fi
    say_ok "🪴 tmux is configured"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigFiglet - configure figlet fonts (vendored)
#
# Description:
#   Figlet fonts ship as a git submodule under vendor/figlet-fonts; this
#   function is now a documented no-op kept for call-graph compatibility.
#
# Usage:    bootstrapConfigFiglet [-n] [-x] [-h]
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapConfigFiglet () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigFiglet" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigFiglet [-n] [-x] [-h]"; return 0
    fi
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local vendor_dir="${dot_bootstrap_directory}/vendor/figlet-fonts"
    if [[ ! -d "${vendor_dir}" ]]; then
        say_warn "🅰️ vendor/figlet-fonts not found — run bootstrapInitSubmodules first"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    say_ok "🅰️ figlet fonts present (vendored: ${vendor_dir})"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigIterm - configure iTerm2 (placeholder)
#
# Description:
#   Reserved hook for iTerm2 configuration. Implementation is intentionally
#   commented-out pending a rework; emits a skip notice for visibility.
#
# Usage:    bootstrapConfigIterm [-n] [-x] [-h]
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapConfigIterm () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigIterm" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigIterm [-n] [-x] [-h]"; return 0
    fi
    say_skip "🖥️  iterm2 configuration is a work in progress"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigSsh - link ssh config + key material from iCloud
#
# Description:
#   Mirrors `${ICLOUD}/dot/ssh/{config,config.d,<keyfiles>}` into ~/.ssh
#   using ensureSymlink (idempotent). Includes per-host snippets from
#   `${ICLOUD}/dot/ssh/config.d` and any non-config file directly under
#   `${ICLOUD}/dot/ssh` (identities/keys). Requires bootstrapCheckCloud to
#   have populated ICLOUD.
#
# Usage:    bootstrapConfigSsh [-n] [-x] [-h]
# Returns:  0 on success; 1 when ICLOUD missing or any link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigSsh () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigSsh" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigSsh [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    if [[ -z "${ICLOUD:-}" ]]; then
        say_err "🔑 ICLOUD is not set — run bootstrapCheckCloud first"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    local ssh_config="${HOME}/.ssh/config"
    local ssh_config_dot="${ICLOUD}/dot/ssh/config"
    local ssh_root_dot="${ICLOUD}/dot/ssh"
    local ssh_config_d_dot="${ICLOUD}/dot/ssh/config.d"
    local ssh_config_d="${HOME}/.ssh/config.d"
    local ssh_keys=()

    if [[ ! -f "${ssh_config_dot}" ]]; then
        say_err "🔑 ssh source config missing: ${ssh_config_dot}"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    dry_mkdir "${HOME}/.ssh"
    dry_mkdir "${ssh_config_d}"

    ensureSymlink "${ssh_config_dot}" "${ssh_config}" || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    # link any per-host/include config snippets
    if [[ -d "${ssh_config_d_dot}" ]]; then
        local ssh_config_snippet snippet_name
        while IFS= read -r -d '' ssh_config_snippet; do
            snippet_name="$(basename "${ssh_config_snippet}")"
            ensureSymlink "${ssh_config_snippet}" "${ssh_config_d}/${snippet_name}" \
                || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }
        done < <(find "${ssh_config_d_dot}" -type f -print0)
    fi

    # collect non-recursive top-level entries (key material)
    while IFS= read -r -d '' ssh_key; do
        ssh_keys+=("${ssh_key}")
    done < <(find "${ssh_root_dot}" -maxdepth 1 -type f -print0)

    local ssh_key ssh_key_name ssh_key_path
    for ssh_key in "${ssh_keys[@]}"; do
        ssh_key_name="$(basename "${ssh_key}")"
        [[ "${ssh_key_name}" == "config" ]] && continue
        ssh_key_path="${HOME}/.ssh/${ssh_key_name}"
        ensureSymlink "${ssh_key}" "${ssh_key_path}" \
            || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }
    done
    say_ok "🔑 your ssh client is configured"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigGit - link ~/.gitconfig to the iCloud-tracked config
#
# Usage:    bootstrapConfigGit [-n] [-x] [-h]
# Returns:  0 on success; 1 when ICLOUD missing, source missing, or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigGit () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigGit" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigGit [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    if [[ -z "${ICLOUD:-}" ]]; then
        say_err "🐙 ICLOUD is not set — run bootstrapCheckCloud first"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    local git_config="${HOME}/.gitconfig"
    local git_config_dot="${ICLOUD}/dot/git/config"

    if [[ ! -f "${git_config_dot}" ]]; then
        say_err "🐙 git source config missing: ${git_config_dot}"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    ensureSymlink "${git_config_dot}" "${git_config}" || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }
    say_ok "🐙 your git installation is configured"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigGh - link gh CLI config from iCloud
#
# Description:
#   Symlinks `~/.config/gh/{config.yml,hosts.yml}` to the iCloud-tracked
#   gh configuration directory. Idempotent via ensureSymlink. Dry-run safe.
#
# Usage:    bootstrapConfigGh
# Returns:  0 on success; 1 when symlink fails.
# -----------------------------------------------------------------------------
function bootstrapConfigGh () {
    local git_config_dir_dot="${icloud_directory}/dot/git/gh"
    local git_config_dir="${HOME}/.config/gh"

    dry_mkdir "${git_config_dir}"
    ensureSymlink "${git_config_dir_dot}/config.yml" "${git_config_dir}/config.yml" || return 1
    ensureSymlink "${git_config_dir_dot}/hosts.yml"  "${git_config_dir}/hosts.yml"  || return 1

    say_ok "🐱 your gh installation is configured"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigureZsh - configure zsh as the login shell
#
# Description:
#   Links the git-tracked zshrc (`$DOT_DIRECTORY/zshrc`) to `~/.zshrc` and,
#   optionally, mirrors `data/zsh.yaml` into iCloud. The legacy iCloud `rc`
#   file is no longer written; git is the source of truth for the rc.
#
# Flags:
#   -r   link `$DOT_DIRECTORY/zshrc` -> `~/.zshrc` (default when neither
#        -r nor -d is supplied)
#   -d   mirror `$DOT_DIRECTORY/data/zsh.yaml` ->
#        `$ICLOUD/dot/shell/zsh/zsh.yaml` (only when source is newer)
#   -n   dry-run
#   -x   debug / xtrace
#   -h   show usage
#   login shell is zsh. With -d, also mirrors `data/zsh.yaml` to the iCloud
#   tracked copy used by remote shells. Idempotent throughout (ensureSymlink,
#   `-nt` test, chsh only when shell differs).
#
# Usage:    bootstrapConfigureZsh [-r] [-d] [-n] [-x] [-h]
# Options:  -r link \$DOT_DIRECTORY/zshrc -> ~/.zshrc (default when no flag)
#           -d mirror data/zsh.yaml -> \$ICLOUD/dot/shell/zsh/zsh.yaml
#           -n dry-run  -x xtrace  -h help
# Returns:  0 on success; 1 on missing prerequisites or link/copy failure.
# -----------------------------------------------------------------------------
function bootstrapConfigureZsh () {
    local dry_mode=0 handles_config=0 handles_rc=0 debug=0 show_help=0
    local OPTIND=1
    local opt
    while getopts ":ndhrx" opt; do
        case ${opt} in
            d) handles_config=1 ;;
            r) handles_rc=1 ;;
            n) dry_mode=1 ;;
            x) debug=1 ;;
            h) show_help=1 ;;
            \?) say_err "bootstrapConfigureZsh: invalid option -${OPTARG}"; return 2 ;;
        esac
    done
    if [[ ${show_help} -eq 1 ]]; then
        cat <<'EOF'
Usage: bootstrapConfigureZsh [-r] [-d] [-n] [-x] [-h]
  -r   link $DOT_DIRECTORY/zshrc -> ~/.zshrc (default)
  -d   mirror data/zsh.yaml -> $ICLOUD/dot/shell/zsh/zsh.yaml
  -n   dry-run
  -x   xtrace
  -h   show this help message
EOF
        return 0
    fi

    # default action: link rc
    [[ ${handles_rc} -eq 0 && ${handles_config} -eq 0 ]] && handles_rc=1

    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"
    [[ ${dry_mode} -gt 0 ]] && DOT_DRY_RUN=1
    [[ ${debug} -gt 0 ]] && set -x

    local rc_source="${dot_bootstrap_directory}/zshrc"
    local rc_target="${HOME}/.zshrc"

    if [[ ! -f "${rc_source}" ]]; then
        say_err "rc source missing: ${rc_source}"
        [[ ${debug} -gt 0 ]] && set +x
        return 1
    fi

    _dot_require_cmd "bootstrapConfigureZsh" zsh basename awk \
        || { [[ ${debug} -gt 0 ]] && set +x; return 1; }

    local zsh_bin
    zsh_bin="$(command -v zsh)"

    # ensure user's login shell is zsh
    local current_shell=""
    if command -v dscl >/dev/null 2>&1; then
        current_shell="$(basename -- "$(dscl . -read "$HOME" UserShell 2>/dev/null | awk '{print $NF}')")"
    fi
    if [[ -n "${current_shell}" && "${current_shell}" != "zsh" ]]; then
        dryrun chsh -s "${zsh_bin}" "${USER}" || say_warn "chsh failed; login shell unchanged"
    fi

    # one-shot deprecation notice for legacy iCloud rc
    if [[ -n "${ICLOUD:-}" && -e "${ICLOUD}/dot/shell/zsh/rc" ]]; then
        say_warn "🪰 iCloud zsh rc is deprecated; ${rc_source} is now canonical."
        say_warn "   You may safely remove ${ICLOUD}/dot/shell/zsh/rc once nothing references it."
    fi

    # -r: link git-tracked zshrc -> ~/.zshrc
    if [[ ${handles_rc} -gt 0 ]]; then
        if ! ensureSymlink "${rc_source}" "${rc_target}"; then
            say_err "failed to link ${rc_source} → ${rc_target}"
            [[ ${debug} -gt 0 ]] && set +x
            return 1
        fi
        [[ ${debug} -gt 0 ]] && say_ok "${rc_target} → ${rc_source}"
    fi

    # -d: mirror data/zsh.yaml to iCloud
    if [[ ${handles_config} -gt 0 ]]; then
        if [[ -z "${ICLOUD:-}" ]]; then
            say_err "ICLOUD is not set; cannot mirror zsh.yaml"
            [[ ${debug} -gt 0 ]] && set +x
            return 1
        fi
        local data_source="${dot_bootstrap_directory}/data/zsh.yaml"
        local data_dest="${icloud_directory}/dot/shell/zsh/zsh.yaml"
        local data_dest_dir="${data_dest%/*}"

        if [[ ! -f "${data_source}" ]]; then
            say_err "data source missing: ${data_source}"
            [[ ${debug} -gt 0 ]] && set +x
            return 1
        fi
        [[ ! -d "${data_dest_dir}" ]] && dry_mkdir "${data_dest_dir}"

        if [[ ! -f "${data_dest}" || "${data_source}" -nt "${data_dest}" ]]; then
            dry_cp "${data_source}" "${data_dest}"
            [[ ${debug} -gt 0 ]] && say_ok "${data_source} -> ${data_dest}"
        else
            [[ ${debug} -gt 0 ]] && say_skip "${data_dest} is up to date"
        fi
    fi

    say_ok "🐢 zsh shell is configured (restart open shells)"
    [[ ${debug} -gt 0 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigBash - link ~/.bashrc to the tracked bash rc
#
# Usage:    bootstrapConfigBash [-n] [-x] [-h]
# Returns:  0 on success; 1 when source missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigBash () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigBash" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigBash [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local rc_source="${dot_bootstrap_directory}/data/configs/shell/bash/rc"
    local rc="${HOME}/.bashrc"

    if [[ ! -f "${rc_source}" ]]; then
        say_err "rc source missing: ${rc_source}"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi

    ensureSymlink "${rc_source}" "${rc}" || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }
    say_ok "🐚 bash shell is configured (restart open shells)"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigFish - link fish shell config from tracked rc
#
# Description:
#   Symlinks the tracked fish rc to `~/.config/fish/config.fish`.
#   Creates the parent directory when absent. Idempotent + dry-run aware.
#
# Usage:    bootstrapConfigFish [-n] [-h]
# Returns:  0 on success; 1 when source missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigFish () {
    local opt="" OPTIND=1
    local dry_mode=0
    while getopts ":nh" opt; do
        case "${opt}" in
            n) dry_mode=1 ;;
            h)
                echo "Usage: bootstrapConfigFish [-n] [-h]"
                echo "  -n   dry-run"
                echo "  -h   show this help message"
                return 0
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
        esac
    done

    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"
    if [[ ${dry_mode} -gt 0 ]]; then
        DOT_DRY_RUN=1
    fi

    local rc_source="${dot_bootstrap_directory}/data/configs/shell/fish/rc"
    local rc="${HOME}/.config/fish/config.fish"

    if [[ ! -f "${rc_source}" ]]; then
        say_err "rc source missing: ${rc_source}"
        return 1
    fi

    dry_mkdir "$(dirname "${rc}")"
    ensureSymlink "${rc_source}" "${rc}" || return 1
    say_ok "🐟 fish shell is configured (restart open shells)"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigKsh - link ksh shell config from tracked rc
#
# Description:
#   Symlinks the tracked ksh rc to `~/.kshrc`. Idempotent + dry-run aware.
#
# Usage:    bootstrapConfigKsh [-n] [-h]
# Returns:  0 on success; 1 when source missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigKsh () {
    local opt="" OPTIND=1
    local dry_mode=0
    while getopts ":nh" opt; do
        case "${opt}" in
            n) dry_mode=1 ;;
            h)
                echo "Usage: bootstrapConfigKsh [-n] [-h]"
                echo "  -n   dry-run"
                echo "  -h   show this help message"
                return 0
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
        esac
    done

    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"
    if [[ ${dry_mode} -gt 0 ]]; then
        DOT_DRY_RUN=1
    fi

    local rc_source="${dot_bootstrap_directory}/data/configs/shell/ksh/rc"
    local rc="${HOME}/.kshrc"

    if [[ ! -f "${rc_source}" ]]; then
        say_err "rc source missing: ${rc_source}"
        return 1
    fi

    ensureSymlink "${rc_source}" "${rc}" || return 1
    say_ok "🐘 ksh shell is configured (restart open shells)"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigCsh - link csh shell config from tracked rc
#
# Description:
#   Symlinks the tracked csh rc to `~/.cshrc`. Idempotent + dry-run aware.
#
# Usage:    bootstrapConfigCsh [-n] [-h]
# Returns:  0 on success; 1 when source missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigCsh () {
    local opt="" OPTIND=1
    local dry_mode=0
    while getopts ":nh" opt; do
        case "${opt}" in
            n) dry_mode=1 ;;
            h)
                echo "Usage: bootstrapConfigCsh [-n] [-h]"
                echo "  -n   dry-run"
                echo "  -h   show this help message"
                return 0
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
        esac
    done

    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"
    if [[ ${dry_mode} -gt 0 ]]; then
        DOT_DRY_RUN=1
    fi

    local rc_source="${dot_bootstrap_directory}/data/configs/shell/csh/rc"
    local rc="${HOME}/.cshrc"

    if [[ ! -f "${rc_source}" ]]; then
        say_err "rc source missing: ${rc_source}"
        return 1
    fi

    ensureSymlink "${rc_source}" "${rc}" || return 1
    say_ok "🦜 csh shell is configured (restart open shells)"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigPwsh - configure PowerShell (placeholder)
#
# Description:
#   Reserved hook for PowerShell configuration. Currently a no-op.
#
# Usage:    bootstrapConfigPwsh
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapConfigPwsh () {
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigOhMyZsh - configure oh-my-zsh symlink
#
# Description:
#   Symlinks the vendored oh-my-zsh directory to $ZSH. Idempotent via
#   ensureSymlink.
#
# Usage:    bootstrapConfigOhMyZsh
# Returns:  0 on success; 1 when vendor directory missing or link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigOhMyZsh () {
    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    if [[ ! -d "${vendor_omz}" ]]; then
        say_err "🧙 vendor/oh-my-zsh not found — run bootstrapInitSubmodules first"
        return 1
    fi
    if ensureSymlink "${vendor_omz}" "${ZSH}"; then
        say_ok "🧙 oh-my-zsh is configured"
        return 0
    fi
    say_err "🧙 oh-my-zsh configuration failed"
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapConfigZshCustomPlugins - DEPRECATED custom plugin loader
#
# Description:
#   Formerly installed custom zsh plugins by clobbering ~/.zshrc. Replaced
#   by bootstrapInstallOhMyZshCustomPlugins which uses vendored submodules.
#   Emits a deprecation warning and returns immediately.
#
# Usage:    bootstrapConfigZshCustomPlugins
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapConfigZshCustomPlugins () {
    say_warn "bootstrapConfigZshCustomPlugins is deprecated — use bootstrapInstallOhMyZshCustomPlugins"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckOhMyZshPlugin - validate a single oh-my-zsh plugin
#
# Description:
#   Checks that a plugin identified by -o <org> -r <repo> is valid.
#   Currently only validates that both arguments are supplied.
#
# Usage:    bootstrapCheckOhMyZshPlugin -o <org> -r <repo>
# Returns:  0 when args are valid; 1 on missing org or repo.
# -----------------------------------------------------------------------------
function bootstrapCheckOhMyZshPlugin () {
    local org="" repo="" opt="" OPTIND=1
    while getopts ":o:r:" opt; do
        case ${opt} in
            o)
                org="${OPTARG}"
                ;;
            r)
                repo="${OPTARG}"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                ;;
        esac
    done

    # if o or r is not set, return
    if [[ -z "${org}" || -z "${repo}" ]]; then
        echo "❌  org or repo not set"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapListOhMyZshPluginConfiguredPlugins - list installed custom plugins
#
# Description:
#   Lists directories under ~/.oh-my-zsh/custom/plugins/ to show which
#   custom plugins are physically present on disk.
#
# Usage:    bootstrapListOhMyZshPluginConfiguredPlugins
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapListOhMyZshPluginConfiguredPlugins () {
    local _plugins="" plugin=""
    _plugins=$(
        find "${HOME}/.oh-my-zsh/custom/plugins/" -maxdepth 1 -type d -exec basename {} \;
    )
    if [[ -n "${_plugins}" ]]; then
        echo "🛠️  configured oh-my-zsh plugins:"
        while IFS= read -r plugin; do
            [[ -z "${plugin}" ]] && continue
            echo " - ${plugin}"
        done <<< "${_plugins}"
    else
        echo "❌  no configured oh-my-zsh plugins found"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapListOhMyZshPlugin - list available oh-my-zsh plugins
#
# Description:
#   With -l, lists local custom plugins on disk. With -c, lists plugins
#   declared in data/zsh.yaml. Supports -h for usage.
#
# Usage:    bootstrapListOhMyZshPlugin [-l] [-c] [-h]
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapListOhMyZshPlugin () {
    local list_local=0 list_configured=0 opt="" OPTIND=1
    while getopts ":lch" opt; do
        case ${opt} in
            l)
                list_local=1
                ;;
            c)
                list_configured=1
                ;;
            h)
                echo "Usage: bootstrapListOhMyZshPlugin [-l] [-c] [-h]"
                return 0
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                ;;
        esac
    done

    echo "🛠️  available oh-my-zsh plugins"

    if [[ "${list_local}" -gt 0 ]]; then
        find "${dot_bootstrap_directory}/vendor/oh-my-zsh/custom/plugins" -maxdepth 1 -type d -exec basename {} \;
    fi

    if [[ "${list_configured}" -gt 0 ]]; then
        local plugin=""
        yq '.plugins.custom[].owner' "${HOME}/.dot/data/zsh.yaml" | \
        while IFS= read -r plugin; do
            echo " - ${plugin}"
        done
    fi
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallOhMyZshPlugin - clone a single oh-my-zsh custom plugin
#
# Description:
#   Clones an oh-my-zsh plugin from GitHub into $ZSH_CUSTOM/plugins/<repo>.
#   Idempotent: skips if the target directory already exists. Dry-run aware.
#
# Usage:    bootstrapInstallOhMyZshPlugin <org> <repo>
# Returns:  0 on success or already installed; 1 on missing args or clone failure.
# -----------------------------------------------------------------------------
function bootstrapInstallOhMyZshPlugin() {
    local org="${1}"
    local repo="${2}"
    if [[ -z "${org}" || -z "${repo}" ]]; then
        say_err "🧩 org and repo are required"
        return 1
    fi
    local target="${ZSH_CUSTOM}/plugins/${repo}"
    if [[ -d "${target}" ]]; then
        say_skip "🧩 ${repo} already installed"
        return 0
    fi
    if ! dryrun gh repo clone "${org}/${repo}" "${target}"; then
        say_err "🧩 failed to install ${repo}"
        return 1
    fi
    say_ok "🧩 ${repo} installed"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigPowershell10K - link powerlevel10k config from iCloud
#
# Description:
#   Symlinks `~/.p10k.zsh` to the iCloud-tracked powerlevel10k rc.
#   Idempotent via ensureSymlink.
#
# Usage:    bootstrapConfigPowershell10K
# Returns:  0 on success; 1 when link fails.
# -----------------------------------------------------------------------------
function bootstrapConfigPowershell10K () {
    ensureSymlink "${icloud_directory}/dot/shell/powerlevel/rc.zsh" "${HOME}/.p10k.zsh" || return 1
    say_ok "✨ powerlevel10k is configured"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckBrew - ensure Homebrew is available
#
# Description:
#   Idempotent guard for Homebrew. Returns success immediately when `brew`
#   is already on PATH; otherwise delegates installation to
#   bootstrapInstallBrew. Honors DOT_DRY_RUN via the installer.
#
# Usage:    bootstrapCheckBrew [-n] [-x] [-h]
# Options:  -n dry-run   -x xtrace   -h help
# Returns:  0 when brew is present after the call; 1 on install failure.
# -----------------------------------------------------------------------------
function bootstrapCheckBrew () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckBrew" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckBrew [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    if command -v brew >/dev/null 2>&1; then
        say_skip "🍺 brew already installed"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    say_work "🍺 installing brew"
    bootstrapInstallBrew
    local rc=$?
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# bootstrapCheckZsh - DEPRECATED zsh check (handled by data/Brewfile)
#
# Usage:    bootstrapCheckZsh
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckZsh () {
    say_skip "🐢 bootstrapCheckZsh deprecated — zsh provided by data/Brewfile"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckJq - DEPRECATED jq check (handled by data/Brewfile)
#
# Usage:    bootstrapCheckJq
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckJq () {
    say_skip "🧪 bootstrapCheckJq deprecated — jq provided by data/Brewfile"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckIterm - DEPRECATED iterm2 check (handled by data/Brewfile.cask)
#
# Usage:    bootstrapCheckIterm [-n] [-x] [-h]
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckIterm () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckIterm" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckIterm [-n] [-x] [-h]"; return 0
    fi
    say_skip "🖥️  bootstrapCheckIterm deprecated — iterm2 provided by data/Brewfile.cask"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckFonts - DEPRECATED fonts check (handled by data/Brewfile.cask)
#
# Usage:    bootstrapCheckFonts
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckFonts () {
    say_skip "🔤 bootstrapCheckFonts deprecated — fonts provided by data/Brewfile.cask"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckThemes - DEPRECATED themes check (vendor submodule)
#
# Usage:    bootstrapCheckThemes
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckThemes () {
    say_skip "🎨 bootstrapCheckThemes deprecated — vendor submodule iterm-themes provides themes"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckOhMyZsh - ensure oh-my-zsh is installed and configured
#
# Description:
#   Installs oh-my-zsh when ~/.oh-my-zsh is missing, then delegates to
#   bootstrapConfigOhMyZsh for symlinks/customizations. Idempotent.
#
# Usage:    bootstrapCheckOhMyZsh [-n] [-x] [-h]
# Returns:  0 on success; non-zero from the install/config sub-step.
# -----------------------------------------------------------------------------
function bootstrapCheckOhMyZsh () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckOhMyZsh" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckOhMyZsh [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local rc=0
    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    local omz_home="$HOME/.oh-my-zsh"

    if [[ -L "${omz_home}" ]]; then
        local link_target=""
        link_target="$(readlink "${omz_home}")"
        if [[ "${link_target}" == "${vendor_omz}" ]]; then
            say_skip "🧙 oh-my-zsh already linked to vendor"
        elif [[ "${link_target}" == *"iCloud"* || "${link_target}" == *"Mobile Documents"* ]]; then
            say_warn "🧙 oh-my-zsh linked to iCloud (${link_target}) — relinking to vendor"
            dry_rm "${omz_home}"
            ensureSymlink "${vendor_omz}" "${omz_home}" || rc=1
        else
            say_warn "🧙 oh-my-zsh linked to unexpected target (${link_target}) — relinking to vendor"
            dry_rm "${omz_home}"
            ensureSymlink "${vendor_omz}" "${omz_home}" || rc=1
        fi
    elif [[ -d "${omz_home}" ]]; then
        say_warn "🧙 oh-my-zsh is a directory, not a symlink — relinking to vendor"
        ensureSymlink "${vendor_omz}" "${omz_home}" || rc=1
    else
        say_work "🧙 installing oh-my-zsh"
        bootstrapInstallOhMyZsh || rc=$?
        if [[ ${rc} -eq 0 && ! -L "${omz_home}" ]]; then
            ensureSymlink "${vendor_omz}" "${omz_home}" || rc=1
        fi
    fi
    if [[ ${rc} -eq 0 ]]; then
        bootstrapConfigOhMyZsh || rc=$?
    fi
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# bootstrapCheckPowershell10K - check powerlevel10k installation (WIP)
#
# Description:
#   Placeholder for powerlevel10k installation verification.
#   Currently emits a skip notice.
#
# Usage:    bootstrapCheckPowershell10K
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapCheckPowershell10K () {
    say_skip "✨ powerlevel10k installation is a work in progress"
    return 0
    # if [[ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]]; then
    #     say_work "✨ installing powerlevel10k"
    #     bootstrapInstallPowershell10K || return 1
    # fi
    # if [[ -L "${HOME}/.p10k.zsh" || -f "${HOME}/.p10k.zsh" ]]; then
    #     # let bootstrapConfigPowershell10K resolve idempotency via ensureSymlink
    #     bootstrapConfigPowershell10K
    # else
    #     say_work "✨ powerlevel10k is not configured — configuring"
    #     bootstrapConfigPowershell10K
    # fi
}

# -----------------------------------------------------------------------------
# bootstrapInstallBrew - install Homebrew from upstream
#
# Description:
#   Runs the official Homebrew installer script. Requires `curl` and `bash`
#   on PATH. Dry-run safe: prints the planned command without executing.
#
# Usage:    bootstrapInstallBrew [-n] [-x] [-h]
# Returns:  0 on success; 1 on installer failure or missing prerequisites.
# -----------------------------------------------------------------------------
function bootstrapInstallBrew () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapInstallBrew" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapInstallBrew [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    _dot_require_cmd "bootstrapInstallBrew" curl bash || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    if _is_dry; then
        say_plan "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        say_ok "🍺 brew is installed"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    say_err "🍺 brew installation failed"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapInstallZsh - DEPRECATED (handled by data/Brewfile)
#
# Usage:    bootstrapInstallZsh
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapInstallZsh () {
    say_skip "🐢 zsh installation is handled by data/Brewfile"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallJq - DEPRECATED (handled by data/Brewfile)
#
# Usage:    bootstrapInstallJq
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapInstallJq () {
    say_skip "🧪 jq installation is handled by data/Brewfile"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallIterm - DEPRECATED (handled by data/Brewfile.cask)
#
# Usage:    bootstrapInstallIterm [-n] [-x] [-h]
# Returns:  0 always.
# -----------------------------------------------------------------------------
function bootstrapInstallIterm () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapInstallIterm" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapInstallIterm [-n] [-x] [-h]"; return 0
    fi
    say_skip "🖥️  iterm2 installation is handled by data/Brewfile.cask"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallFonts - install custom fonts from iCloud
#
# Description:
#   Copies font files from `$ICLOUD/dot/terminal/fonts/` into
#   `~/Library/Fonts/`. Idempotent: only copies fonts not already present.
#   Dry-run aware.
#
# Usage:    bootstrapInstallFonts
# Returns:  0 on success; 1 when source directory is missing.
# -----------------------------------------------------------------------------
function bootstrapInstallFonts () {
    local src_dir="${ICLOUD}/dot/terminal/fonts"
    local dst_dir="${HOME}/Library/Fonts"
    if [[ ! -d "${src_dir}" ]]; then
        say_err "🔤 fonts source not found: ${src_dir}"
        return 1
    fi
    dry_mkdir "${dst_dir}"
    local font name copied=0 skipped=0
    while IFS= read -r -d '' font; do
        name="$(basename "${font}")"
        if [[ -e "${dst_dir}/${name}" ]]; then
            skipped=$((skipped+1))
            continue
        fi
        dry_cp "${font}" "${dst_dir}/${name}"
        copied=$((copied+1))
    done < <(find "${src_dir}" -maxdepth 1 -type f -print0)
    say_ok "🔤 fonts: ${copied} copied, ${skipped} already present"
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallThemes - verify iterm2 themes vendor submodule
#
# Description:
#   Checks that the iterm-themes vendor submodule is present. Iterm2
#   imports directly from the vendor directory; no linking needed.
#   Idempotent.
#
# Usage:    bootstrapInstallThemes
# Returns:  0 when present; 1 when vendor directory is missing.
# -----------------------------------------------------------------------------
function bootstrapInstallThemes () {
    local vendor_dir="${dot_bootstrap_directory}/vendor/iterm-themes"
    if [[ ! -d "${vendor_dir}" ]]; then
        say_err "🎨 themes source not found: ${vendor_dir} — run bootstrapInitSubmodules first"
        return 1
    fi
    # no link needed since iterm2 imports directly from the vendor directory; just check presence
    say_ok "🎨 iterm2 themes are available (via vendor submodule)"

    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallOhMyZsh - symlink vendored oh-my-zsh to $ZSH
#
# Description:
#   Ensures `vendor/oh-my-zsh` is symlinked to `$ZSH`. Requires the
#   submodule to have been initialized first. Idempotent via ensureSymlink.
#
# Usage:    bootstrapInstallOhMyZsh
# Returns:  0 on success; 1 when vendor directory is missing.
# -----------------------------------------------------------------------------
function bootstrapInstallOhMyZsh () {
    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    if [[ ! -d "${vendor_omz}" ]]; then
        say_err "🧙 vendor/oh-my-zsh not found — run bootstrapInitSubmodules first"
        return 1
    fi
    if ensureSymlink "${vendor_omz}" "${ZSH}"; then
        say_ok "🧙 oh-my-zsh is installed (via vendor symlink)"
        return 0
    fi
    say_err "🧙 oh-my-zsh installation failed"
    return 1
}

# NOTE: bootstrapInstallOhMyTmux was consolidated into bootstrapCheckOhMyTmux

# -----------------------------------------------------------------------------
# bootstrapInstallPowershell10K - ensure powerlevel10k theme is present
#
# Description:
#   Validates that the powerlevel10k theme exists inside the vendored
#   oh-my-zsh custom themes directory. Reports installation status.
#
# Usage:    bootstrapInstallPowershell10K
# Returns:  0 when theme directory exists; 1 when missing.
# -----------------------------------------------------------------------------
function bootstrapInstallPowershell10K () {
    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    local p10k_path="${vendor_omz}/custom/themes/powerlevel10k"

    if [[ ! -d "${p10k_path}" ]]; then
        say_err "✨ powerlevel10k not found in vendor/oh-my-zsh/custom/themes — run bootstrapInitSubmodules first"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapCheckVim - check & configure vim + neovim (vendored)
#
# Description:
#   The vendored vendor/vim submodule provides a unified configuration for
#   both vim and neovim.  This function verifies the vendor directory exists,
#   runs `make install` (which symlinks ~/.vim and ~/.config/nvim, syncs
#   plugin submodules, generates helptags, and builds native artifacts),
#   then verifies the resulting symlinks.
#
# Usage:    bootstrapCheckVim [-n] [-x] [-h]
# Returns:  0 on success; 1 on failure.
# -----------------------------------------------------------------------------
function bootstrapCheckVim () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapCheckVim" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapCheckVim [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    say_warn "DEPRECATED: use 'make bootstrap-vim' or 'make vim-install' instead"

    local rc=0
    bootstrapInstallVim || rc=$?
    if [[ ${rc} -eq 0 ]]; then
        bootstrapConfigVim || rc=$?
    fi

    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# bootstrapInstallVim - install vim + neovim via vendored Makefile
#
# Description:
#   Runs `make install` in `vendor/vim` to symlink ~/.vim + ~/.config/nvim,
#   sync plugins, and build native artifacts. Requires the vendor submodule
#   to be initialized. Dry-run aware.
#
# Usage:    bootstrapInstallVim [-n] [-x] [-h]
# Returns:  0 on success; 1 when vendor is missing or make fails.
# -----------------------------------------------------------------------------
function bootstrapInstallVim () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapInstallVim" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapInstallVim [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local vendor_dir="${dot_bootstrap_directory}/vendor/vim"
    if [[ ! -d "${vendor_dir}" ]]; then
        say_err "📝 vendor/vim not found — run bootstrapInitSubmodules first"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    if [[ ! -f "${vendor_dir}/Makefile" ]]; then
        say_err "📝 vendor/vim/Makefile not found"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    if _is_dry; then
        say_plan "make -C ${vendor_dir} install  (symlink ~/.vim + ~/.config/nvim, sync plugins, build native artifacts)"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
    fi
    say_work "📝 running make install in vendor/vim (vim + neovim)"
    if ! make -C "${vendor_dir}" install \
        DOT_DRY_RUN="${DOT_DRY_RUN:-0}" \
        DOT_DEBUG="${DOT_DEBUG:-0}" \
        DOT_VERBOSE="${DOT_VERBOSE:-0}"; then
        say_err "📝 make install failed in vendor/vim"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    say_ok "📝 vim + neovim installed via vendor/vim"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapConfigVim - verify vim + neovim symlinks from make install
#
# Description:
#   Validates that ~/.vim (or ~/.config/nvim) symlinks created by
#   `bootstrapInstallVim` are healthy. Reports broken/missing links.
#   Read-only check; no writes.
#
# Usage:    bootstrapConfigVim [-n] [-x] [-h]
# Returns:  0 when symlinks are valid; 1 when checks fail.
# -----------------------------------------------------------------------------
function bootstrapConfigVim () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigVim" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigVim [-n] [-x] [-h]"; return 0
    fi
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local vendor_dir="${dot_bootstrap_directory}/vendor/vim"
    local nvim_config="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim"

    local rc=0
    if [[ -L "${HOME}/.vim" ]]; then
        say_ok "📝 ~/.vim symlink present"
    else
        say_warn "📝 ~/.vim is not a symlink — expected link to ${vendor_dir}"
        rc=1
    fi
    if [[ -L "${nvim_config}" ]]; then
        say_ok "📝 ${nvim_config} symlink present"
    else
        say_warn "📝 ${nvim_config} is not a symlink — expected link to ${vendor_dir}"
        rc=1
    fi
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return ${rc}
}

# -----------------------------------------------------------------------------
# bootstrapInitSubmodules - initialize tracked git submodules
#
# Description:
#   Recursively initializes the repo's .gitmodules. No-op (with warning)
#   when .gitmodules is absent. Required before any step that references
#   vendor/oh-my-zsh, vendor/oh-my-tmux, or vendor/figlet-fonts.
#
# Usage:    bootstrapInitSubmodules [-n] [-x] [-h]
# Returns:  0 on success or when .gitmodules is missing; 1 on git failure.
# -----------------------------------------------------------------------------
function bootstrapInitSubmodules () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapInitSubmodules" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapInitSubmodules [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    _dot_require_cmd "bootstrapInitSubmodules" git || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    if [[ ! -f "${dot_bootstrap_directory}/.gitmodules" ]]; then
        say_warn "no .gitmodules found, skipping submodule init"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    say_work "🧶 initializing git submodules"
    if dryrun git -C "${dot_bootstrap_directory}" submodule update --init --recursive; then
        say_ok "🧶 submodules initialized"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    say_err "🧶 submodule initialization failed"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapConfigNode - provision node via `n` under an arch-scoped prefix
#
# Description:
#   Ensures the requested node version is active at `${HOME}/.node-<arch>`.
#   Optionally installs npm packages from data/zsh.yaml when
#   DOT_INSTALL_LANG_DEPS is set. Idempotent and dry-run aware.
#
# Usage:    bootstrapConfigNode [-n] [-x] [-h]
# Env:      NODE_VERSION (default 20.10.0)
#           DOT_INSTALL_LANG_DEPS (>0 installs npm requirements)
# Returns:  0 on success; 1 when `n` missing or install fails.
# -----------------------------------------------------------------------------
function bootstrapConfigNode () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapConfigNode" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapConfigNode [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    local node_version="${NODE_VERSION:-20.10.0}"
    local n_prefix
    n_prefix="${HOME}/.node-$(uname -m)"

    _dot_require_cmd "bootstrapConfigNode" n || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    export N_PREFIX="${n_prefix}"
    dry_mkdir "${n_prefix}"

    # idempotent: only invoke `n` if requested version is not already active
    local active_version=""
    if [[ -x "${n_prefix}/bin/node" ]]; then
        active_version="$("${n_prefix}/bin/node" --version 2>/dev/null | sed 's/^v//')"
    fi
    if [[ "${active_version}" == "${node_version}" ]]; then
        say_skip "🟢 node ${node_version} already active"
    else
        say_work "🟢 ensuring node ${node_version} via n"
        if ! dryrun n "${node_version}"; then
            say_err "🟢 failed to install node ${node_version}"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
        fi
    fi
    say_ok "🟢 node ${node_version} is ready"

    if [[ "${DOT_INSTALL_LANG_DEPS:-0}" -gt 0 ]]; then
        local data_file="${dot_bootstrap_directory}/data/zsh.yaml"
        if [[ ! -f "${data_file}" ]]; then
            say_warn "data/zsh.yaml not found, skipping npm packages"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        if ! command -v yq >/dev/null 2>&1; then
            say_warn "yq not found, skipping npm packages"
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        local npm_packages
        npm_packages="$(yq '.languages.node.npm.requirements[]' "${data_file}" 2>/dev/null)"
        if [[ -z "${npm_packages}" ]]; then
            [[ ${_opt_debug} -eq 1 ]] && set +x; return 0
        fi
        while IFS= read -r pkg; do
            if npm list -g --depth=0 "${pkg}" &>/dev/null; then
                say_skip "📦 npm ${pkg} already installed"
            else
                say_work "📦 installing npm ${pkg}"
                dryrun npm install -g "${pkg}" || say_warn "failed to install ${pkg}"
            fi
        done <<< "${npm_packages}"
    fi

    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 0
}

# -----------------------------------------------------------------------------
# bootstrapInstallOhMyZshCustomPlugins - sync vendored OMZ custom plugins
#
# Description:
#   Reads `data/zsh.yaml` to determine which oh-my-zsh custom plugin
#   submodules under vendor/ohmyzsh/custom/plugins to init (enabled) or
#   deinit (disabled). Idempotent: skips already-initialized submodules
#   and only deinit's submodules that have content.
#
# Usage:    bootstrapInstallOhMyZshCustomPlugins [-n] [-x] [-h]
# Returns:  0 when all sync operations succeed; 1 on any init failure.
# -----------------------------------------------------------------------------
function bootstrapInstallOhMyZshCustomPlugins () {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapInstallOhMyZshCustomPlugins" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        echo "Usage: bootstrapInstallOhMyZshCustomPlugins [-n] [-x] [-h]"; return 0
    fi
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"; [[ ${_opt_dry} -eq 1 ]] && DOT_DRY_RUN=1
    [[ ${_opt_debug} -eq 1 ]] && set -x

    say_warn "DEPRECATED: use 'make bootstrap-omz-plugins' or 'make omz-sync-plugins' instead"

    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    local zsh_yaml="${dot_bootstrap_directory}/data/zsh.yaml"

    if [[ ! -d "${vendor_omz}" ]]; then
        say_err "🧩 vendor/ohmyzsh not found"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    if [[ ! -f "${zsh_yaml}" ]]; then
        say_err "🧩 data/zsh.yaml not found: ${zsh_yaml}"
        [[ ${_opt_debug} -eq 1 ]] && set +x; return 1
    fi
    _dot_require_cmd "bootstrapInstallOhMyZshCustomPlugins" yq git \
        || { [[ ${_opt_debug} -eq 1 ]] && set +x; return 1; }

    say_work "🧩 syncing oh-my-zsh custom plugin submodules"
    local enabled_repos disabled_repos
    enabled_repos=$(yq '.plugins.custom[] | select(.enabled == true) | .repo' "${zsh_yaml}")
    disabled_repos=$(yq '.plugins.custom[] | select(.enabled == false) | .repo' "${zsh_yaml}")
    local failed=0 repo submodule_path
    while IFS= read -r repo; do
        [[ -z "${repo}" ]] && continue
        submodule_path="custom/plugins/${repo}"
        if [[ -f "${vendor_omz}/${submodule_path}/.git" || -d "${vendor_omz}/${submodule_path}/.git" ]]; then
            say_skip "➕ ${submodule_path} (already initialized)"
            continue
        fi
        say_work "➕ init ${submodule_path}"
        if ! dryrun git -C "${vendor_omz}" submodule update --init "${submodule_path}"; then
            say_err "failed to init ${submodule_path}"
            failed=1
        fi
    done <<< "${enabled_repos}"
    while IFS= read -r repo; do
        [[ -z "${repo}" ]] && continue
        submodule_path="custom/plugins/${repo}"
        if [[ -d "${vendor_omz}/${submodule_path}" && ( -f "${vendor_omz}/${submodule_path}/.git" || -d "${vendor_omz}/${submodule_path}/.git" ) ]]; then
            say_work "➖ deinit ${submodule_path} (disabled)"
            dryrun git -C "${vendor_omz}" submodule deinit --force "${submodule_path}" || true
        fi
    done <<< "${disabled_repos}"

    if [[ ${failed} -eq 0 ]]; then
        say_ok "🧩 oh-my-zsh custom plugins synced"
        [[ ${_opt_debug} -eq 1 ]] && set +x
        return 0
    fi
    say_err "🧩 oh-my-zsh custom plugin sync failed"
    [[ ${_opt_debug} -eq 1 ]] && set +x
    return 1
}

# -----------------------------------------------------------------------------
# bootstrapSystem - orchestrate the full dotfiles bootstrap
#
# Description:
#   Top-level driver. Runs the bootstrap pipeline in dependency order:
#     1. Homebrew + formula/cask deps
#     2. iCloud link + git submodules
#     3. Shell configuration (zsh, bash)
#     4. SSH + git config
#     5. Language toolchains (python, node)
#     6. Terminal config (iTerm2, figlet)
#     7. oh-my-zsh + custom plugins
#     8. oh-my-tmux
#   Each step short-circuits the run on failure. Honors DOT_DRY_RUN from the
#   environment; -n propagates as DOT_DRY_RUN=1 to every child step.
#
# Usage:    bootstrapSystem [-n] [-x] [-h]
# Env:      DOT_DRY_RUN, DOT_INSTALL_LANG_DEPS, ICLOUD
# Returns:  0 on full success; first non-zero return from any step otherwise.
# -----------------------------------------------------------------------------
function bootstrapSystem() {
    local _opt_dry _opt_debug _opt_help OPTIND=1
    _dot_std_opts "bootstrapSystem" "$@" || return $?
    if [[ ${_opt_help} -eq 1 ]]; then
        cat <<'EOF'
Usage: bootstrapSystem [-n] [-x] [-h]
  -n   dry-run (sets DOT_DRY_RUN=1 for all child steps)
  -x   xtrace
  -h   show this help message
EOF
        return 0
    fi
    if [[ ${_opt_dry} -eq 1 ]]; then
        DOT_DRY_RUN=1
        export DOT_DRY_RUN
    fi
    [[ ${_opt_debug} -eq 1 ]] && set -x

    # load secrets (best-effort; missing secrets must not abort bootstrap)
    if command -v __load_secrets >/dev/null 2>&1; then
        __load_secrets || say_warn "__load_secrets reported non-zero"
    fi

    local rc=0
    bootstrapCheckBrew                    || { rc=$?; say_err "bootstrapCheckBrew failed (rc=${rc})"; }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckDependencies         || { rc=$?; say_err "bootstrapCheckDependencies failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckCaskDependencies     || { rc=$?; say_err "bootstrapCheckCaskDependencies failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckCloud                || { rc=$?; say_err "bootstrapCheckCloud failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapInitSubmodules            || { rc=$?; say_err "bootstrapInitSubmodules failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigureZsh              || { rc=$?; say_err "bootstrapConfigureZsh failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigBash                || { rc=$?; say_err "bootstrapConfigBash failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigSsh                 || { rc=$?; say_err "bootstrapConfigSsh failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigGit                 || { rc=$?; say_err "bootstrapConfigGit failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigPython              || { rc=$?; say_err "bootstrapConfigPython failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigNode                || { rc=$?; say_err "bootstrapConfigNode failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigIterm               || { rc=$?; say_err "bootstrapConfigIterm failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapConfigFiglet              || { rc=$?; say_err "bootstrapConfigFiglet failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckOhMyZsh              || { rc=$?; say_err "bootstrapCheckOhMyZsh failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapInstallOhMyZshCustomPlugins || { rc=$?; say_err "bootstrapInstallOhMyZshCustomPlugins failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckOhMyTmux             || { rc=$?; say_err "bootstrapCheckOhMyTmux failed (rc=${rc})"; } }
    [[ ${rc} -eq 0 ]] && { bootstrapCheckVim                   || { rc=$?; say_err "bootstrapCheckVim failed (rc=${rc})"; } }

    [[ ${_opt_debug} -eq 1 ]] && set +x
    if [[ ${rc} -eq 0 ]]; then
        say_done "bootstrap complete"
        return 0
    fi
    return ${rc}
}

# -----------------------------------------------------------------------------
# _dot_bootstrap_export_functions - export all bootstrap functions
#
# Description:
#   Exports every defined function so sub-shells (bash) inherit them when
#   this file has been sourced. In zsh, uses `typeset -fx` since zsh does
#   not support `export -f`.
#
# Usage:    _dot_bootstrap_export_functions   (called internally)
# Returns:  0 always.
# -----------------------------------------------------------------------------
_dot_bootstrap_export_functions () {
    local fn
    local fns=(
        _is_dry dryrun
        _dot_std_opts _dot_require_cmd
        say_step say_info say_ok say_skip say_work say_warn say_err say_plan say_done
        dry_mkdir dry_rm dry_rmrf dry_mv dry_cp dry_defaults_write
        ensureSymlink
        resolveBrewfilePath resolveBrewfileCaskPath
        installDependencies installCaskDependencies
        bootstrapPrint bootstrapInfo bootstrapDeps
        bootstrapCheckBrew bootstrapInstallBrew
        bootstrapCheckDependencies bootstrapCheckCaskDependencies
        bootstrapCheckCloud bootstrapLinkCloud
        bootstrapCheckJq bootstrapInstallJq
        bootstrapCheckZsh bootstrapInstallZsh bootstrapConfigureZsh
        bootstrapConfigBash bootstrapConfigCsh bootstrapConfigKsh
        bootstrapConfigFish bootstrapConfigPwsh
        bootstrapConfigSsh bootstrapConfigGit bootstrapConfigGh
        bootstrapConfigPython bootstrapConfigNode
        bootstrapCheckIterm bootstrapInstallIterm bootstrapConfigIterm
        bootstrapConfigFiglet
        bootstrapCheckOhMyZsh bootstrapInstallOhMyZsh bootstrapConfigOhMyZsh
        bootstrapCheckOhMyZshPlugin bootstrapInstallOhMyZshPlugin
        bootstrapListOhMyZshPlugin bootstrapListOhMyZshPluginConfiguredPlugins
        bootstrapInstallOhMyZshCustomPlugins bootstrapConfigZshCustomPlugins
        bootstrapCheckPowershell10K bootstrapInstallPowershell10K bootstrapConfigPowershell10K
        bootstrapCheckOhMyTmux
        bootstrapCheckThemes bootstrapInstallThemes
        bootstrapCheckFonts bootstrapInstallFonts
        bootstrapCheckVim bootstrapInstallVim bootstrapConfigVim
        bootstrapInitSubmodules
        bootstrapSystem
    )
    if [ -n "${BASH_VERSION:-}" ]; then
        for fn in "${fns[@]}"; do
            # only export functions that are actually defined
            declare -F "${fn}" >/dev/null 2>&1 && export -f "${fn}" 2>/dev/null || true
        done
    elif [ -n "${ZSH_VERSION:-}" ]; then
        for fn in "${fns[@]}"; do
            typeset -f "${fn}" >/dev/null 2>&1 && typeset -fx "${fn}" 2>/dev/null || true
        done
    fi
}

if _dot_bootstrap_is_sourced; then
    # Sourced: expose functions, do NOT run any configuration steps.
    _dot_bootstrap_export_functions
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                DOT_DRY_RUN=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    bootstrapPrint
    bootstrapInfo
    bootstrapSystem
fi

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


if [ ! -d "${dot_bootstrap_directory}" ]; then
    echo "❌  ${dot_bootstrap_directory} does not exist"
    exit 1
fi

. "${dot_bootstrap_directory}/modules/static/lib/internal.sh"

# resolve a Brewfile path based on CPU architecture
function resolveBrewfilePath () {
    local arch="${CPU_ARCHITECTURE:-$(uname -m)}"
    local file="${1:-${ICLOUD}/dot/Brewfile.${arch}}"
    if [[ -f "$file" ]]; then
        echo "$file"
    return 0
    else
        echo "Brewfile not found at $file"
    return 1
    fi
}


# ──────────────────────────────────────────────────────────────────────────────
# 🎨 output palette — keep messages punchy, scannable, and consistent.
#    Every mutating step funnels through `dry_*` so DOT_DRY_RUN=1 = NO writes.
# ──────────────────────────────────────────────────────────────────────────────
DOT_DRY_RUN="${DOT_DRY_RUN:-0}"

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

# ⚫️ dry-run wrapper: in DRY mode, ANNOUNCE the planned command and DO NOT run.
function dryrun () {
    if _is_dry; then
        say_plan "$*"
        return 0
    fi
    "$@"
}

# 🧱 idempotent + dry-aware filesystem primitives.
# Each one inspects the current state first; only mutates when needed.
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

# defaults write — idempotent: read current value first, only write if it differs.
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


# ⚫️ preflight checks and information
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

# prints ⚫️ start banner
function bootstrapPrint () {
    if _is_dry; then
        echo "🔮 DRY-RUN MODE — no system changes will be made"
    fi
    say_step "executing ${dot_boostrap_file}"
}


# installs ⚫️ dependencies
function bootstrapDeps () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        say_err "📋 no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    if dryrun brew bundle install --file "${brewfile}"; then
        say_ok "📋 dependencies ok"
        return 0
    fi
    say_err "📋 dependencies failed"
    return 1
}

# checks and installs ⚫️ dependencies (idempotent: only installs when bundle check fails or DOT_DEPS=1)
function bootstrapCheckDependencies () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        say_err "📋 no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    # yq is a first-class dependency required for parsing data/zsh.yaml
    if ! command -v yq &>/dev/null; then
        say_work "🧰 yq not found — installing via brew"
        dryrun brew install yq || { say_err "failed to install yq"; return 1; }
    fi

    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        say_work "📋 reinstalling brew bundle (DOT_DEPS=${dot_bootstrap_deps})"
        installDependencies
    elif brew bundle check --file "${brewfile}" > /dev/null 2>&1; then
        say_skip "📋 brew bundle satisfied (${brewfile})"
    else
        say_work "📋 brew bundle missing items — installing"
        installDependencies
    fi
}

# installs ⚫️ dependencies
function installDependencies () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        say_err "📋 no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    if dryrun brew bundle install --file "${brewfile}"; then
        say_ok "📋 dependencies installed"
        return 0
    fi
    say_err "📋 dependencies installation failed"
    return 1
}

# ⚫️ configures python environment for ⚫️
function bootstrapConfigPython () {
    local desired_version="3.11"
    local arch
    arch="$(uname -m)"
    local venv_name="${desired_version}-${arch}-base"
    local venv_path="${HOME}/.venv/${venv_name}"

    if ! command -v uv &> /dev/null; then
        say_err "🐍 uv is not installed (expected via Brewfile)"
        return 1
    fi

    dry_mkdir "${HOME}/.venv"
    if [[ ! -d "${venv_path}" ]]; then
        say_work "🐍 creating python venv ${venv_name}"
        if ! dryrun uv venv --seed --python "${desired_version}" "${venv_path}"; then
            say_err "🐍 failed to create python venv"
            return 1
        fi
    else
        say_skip "🐍 python venv ${venv_name} already exists"
    fi

    say_ok "🐍 python venv ${venv_name} is ready"

    if [[ "${DOT_INSTALL_LANG_DEPS:-0}" -gt 0 ]]; then
        local data_file="${dot_bootstrap_directory}/data/zsh.yaml"
        if [[ ! -f "${data_file}" ]]; then
            say_warn "data/zsh.yaml not found, skipping pip packages"
            return 0
        fi
        local pip_packages
        pip_packages="$(yq '.languages.python.pip.requirements[]' "${data_file}" 2>/dev/null)"
        if [[ -z "${pip_packages}" ]]; then
            return 0
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

    return 0
}

# ⚫️ links iCloud directory
function bootstrapLinkCloud () {
    if [[ ! -d "${icloud_directory}" ]]; then
        say_err "☁️  iCloud directory not found: ${icloud_directory}"
        return 1
    fi

    if ensureSymlink "${icloud_directory}" "${icloud_link}"; then
        ICLOUD="${icloud_link}"
        export ICLOUD
        say_ok "☁️  ${icloud_link} → ${icloud_directory}"
        return 0
    fi

    say_err "☁️  ${icloud_link} is not linked to ${icloud_directory}"
    return 1
}

# ⚫️ checks iCloud directory and links it
function bootstrapCheckCloud () {
    if [[ -d "${icloud_directory}" ]]; then
        say_ok "☁️  iCloud is enabled"
        bootstrapLinkCloud || return 1
    else
        say_err "☁️  iCloud is not enabled (${icloud_directory} missing)"
        return 1
    fi
    return 0
}

# ⚫️ installs and configures Oh My Tmux
function bootstrapCheckOhMyTmux () {
    local vendor_tmux="${dot_bootstrap_directory}/vendor/oh-my-tmux"
    local plugin_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/tmux/plugins"

    if [[ ! -d "${vendor_tmux}" ]]; then
        say_err "🪴 vendor/oh-my-tmux not found — run bootstrapInitSubmodules first"
        return 1
    fi

    # link config files directly to vendor paths (idempotent via ensureSymlink)
    ensureSymlink "${vendor_tmux}/.tmux.conf"       "${HOME}/.tmux.conf"       || return 1
    ensureSymlink "${vendor_tmux}/.tmux.conf.local" "${HOME}/.tmux.conf.local" || return 1

    # ensure the tpm plugin directory exists (TMUX_PLUGIN_MANAGER_PATH)
    dry_mkdir "${plugin_dir}"

    # back up any legacy ~/.tmux directory or symlink — no longer needed
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
        if tmux has-session -t bootstrap 2>/dev/null; then
            tmux kill-session -t bootstrap
        fi
        tmux new-session -d -s bootstrap \
            && tmux send-keys -t bootstrap C-I \
            && tmux kill-session -t bootstrap
    fi
    say_ok "🪴 tmux is configured"
}

# ⚫️ configures figlet (idempotent: clone or pull)
function bootstrapConfigFiglet () {
    if [[ ! -d "$HOME"/.figlet ]]; then
        say_work "🅰️ cloning figlet-fonts → ~/.figlet"
        dryrun git clone git@github.com:xero/figlet-fonts.git "$HOME"/.figlet
    else
        say_work "🅰️ updating ~/.figlet"
        dryrun git -C "$HOME"/.figlet pull --ff-only
    fi
    say_ok "🅰️ figlet is configured"
}

# ⚫️ configures iterm2 (idempotent: defaults are diffed; theme imports run only when not in dry-run)
function bootstrapConfigIterm () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local schemes_root="${ICLOUD}/dot/terminal/themes/iTerm2-Color-Schemes"
    local catppuccin_root="${ICLOUD}/dot/terminal/themes/catppuccin/catppuccin"

    # import color schemes (these scripts are themselves idempotent for already-imported schemes)
    if [[ -x "${schemes_root}/tools/import-scheme.sh" ]]; then
        if _is_dry; then
            say_plan "${schemes_root}/tools/import-scheme.sh -v ${schemes_root}/schemes/"
        else
            say_work "🎨 importing iTerm2-Color-Schemes"
            "${schemes_root}/tools/import-scheme.sh" -v "${schemes_root}/schemes/" >/dev/null
        fi
    else
        say_warn "🎨 iTerm2-Color-Schemes import script missing (${schemes_root})"
    fi

    if [[ -x "${schemes_root}/tools/import-scheme.sh" && -d "${catppuccin_root}/colors" ]]; then
        if _is_dry; then
            say_plan "${schemes_root}/tools/import-scheme.sh -v ${catppuccin_root}/colors/"
        else
            say_work "🎨 importing catppuccin schemes"
            "${schemes_root}/tools/import-scheme.sh" -v "${catppuccin_root}/colors/" >/dev/null
        fi
    fi

    # idempotent defaults: only writes when the value differs
    dry_defaults_write com.googlecode.iterm2 PrefsCustomFolder       -string "${icloud_directory}/dot/terminal"
    dry_defaults_write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool  true

    say_ok "🖥️  iterm2 is configured (restart iterm2 to pick up changes)"
}

# ⚫️ configures ssh client
function bootstrapConfigSsh () {
    local ssh_config="${HOME}/.ssh/config"
    local ssh_config_dot="${ICLOUD}/dot/ssh/config"
    local ssh_root_dot="${ICLOUD}/dot/ssh"
    local ssh_config_d_dot="${ICLOUD}/dot/ssh/config.d"
    local ssh_config_d="${HOME}/.ssh/config.d"
    local ssh_keys=()

    dry_mkdir "${HOME}/.ssh"
    dry_mkdir "${ssh_config_d}"

    ensureSymlink "${ssh_config_dot}" "${ssh_config}" || return 1

    # link any per-host/include config snippets from ${ICLOUD}/dot/ssh/config.d
    # into ${HOME}/.ssh/config.d preserving the original filename
    if [[ -d "${ssh_config_d_dot}" ]]; then
        local ssh_config_snippet snippet_name
        while IFS= read -r -d '' ssh_config_snippet; do
            snippet_name="$(basename "${ssh_config_snippet}")"
            ensureSymlink "${ssh_config_snippet}" "${ssh_config_d}/${snippet_name}" || return 1
        done < <(find "${ssh_config_d_dot}" -type f -print0)
    fi

    # gather ssh keys from the top-level ${ICLOUD}/dot/ssh directory only,
    # so we don't recurse into config.d/ (which is handled above)
    while IFS= read -r -d '' ssh_key; do
        ssh_keys+=("${ssh_key}")
    done < <(find "${ssh_root_dot}" -maxdepth 1 -type f -print0)

    local ssh_key_name
    for ssh_key in "${ssh_keys[@]}"; do
        ssh_key_name="$(basename "${ssh_key}")"
        # skip the top-level ssh config, it is linked above
        if [[ "${ssh_key_name}" == "config" ]]; then
            continue
        fi
        local ssh_key_path="${HOME}/.ssh/${ssh_key_name}"
        # a link exists with this identity
        ensureSymlink "${ssh_key}" "${ssh_key_path}" || return 1
    done
    say_ok "🔑 your ssh client is configured"

}

# ⚫️ configures git
function bootstrapConfigGit () {
    local git_config="${HOME}/.gitconfig"
    local git_config_dot="${ICLOUD}/dot/git/config"

    ensureSymlink "${git_config_dot}" "${git_config}" || return 1
    say_ok "🐙 your git installation is configured"
}

# ⚫️ configures gh (idempotent via ensureSymlink + dry-run safe)
function bootstrapConfigGh () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local git_config_dir_dot="${icloud_directory}/dot/git/gh"
    local git_config_dir="${HOME}/.config/gh"

    dry_mkdir "${git_config_dir}"
    ensureSymlink "${git_config_dir_dot}/config.yml" "${git_config_dir}/config.yml" || return 1
    ensureSymlink "${git_config_dir_dot}/hosts.yml"  "${git_config_dir}/hosts.yml"  || return 1

    say_ok "🐱 your gh installation is configured"
}

# ⚫️ configures zsh
#
# Links the git-tracked zshrc (`$DOT_DIRECTORY/zshrc`) to `~/.zshrc` and,
# optionally, mirrors `data/zsh.yaml` into iCloud (the only zsh artifact we
# still duplicate there). The legacy iCloud `rc` file is no longer written;
# git is the source of truth for the rc.
#
# Flags:
#   -r   link `$DOT_DIRECTORY/zshrc` -> `~/.zshrc` (default when neither
#        -r nor -d is supplied)
#   -d   mirror `$DOT_DIRECTORY/data/zsh.yaml` ->
#        `$ICLOUD/dot/shell/zsh/zsh.yaml` (only when source is newer)
#   -n   dry-run
#   -x   debug / xtrace
#   -h   show usage
function bootstrapConfigureZsh () {
    local dry_mode=0
    local handles_config=0
    local handles_rc=0
    local debug=0
    local OPTIND=1

    while getopts ":ndhrx" opt; do
        case ${opt} in
            d) handles_config=1 ;;
            r) handles_rc=1 ;;
            n) dry_mode=1 ;;
            x) debug=1 ;;
            h)
                echo "Usage: bootstrapConfigureZsh [-r] [-d] [-n] [-x] [-h]"
                echo "  -r   link \$DOT_DIRECTORY/zshrc -> ~/.zshrc (default)"
                echo "  -d   mirror data/zsh.yaml -> \$ICLOUD/dot/shell/zsh/zsh.yaml"
                echo "  -n   dry-run"
                echo "  -x   debug"
                echo "  -h   show this help message"
                return 0
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2 ;;
            :)  echo "Option -$OPTARG requires an argument." >&2 ;;
        esac
    done

    # default action: link rc
    if [[ ${handles_rc} -eq 0 && ${handles_config} -eq 0 ]]; then
        handles_rc=1
    fi

    # honor a function-scoped DOT_DRY_RUN so dryrun/ensureSymlink see -n
    local DOT_DRY_RUN="${DOT_DRY_RUN:-0}"
    if [[ ${dry_mode} -gt 0 ]]; then
        DOT_DRY_RUN=1
    fi

    [[ ${debug} -gt 0 ]] && set -x

    local rc_source="${dot_bootstrap_directory}/zshrc"
    local rc_target="${HOME}/.zshrc"

    if [[ ! -f "${rc_source}" ]]; then
        echo "❌ rc source missing: ${rc_source}"
        [[ ${debug} -gt 0 ]] && set +x
        return 1
    fi

    local zsh_bin
    zsh_bin="$(command -v zsh)"
    if [[ -z "${zsh_bin}" ]]; then
        echo "❌ zsh is not installed"
        [[ ${debug} -gt 0 ]] && set +x
        return 1
    fi

    # ensure user's login shell is zsh
    local current_shell
    current_shell="$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")"
    if [[ "${current_shell}" != "zsh" ]]; then
        dryrun chsh -s "${zsh_bin}" "${USER}"
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

    # -d: mirror data/zsh.yaml to iCloud (still treated as duplicated data)
    if [[ ${handles_config} -gt 0 ]]; then
        if [[ -z "${ICLOUD:-}" ]]; then
            echo "❌ ICLOUD is not set; cannot mirror zsh.yaml"
            [[ ${debug} -gt 0 ]] && set +x
            return 1
        fi

        local data_source="${dot_bootstrap_directory}/data/zsh.yaml"
        local data_dest="${icloud_directory}/dot/shell/zsh/zsh.yaml"
        local data_dest_dir="${data_dest%/*}"

        if [[ ! -f "${data_source}" ]]; then
            echo "❌ data source missing: ${data_source}"
            [[ ${debug} -gt 0 ]] && set +x
            return 1
        fi

        if [[ ! -d "${data_dest_dir}" ]]; then
            dryrun mkdir -p "${data_dest_dir}"
        fi

        # copy only when source is newer (or destination missing)
        if [[ ! -f "${data_dest}" || "${data_source}" -nt "${data_dest}" ]]; then
            dryrun cp "${data_source}" "${data_dest}"
            [[ ${debug} -gt 0 ]] && echo "✅  ${data_source} -> ${data_dest}"
        else
            [[ ${debug} -gt 0 ]] && echo "⏭️  ${data_dest} is up to date"
        fi
    fi

    [[ ${debug} -gt 0 ]] && set +x
    say_ok "🐢 zsh shell is configured (restart open shells)"
    return 0
}

# ⚫️ configures bash
function bootstrapConfigBash () {
    local rc="${HOME}/.bashrc"

    ensureSymlink "${ICLOUD}/dot/shell/bash/rc" "${rc}" || return 1
    say_ok "🐚 bash shell is configured (restart open shells)"
}

# ⚫️ configures fish
function bootstrapConfigFish () {
    local rc="${HOME}/.config/fish/config.fish"
    dry_mkdir "$(dirname "${rc}")"
    ensureSymlink "${ICLOUD}/dot/shell/fish/rc" "${rc}" || return 1
    say_ok "🐟 fish shell is configured (restart open shells)"
}

# ⚫️ configures ksh
function bootstrapConfigKsh () {
    local rc="${HOME}/.kshrc"
    ensureSymlink "${ICLOUD}/dot/shell/ksh/rc" "${rc}" || return 1
    say_ok "🐘 ksh shell is configured (restart open shells)"
}

# ⚫️ configures csh
function bootstrapConfigCsh () {
    local rc="${HOME}/.cshrc"
    ensureSymlink "${ICLOUD}/dot/shell/csh/rc" "${rc}" || return 1
    say_ok "🦜 csh shell is configured (restart open shells)"
}

# ⚫️ configures pwsh
function bootstrapConfigPwsh () {
    return 0
}

# ⚫️ configures oh-my-zsh
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

# ⚫️ (DEPRECATED) custom plugin loader — was clobbering ~/.zshrc; replaced by
# bootstrapInstallOhMyZshCustomPlugins which uses the vendored ohmyzsh submodule.
function bootstrapConfigZshCustomPlugins () {
    say_warn "bootstrapConfigZshCustomPlugins is deprecated — use bootstrapInstallOhMyZshCustomPlugins"
    return 0
}

# ⚫️ checks oh-my-zsh plugin
function bootstrapCheckOhMyZshPlugin () {
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
}

# ⚫️ lists oh-my-zsh configured plugins
function bootstrapListOhMyZshPluginConfiguredPlugins () {
    # get plugins from j
    plugins=$(
        find "${HOME}/.oh-my-zsh/custom/plugins/" -maxdepth 1 -type d -exec basename {} \;
    )
    if [[ -n "${plugins}" ]]; then
        echo "🛠️  configured oh-my-zsh plugins:"
        for plugin in ${plugins}; do
            echo " - ${plugin}"
        done
    else
        echo "❌  no configured oh-my-zsh plugins found"
    fi
}

# ⚫️ lists oh-my-zsh plugins
function bootstrapListOhMyZshPlugin () {
    listLocal=0
    while getopts ":lch" opt; do
        case ${opt} in
            l)
                # echo "listing local plugins"
                listLocal=1
                ;;
            c)
                # echo "listing configured plugins"
                listConfigured=1
                ;;
            h)
                echo "Usage: ${0} [-l] [-h]"
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

    # list all plugins
    if [ "${listLocal}" -gt 0 ]; then
        # list local plugins
        find "${HOME}/.oh-my-zsh/custom/plugins/" -maxdepth 1 -type d -exec basename {} \;
    fi

    if [ "${listConfigured}" -gt 0 ]; then
        # get plugins from file
        yq '.plugins.custom[].owner' "${HOME}/.dot/data/zsh.yaml" | \
        while IFS= read -r plugin; do
            echo " - ${plugin}"
        done
    fi

}

# ⚫️ installs oh-my-zsh plugin (idempotent)
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
}

# ⚫️ installs powerlevel10k
function bootstrapConfigPowershell10K () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    ensureSymlink "${icloud_directory}/dot/shell/powerlevel/rc.zsh" "${HOME}/.p10k.zsh" || return 1
    say_ok "✨ powerlevel10k is configured"
}

# ⚫️ checks brew installation
function bootstrapCheckBrew () {
    if command -v brew &> /dev/null; then
        say_skip "🍺 brew already installed"
        return 0
    fi
    say_work "🍺 installing brew"
    bootstrapInstallBrew
}

# ⚫️ checks zsh installation
function bootstrapCheckZsh () {
    if command -v zsh &> /dev/null; then
        say_skip "🐢 zsh already installed"
    else
        say_work "🐢 installing zsh"
        bootstrapInstallZsh
    fi

    if [[ "$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")" == "zsh" ]]; then
        say_skip "🐢 zsh is already the default login shell"
    else
        say_work "🐢 zsh is not the default login shell — configuring"
        bootstrapConfigureZsh
    fi
    return 0
}

# ⚫️ checks jq installation
function bootstrapCheckJq () {
    if command -v jq &> /dev/null; then
        say_skip "🧪 jq already installed"
        return 0
    fi
    say_work "🧪 installing jq"
    bootstrapInstallJq
}

# ⚫️ checks iterm2 installation
function bootstrapCheckIterm () {
    if mdfind "kMDItemKind == 'Application'" 2>/dev/null | grep -q -Ei '^/Applications/[i]Term.*?.app'; then
        say_skip "🖥️  iterm2 already installed"
    else
        say_work "🖥️  installing iterm2"
        bootstrapInstallIterm || return 1
    fi
    bootstrapConfigIterm
}

# ⚫️ checks fonts installation
function bootstrapCheckFonts () {
    true
    true
}

# ⚫️ checks iterm2 themes installation
function bootstrapCheckThemes () {
    if [[ -d "${HOME}/.themes" ]]; then
        say_skip "🎨 iterm2 themes already installed"
        return 0
    fi
    say_work "🎨 installing iterm2 themes"
    bootstrapInstallThemes
}

# ⚫️ checks oh-my-zsh installation
function bootstrapCheckOhMyZsh () {
    if [[ -d "$HOME/.oh-my-zsh" || -L "$HOME/.oh-my-zsh" ]]; then
        say_skip "🧙 oh-my-zsh already present"
    else
        say_work "🧙 installing oh-my-zsh"
        bootstrapInstallOhMyZsh
    fi
    bootstrapConfigOhMyZsh
}

# ⚫️ checks powerlevel10k installation
function bootstrapCheckPowershell10K () {
    if [[ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]]; then
        say_work "✨ installing powerlevel10k"
        bootstrapInstallPowershell10K || return 1
    fi
    if [[ -L "${HOME}/.p10k.zsh" || -f "${HOME}/.p10k.zsh" ]]; then
        # let bootstrapConfigPowershell10K resolve idempotency via ensureSymlink
        bootstrapConfigPowershell10K
    else
        say_work "✨ powerlevel10k is not configured — configuring"
        bootstrapConfigPowershell10K
    fi
}

# ⚫️ installs brew
function bootstrapInstallBrew () {
    if _is_dry; then
        say_plan "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 0
    fi
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        say_ok "🍺 brew is installed"
        return 0
    fi
    say_err "🍺 brew installation failed"
    return 1
}

# ⚫️ installs zsh
function bootstrapInstallZsh () {
    if dryrun brew install zsh; then
        say_ok "🐢 zsh is installed"
        return 0
    fi
    say_err "🐢 zsh installation failed"
    return 1
}

# ⚫️ installs jq
function bootstrapInstallJq () {
    if dryrun brew install jq; then
        say_ok "🧪 jq is installed"
        return 0
    fi
    say_err "🧪 jq installation failed"
    return 1
}

# ⚫️ installs iterm2
function bootstrapInstallIterm () {
    if dryrun brew install --cask iterm2; then
        say_ok "🖥️  iterm2 is installed"
        return 0
    fi
    say_err "🖥️  iterm2 installation failed"
    return 1
}

# ⚫️ installs fonts (idempotent: only copies fonts not already present in ~/Library/Fonts)
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

# ⚫️ installs iterm2 themes (idempotent: only clones if missing)
function bootstrapInstallThemes () {
    if [[ -d "${HOME}/.themes" ]]; then
        say_skip "🎨 ~/.themes already exists"
        return 0
    fi
    if ! dryrun gh repo clone apsamuel/iTerm2-Color-Schemes "${HOME}/.themes"; then
        say_err "🎨 iterm2 themes installation failed"
        return 1
    fi
    if ! _is_dry; then
        bash "${HOME}/.themes/tools/import-scheme.sh" >/dev/null
    else
        say_plan "bash ${HOME}/.themes/tools/import-scheme.sh"
    fi
    say_ok "🎨 iterm2 themes are installed"
    return 0
}

# ⚫️ installs oh-my-zsh
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

# ⚫️ installs powerlevel10k
function bootstrapInstallPowershell10K () {
    local vendor_omz="${dot_bootstrap_directory}/vendor/oh-my-zsh"
    local p10k_path="${vendor_omz}/custom/themes/powerlevel10k"

    if [[ ! -d "${p10k_path}" ]]; then
        say_err "✨ powerlevel10k not found in vendor/oh-my-zsh/custom/themes — run bootstrapInitSubmodules first"
        return 1
    fi
    say_skip "✨ powerlevel10k is bundled in vendor/oh-my-zsh custom themes"
    return 0
}

# ⚫️ checks vim installation
function bootstrapCheckVim () {
    if command -v vim &> /dev/null; then
        say_skip "📝 vim already installed"
        return 0
    fi
    say_work "📝 installing vim"
    bootstrapInstallVim
}

# ⚫️ installs vim
function bootstrapInstallVim () {
    if dryrun brew install vim; then
        say_ok "📝 vim is installed"
        return 0
    fi
    say_err "📝 vim installation failed"
    return 1
}

# ⚫️ configures vim (idempotent: ensureSymlink for each artifact)
function bootstrapConfigVim () {
    say_step "configuring vim"
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    ensureSymlink "${icloud_directory}/dot/shell/vim/rc"          "${HOME}/.vimrc"        || return 1
    ensureSymlink "${icloud_directory}/dot/shell/vim/rc-dir"      "${HOME}/.vim"          || return 1
    ensureSymlink "${icloud_directory}/dot/shell/vim/vim_runtime" "${HOME}/.vim_runtime" || return 1
    say_ok "📝 vim is configured"
}

# ⚫️ checks neovim installation
function bootstrapInstallNeovim () {
    if dryrun brew install neovim; then
        say_ok "🌱 Neovim is installed"
        return 0
    fi
    say_err "🌱 Neovim installation failed"
    return 1
}

# ⚫️ checks neovim installation
function bootstrapCheckNeovim () {
    if command -v nvim > /dev/null 2>&1; then
        say_skip "🌱 Neovim already installed"
        return 0
    fi
    say_work "🌱 installing Neovim"
    bootstrapInstallNeovim
}

# ⚫️ configures neovim
function bootstrapConfigNeovim () {
    echo "🛠️ configuring Neovim..."
}

# ⚫️ initializes git submodules
function bootstrapInitSubmodules () {
    if [[ ! -f "${dot_bootstrap_directory}/.gitmodules" ]]; then
        say_warn "no .gitmodules found, skipping submodule init"
        return 0
    fi
    say_work "🧶 initializing git submodules"
    if dryrun git -C "${dot_bootstrap_directory}" submodule update --init --recursive; then
        say_ok "🧶 submodules initialized"
        return 0
    fi
    say_err "🧶 submodule initialization failed"
    return 1
}

# ⚫️ configures node environment via n
function bootstrapConfigNode () {
    local node_version="${NODE_VERSION:-20.10.0}"
    local n_prefix="${HOME}/.node-$(uname -m)"

    if ! command -v n &> /dev/null; then
        say_err "🟢 n is not installed (expected via Brewfile)"
        return 1
    fi

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
            return 1
        fi
    fi
    say_ok "🟢 node ${node_version} is ready"

    if [[ "${DOT_INSTALL_LANG_DEPS:-0}" -gt 0 ]]; then
        local data_file="${dot_bootstrap_directory}/data/zsh.yaml"
        if [[ ! -f "${data_file}" ]]; then
            say_warn "data/zsh.yaml not found, skipping npm packages"
            return 0
        fi
        local npm_packages
        npm_packages="$(yq '.languages.node.npm.requirements[]' "${data_file}" 2>/dev/null)"
        if [[ -z "${npm_packages}" ]]; then
            return 0
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

    return 0
}

# ⚫️ installs oh-my-zsh custom plugins via vendor/ohmyzsh nested submodules
function bootstrapInstallOhMyZshCustomPlugins () {
    local vendor_omz="${dot_bootstrap_directory}/vendor/ohmyzsh"
    local zsh_yaml="${dot_bootstrap_directory}/data/zsh.yaml"
    if [[ ! -d "${vendor_omz}" ]]; then
        say_err "🧩 vendor/ohmyzsh not found"
        return 1
    fi
    say_work "🧩 syncing oh-my-zsh custom plugin submodules"
    local enabled_repos disabled_repos
    enabled_repos=$(yq '.plugins.custom[] | select(.enabled == true) | .repo' "${zsh_yaml}")
    disabled_repos=$(yq '.plugins.custom[] | select(.enabled == false) | .repo' "${zsh_yaml}")
    local failed=0
    while IFS= read -r repo; do
        [[ -z "${repo}" ]] && continue
        local submodule_path="custom/plugins/${repo}"
        # idempotent: skip if already initialized AND has content
        if [[ -f "${vendor_omz}/${submodule_path}/.git" || -d "${vendor_omz}/${submodule_path}/.git" ]]; then
            say_skip "➕ ${submodule_path} (already initialized)"
            continue
        fi
        echo "  ➕ init ${submodule_path}"
        dryrun git -C "${vendor_omz}" submodule update --init "${submodule_path}" || { say_err "failed to init ${submodule_path}"; failed=1; }
    done <<< "${enabled_repos}"
    while IFS= read -r repo; do
        [[ -z "${repo}" ]] && continue
        local submodule_path="custom/plugins/${repo}"
        if [[ -d "${vendor_omz}/${submodule_path}" && ( -f "${vendor_omz}/${submodule_path}/.git" || -d "${vendor_omz}/${submodule_path}/.git" ) ]]; then
            echo "  ➖ deinit ${submodule_path} (disabled)"
            dryrun git -C "${vendor_omz}" submodule deinit --force "${submodule_path}" || true
        fi
    done <<< "${disabled_repos}"
    [[ "${failed}" -eq 0 ]] && say_ok "🧩 oh-my-zsh custom plugins synced" && return 0
    say_err "🧩 oh-my-zsh custom plugin sync failed"
    return 1
}

# ⚫️ main bootstrap function
function bootstrapSystem() {
    # load secrets
    __load_secrets
    bootstrapCheckBrew || return 1
    bootstrapCheckDependencies || return 1
    bootstrapCheckCloud || return 1
    bootstrapInitSubmodules || return 1

    bootstrapCheckZsh || return 1
    bootstrapConfigureZsh || return 1
    bootstrapConfigBash || return 1

    bootstrapConfigSsh || return 1
    bootstrapConfigGit || return 1

    bootstrapConfigPython || return 1
    bootstrapConfigNode || return 1

    bootstrapCheckIterm || return 1
    bootstrapConfigFiglet || return 1
    bootstrapCheckOhMyZsh || return 1
    bootstrapInstallOhMyZshCustomPlugins || return 1
    bootstrapCheckPowershell10K || return 1
    bootstrapCheckOhMyTmux || return 1

    say_done "bootstrap complete"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
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

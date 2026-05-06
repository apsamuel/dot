#!/bin/bash
#% description: installs and bootstrap ⚫️
#% notes: because this must work on bash 3.x.x and 4.x.x, some of the syntax is a bit weird
#% usage: ./dot-bootstrap.sh
# 🕵️ ignore shellcheck warnings about source statements
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# globals
ZSH=${ZSH:-$HOME/.oh-my-zsh}
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Resolve the project root.
# When sourced in zsh, BASH_SOURCE[0] is empty — use DOT_DIRECTORY if already
# exported (set by zshrc/dotenv.sh before this file is sourced).
# Fall back to BASH_SOURCE only when executed directly under bash.
if [[ -n "${DOT_DIRECTORY}" ]]; then
    dot_bootstrap_directory="${DOT_DIRECTORY}"
else
    dot_bootstrap_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
dot_boostrap_file="${dot_bootstrap_directory}/bin/dot-bootstrap.sh"
dot_bootstrap_deps=${DOT_DEPS:-0}

icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
icloud_link="${HOME}/iCloud"
ICLOUD=${ICLOUD:-${icloud_link}}


if [ ! -d "${dot_bootstrap_directory}" ]; then
    echo "❌  ${dot_bootstrap_directory} does not exist"
    exit 1
fi

. "${dot_bootstrap_directory}/zlib/static/lib/internal.sh"


function resolveBrewfilePath () {
    local local_brewfile="${dot_bootstrap_directory}/data/Brewfile"

    if [[ -f "${local_brewfile}" ]]; then
        echo "${local_brewfile}"
        return 0
    fi

    if [[ -n "${ICLOUD:-}" && -f "${ICLOUD}/dot/Brewfile" ]]; then
        echo "${ICLOUD}/dot/Brewfile"
        return 0
    fi

    return 1
}


function ensureSymlink () {
    local source_path="${1}"
    local target_path="${2}"
    local backup_path="${target_path}.bak"

    if [[ -z "${source_path}" || -z "${target_path}" ]]; then
        echo "❌ ensureSymlink requires source and target"
        return 1
    fi

    if [[ ! -e "${source_path}" && ! -L "${source_path}" ]]; then
        echo "❌ source does not exist: ${source_path}"
        return 1
    fi

    if [[ -L "${target_path}" ]]; then
        if [[ "$(readlink "${target_path}")" == "${source_path}" ]]; then
            return 0
        fi
        rm -f "${target_path}"
    elif [[ -e "${target_path}" ]]; then
        if [[ -e "${backup_path}" || -L "${backup_path}" ]]; then
            backup_path="${target_path}.bak.$(date +%s)"
        fi
        mv "${target_path}" "${backup_path}"
    fi

    ln -s "${source_path}" "${target_path}"
}


# copies zsh configuration and data files to iCloud and links them
function deployZsh () {
    local dry_mode=0
    local handles_config=0
    local handles_rc=0
    local debug=0

    while getopts ":ndhrx" opt; do
        case ${opt} in

            d)
                handles_config=1
                ;;
            r)
                handles_rc=1
                ;;
            n)
                dry_mode=1
                ;;
            x)
                debug=1
                ;;
            h)
                echo "Usage: ${0} [-d] [-h]"
                echo "  -d, --dry-run   Enable dry run mode"
                echo "  -h, --help      Show this help message"
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

    if [[ -z "${ICLOUD}" ]]; then
        echo "ICLOUD is not set"
        return 1
    fi


    data_source="${dot_bootstrap_directory}/config/data.json"
    data_dest="${icloud_directory}/dot/shell/zsh/zsh.json"

    rc_source="${dot_bootstrap_directory}/zshrc"
    rc_dest="${icloud_directory}/dot/shell/zsh/rc"

    [[ $debug -gt 0 ]] && (
        echo "zsh debug" && set -x
    )

    [[ $debug -gt 0 ]] && echo "deploying rc files to ${ICLOUD}"

    if [[ ${handles_rc} -gt 0 ]]; then
        # creates a link to the zshrc file in iCloud

        # if dry we only print the command
        if [[ ${dry_mode} -gt 0 ]]; then
            echo "ln -s -f ${rc_source} ${rc_dest}"
            return 0
        else
            # if the file exists, we remove it
            if [[ -f "${rc_dest}" ]]; then
                rm -f "${rc_dest}" && \
                [[ $debug -gt 0 ]] && echo "🗑️  removed existing zshrc at ${rc_dest}"
            fi

            # if the file is a link, we remove it
            if [[ -L "${rc_dest}" ]]; then
                rm -f "${rc_dest}" && \
                [[ $debug -gt 0 ]] && echo "🗑️  removed existing zshrc link at ${rc_dest}"
            fi

            # create a new link
            ln -s -f "${rc_source}" "${rc_dest}" && \
            [[ $debug -gt 0 ]] && echo "✅  zshrc is deployed to ${rc_dest}"
        fi
    fi

    if [[ ${handles_config} -gt 0 ]]; then

        # if the source data is newer than the destination data, we copy it
        if [[ -f "${data_dest}" && "${data_source}" -nt "${data_dest}" ]]; then
            # check if we are in dry mode
            if [[ ${dry_mode} -gt 0 ]]; then
                echo "cp ${data_source} ${data_dest}"
            else
                # if the file exists, we remove it
                if [[ -f "${data_dest}" ]]; then
                    rm -f "${data_dest}" && \
                    [[ $debug -gt 0 ]] && echo "🗑️  removed existing zsh.json at ${data_dest}"
                fi

                # copy the data file to the destination
                cp "${data_source}" "${data_dest}" && \
                [[ $debug -gt 0 ]] && echo "✅  zsh.json is deployed to ${data_dest}"
            fi
            # rm -f "${data_dest}" && \
            # [[ $debug -gt 0 ]] && echo "🗑️  removed existing zsh.json at ${data_dest}"
        fi

    fi

    # always relink the zshrc file to iCloud
    # ln -s -f "${ICLOUD}/dot/shell/zsh/rc" "${HOME}/.zshrc" && \
    # [[ $debug -gt 0 ]] && echo "✅  zshrc is deployed to ${ICLOUD}/dot/shell/zsh/rc"

    return 0

}

# ⚫️ preflight checks and information
function bootstrapInfo () {
    # we will build up a status string and print it


    # print architecture
    echo "🔧 architecture: $(uname -m)"
    # print os version
    echo "🔧 os: $(sw_vers -productVersion)"

    current_shell="$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")"
    # check if we are running in a ZSH shell
    if [[ $current_shell == "zsh" ]]; then
        echo "✅ in zsh 🐢 !"
    else
        echo "💣 not in zsh"
    fi
    # check if ICLOUD environment variable is set
    if [[ -z "${ICLOUD}" ]]; then
        echo "💣 env: \$ICLOUD is not a link"
    else
        echo "✅ env: \$ICLOUD 🔗 (${ICLOUD})"
    fi

    # check if brew is installed
    if command -v brew &> /dev/null
    then
        echo "✅ cli: brew is available ($(command brew --version))"
    else
        echo "💣 cli: brew is not available"
    fi

    # check if git is installed
    if command -v git &> /dev/null
    then
        echo "✅ cli: git is available ($(command git --version))"
    else
        echo "💣 cli: git is not available"
    fi

    # check if jq is installed
    if command -v jq &> /dev/null
    then
        echo "✅ cli: jq is available ($(command jq --version))"
    else
        echo "💣 cli: jq is not available"
    fi

    # check if curl is installed
    if command -v curl &> /dev/null
    then
        echo "✅ cli: curl is available ($(command curl --version | head -n 1))"
    else
        echo "💣 cli: curl is not available"
    fi

}

# prints ⚫️ start message
function bootstrapPrint () {
    echo "🛠️ executing ${dot_boostrap_file}"
}


# installs ⚫️ dependencies
function bootstrapDeps () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        echo "❌ no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    if brew bundle install --file "${brewfile}";
    then
        echo "✅ dependencies ok"
        return 0
    else
        echo "❌ dependencies failed"
        return 1
    fi
}

# checks and installs ⚫️ dependencies
function bootstrapCheckDependencies () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        echo "❌ no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    # you can force reinstallation of dependencies by setting DOT_DEPS=1
    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        echo "🛠️ installing bootstrap deps ..."
        installDependencies
    else
        if ! brew bundle check --file "${brewfile}" > /dev/null 2>&1
        then
            echo "🛠️ installing dependencies ..."
            installDependencies
        fi
    fi
}

# installs ⚫️ dependencies
function installDependencies () {
    local brewfile
    brewfile="$(resolveBrewfilePath)"
    if [[ -z "${brewfile}" ]]; then
        echo "❌ no Brewfile found (checked local data/ and \$ICLOUD/dot/)"
        return 1
    fi

    if brew bundle install --file "${brewfile}"
    then
        echo "✅ dependencies installed"
        return 0
    else
        echo "❌ dependencies installation failed"
        return 1
    fi
}

# configures python environment for ⚫️
function bootstrapConfigPython () {
    true
}

# ⚫️ links iCloud directory
function bootstrapLinkCloud () {
    if [[ ! -d "${icloud_directory}" ]]; then
        echo "❌ iCloud directory not found: ${icloud_directory}"
        return 1
    fi

    if ensureSymlink "${icloud_directory}" "${icloud_link}"; then
        ICLOUD="${icloud_link}"
        export ICLOUD
        echo "✅ ${icloud_link} is linked to ${icloud_directory}"
        return 0
    fi

    echo "❌ ${icloud_link} is not linked to ${icloud_directory}"
    return 1

}

# ⚫️ checks iCloud directory and links it
function bootstrapCheckCloud () {
    if [[ -d "${icloud_directory}" ]]; then
        echo "✅ iCloud is enabled"
        bootstrapLinkCloud || return 1
    else
        echo "❌ iCloud is not enabled (${icloud_directory} missing)"
        return 1
    fi

    return 0
}

# ⚫️ checks Oh My Tmux installation
function bootstrapCheckOhMyTmux () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local tmux_local_config="${HOME}/.tmux.conf.local"
    local tmux_icloud_config="${icloud_directory}/dot/shell/tmux/conf"

    ln -s -f "${tmux_icloud_config}" "${tmux_local_config}"
    # start a new tmux session, and install plugins
    if tmux has-session -t bootstrap; then
        tmux kill-session -t bootstrap
    fi

    tmux new-session -d -s bootstrap && \
    tmux send-keys -t bootstrap C-I && \
    tmux kill-session -t bootstrap
    echo "✅  tmux is configured"
}

# ⚫️ configures figlet
function bootstrapConfigFiglet () {
    if [[ ! -d "$HOME"/.figlet ]]; then
        git clone git@github.com:xero/figlet-fonts.git "$HOME"/.figlet &> /dev/null
    else
        git -C "$HOME"/.figlet pull &> /dev/null
    fi
    echo "✅  figlet is configured"
}

# ⚫️ configures iterm2
function bootstrapConfigIterm () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local dynamic_profiles="${HOME}/Library/Application Support/iTerm2/DynamicProfiles"

    # ensure the plist file exists where iterm2 expects it


    # ensure that all themes are installed

    # install iTerm-Color-Schemes
    "$ICLOUD"/dot/terminal/themes/iTerm2-Color-Schemes/tools/import-scheme.sh -v "$ICLOUD"/dot/terminal/themes/iTerm2-Color-Schemes/schemes/
    "$ICLOUD"/dot/terminal/themes/iTerm2-Color-Schemes/tools/import-scheme.sh  -v "$ICLOUD"/dot/terminal/themes/catppuccin/catppuccin/colors/

    # enable icloud preferences in iterm2
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "${icloud_directory}/dot/terminal"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

    # copy Profiles to DynamicProfiles path
    if [[ ! -d "${dynamic_profiles}" ]];
    then
        mkdir -p "${dynamic_profiles}"
    fi
    cp "${icloud_directory}/dot/terminal/iterm2.profiles.json" "${dynamic_profiles}/Profiles.json"
    echo "✅ iterm2 is configured, please start/restart iterm2!"

}

# ⚫️ configures ssh client
function bootstrapConfigSsh () {
    local ssh_config="${HOME}/.ssh/config"
    local ssh_config_dot="${ICLOUD}/dot/ssh/config"
    local ssh_root_dot="${ICLOUD}/dot/ssh"
    local ssh_keys=()

    mkdir -p "${HOME}/.ssh"

    ensureSymlink "${ssh_config_dot}" "${ssh_config}" || return 1

    while IFS= read -r -d '' ssh_key; do
        ssh_keys+=("${ssh_key}")
    done < <(find "${ssh_root_dot}" -type f -print0)

    local ssh_key_name
    for ssh_key in "${ssh_keys[@]}"; do
        if [[ "${ssh_key}" =~ config ]]; then
            continue
        fi
        ssh_key_name="$(basename "${ssh_key}")"
        local ssh_key_path="${HOME}/.ssh/${ssh_key_name}"
        # a link exists with this identity
        ensureSymlink "${ssh_key}" "${ssh_key_path}" || return 1
    done
    echo "✅  your ssh client is configured"

}

# ⚫️ configures git
function bootstrapConfigGit () {
    local git_config="${HOME}/.gitconfig"
    local git_config_dot="${ICLOUD}/dot/git/config"

    ensureSymlink "${git_config_dot}" "${git_config}" || return 1
    echo "✅  your git installation is configured"
}

# ⚫️ configures gh
function bootstrapConfigGh () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local git_config_dir_dot="${icloud_directory}/dot/git/gh"
    local git_config_dir="${HOME}/.config/gh"
    # check if the gh config directory exists
    if [[ ! -d "${git_config_dir}" ]]; then
        mkdir -p "${git_config_dir}"
    fi
    # if the file exists, remove it and use a soft link
    if [[ -f "${git_config_dir}/config.yml" ]]; then
        rm -f "${git_config_dir}/config.yml"
        ln -s "${git_config_dir_dot}/config.yml" "${git_config_dir}/config.yml"
    else
        ln -s "${git_config_dir_dot}/config.yml" "${git_config_dir}/config.yml"
    fi

    # link the hosts file
    if [[ -f "${git_config_dir}/hosts.yml" ]]; then
        rm -f "${git_config_dir}/hosts.yml"
        ln -s "${git_config_dir_dot}/hosts.yml" "${git_config_dir}/hosts.yml"
    else
        ln -s "${git_config_dir_dot}/hosts.yml" "${git_config_dir}/hosts.yml"
    fi

    echo "✅  your gh installation is configured"

}

# ⚫️ configures zsh
function bootstrapConfigZsh () {
    local rc="${HOME}/.zshrc"
    local zsh_bin
    zsh_bin="$(command -v zsh)"

    if [[ -z "${zsh_bin}" ]]; then
        echo "❌ zsh is not installed"
        return 1
    fi

    # change users shell
    if [[ "$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")" != "zsh" ]]; then
        chsh -s "${zsh_bin}" "${USER}"
    fi

    ensureSymlink "${dot_bootstrap_directory}/zshrc" "${rc}" || return 1
    # ln -s -f "${icloud_link}/dot/shell/zsh/rc" "${rc}" && \
    echo "✅  zsh shell is configured, please restart any open shells!"
}

# ⚫️ configures bash
function bootstrapConfigBash () {
    local rc="${HOME}/.bashrc"

    ensureSymlink "${ICLOUD}/dot/shell/bash/rc" "${rc}" || return 1
    echo "✅  bash shell is configured, please restart any open shells!"
}

# ⚫️ configures fish
function bootstrapConfigFish () {
    # TODO: make real
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.config/fish/config.fish"
    # if a file exists back it up
    if [[ -f "${rc}" ]]; then
        mv "${rc}" "${rc}.bak"
    fi
    ln -s -f "${icloud_link}/dot/shell/fish/rc" "${rc}"
    echo "✅  fish shell is configured, please restart any open shells!"
    true
}

# ⚫️ configures ksh
function bootstrapConfigKsh () {
    # TODO: make real    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.kshrc"
    # if a file exists back it up
    if [[ -f "${rc}" ]]; then
        mv "${rc}" "${rc}.bak"
    fi
    ln -s -f "${icloud_link}/dot/shell/ksh/rc" "${rc}"
    echo "✅  ksh shell is configured, please restart any open shells!"
    true
}

# ⚫️ configures csh
function bootstrapConfigCsh () {
    # TODO: make real
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.kshrc"
    # if a file exists back it up
    if [[ -f "${rc}" ]]; then
        mv "${rc}" "${rc}.bak"
    fi
    ln -s -f "${icloud_link}/dot/shell/csh/rc" "${rc}"
    echo "✅  csh shell is configured, please restart any open shells!"
    true
}

# ⚫️ configures pwsh
function bootstrapConfigPwsh () {
    return 0
}

# ⚫️ configures oh-my-zsh
function bootstrapConfigOhMyZsh () {
    return 0
}

# ⚫️ configures zsh custom plugins
function bootstrapConfigZshCustomPlugins () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.zshrc"
    # check if the file exists
    if [[ -f "${rc}" ]]; then
        # it exists, so we'll back it up and link in the new one
        echo "🛠️ backing up your old .zshrc..."
        mv "${rc}" "${rc}.bak"
    fi

    # checkout custom plugins
    local custom_plugins_length
    custom_plugins_length=$(jq -r '.plugins.custom| length' "${HOME}/.dot/data/zsh.json")
    # in a perfect world, we would use a mapfile to load the custom plugins
    # mapfile -t custom_plugins < <(jq -r '.plugins.custom | .[]' "${HOME}/.dot/data/zsh.json")
    for (( i=1; i<custom_plugins_length; i++ )); do
        local custom_plugin
        # loads each dictionary item as an associative array
        custom_plugin=$(
            jq -r --arg index "${i}" '"(", (.plugins.custom[($index |tonumber)] | to_entries | .[] | "["+(.key|@sh)+"]="+(.value|@sh) ), ")"' "${HOME}/.dot/data/zsh.json"
        )
        echo "✅ loading custom OMZ plugin ${custom_plugin}"
    done
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
        jq '.' -r '"$(\.plugins.custom[].owner)' "${HOME}/.dot/data/zsh.json" | \
        while IFS= read -r plugin; do
            echo " - ${plugin}"
        done
    fi

}

# ⚫️ installs oh-my-zsh plugin
function bootstrapInstallOhMyZshPlugin() {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.zshrc"

    # repo
    local org="${1}"
    local repo="${2}"
    gh repo clone "${org}/${repo}" "${ZSH_CUSTOM}/plugins/${repo}" &> /dev/null

    if ! gh repo clone "${org}/${repo}" "${ZSH_CUSTOM}/plugins/${repo}"
    then
        echo "❌ failed to install ${repo}"
        return 1
    fi
}

# ⚫️ installs powerlevel10k
function bootstrapConfigPowershell10K () {
    # TODO: should this be a link to icloud?
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    # cp "${dot_bootstrap_directory}"/config/p10k.zsh "${HOME}/.p10k.zsh"
    ln -s "${icloud_directory}/dot/shell/powerlevel/rc.zsh" "${HOME}/.p10k.zsh"
    echo "✅  powerlevel10k is configured"
}

# ⚫️ checks brew installation
function bootstrapCheckBrew () {
    if ! command -v brew &> /dev/null
    then
        echo "🛠️ installing brew..."
        bootstrapInstallBrew
    else
        echo "✅ brew is installed"
        return 0
    fi
}

# ⚫️ checks zsh installation
function bootstrapCheckZsh () {
    if ! command -v zsh &> /dev/null
    then
        echo "🛠️ installing zsh..."
        bootstrapInstallZsh
    else
        echo "✅ zsh is installed"
    fi

    if [[ ! "$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")" == "zsh" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        bootstrapConfigZsh
    else
        echo "✅ zsh is the default terminal"
    fi

    return 0
}

# ⚫️ checks jq installation
function bootstrapCheckJq () {
    if ! command -v jq &> /dev/null
    then
        echo "🛠️ installing jq ..."
        bootstrapInstallJq
    else
        echo "✅ jq is installed"
    fi
    return 0

}

# ⚫️ checks iterm2 installation
function bootstrapCheckIterm () {
    if ! mdfind "kMDItemKind == 'Application'" | grep -q -Ei '^/Applications/[i]Term.*?.app' &> /dev/null
    then
        echo "🛠️ installing iterm2 ..."
        bootstrapInstallIterm
    else
        echo "✅ iterm2 is installed"
        bootstrapConfigIterm
        return 0
    fi
}

# ⚫️ checks fonts installation
function bootstrapCheckFonts () {
    true
    true
}

# ⚫️ checks iterm2 themes installation
function bootstrapCheckThemes () {
    if [[ ! -d "${HOME}/.themes" ]];
    then
        echo "🛠️ installing iterm2 themes ..."
        bootstrapInstallThemes
    fi
}

# ⚫️ checks oh-my-zsh installation
function bootstrapCheckOhMyZsh () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ ! -d $HOME/.oh-my-zsh ]];
    then
        echo "🛠️ installing oh-my-zsh..."
        bootstrapInstallOhMyZsh
    fi
    echo "✅ configuring zsh..."
    bootstrapConfigOhMyZsh
}

# ⚫️ checks powerlevel10k installation
function bootstrapCheckPowershell10K () {
    # installed
    if [[ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]];
    then
        echo "🛠️  installing powerlevel10k ..."
        bootstrapInstallPowershell10K
    fi
    if [[ -f "${HOME}/.p10k.zsh" ]];
    # configured
    then
        echo "✅  powerlevel10k is configured"
    else
        echo "❌  powerlevel10k is not configured..."
        bootstrapConfigPowershell10K
    fi
}

# ⚫️ installs brew
function bootstrapInstallBrew () {
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        echo "✅ brew is installed"
        return 0
    else
        echo "❌ brew installation failed"
        return 1
    fi
}

# ⚫️ installs zsh
function bootstrapInstallZsh () {
    if brew install zsh; then
        echo "✅ zsh is installed"
        return 0
    fi

    echo "❌ zsh installation failed"
    return 1
}

# ⚫️ installs jq
function bootstrapInstallJq () {
    if command brew install jq
    then
        echo "✅ jq is installed"
        return 0
    else
        echo "❌ jq installation failed"
        return 1
    fi
}

# ⚫️ installs nvm
function bootstrapInstallNvm () {
    local nvm_version="${NVM_VERSION:-v0.40.3}"
    local nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"

    if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
        echo "✅ nvm is installed"
        return 0
    fi

    if PROFILE=/dev/null bash -c "$(curl -fsSL "${nvm_install_url}")"; then
        echo "✅ nvm is installed"
        return 0
    fi

    echo "❌ nvm installation failed"
    return 1
}

# ⚫️ configures nvm in shell profiles
function bootstrapConfigNvm () {
    local nvm_profile_start="# >>> nvm init >>>"
    local nvm_profile_end="# <<< nvm init <<<"
    local profile

    for profile in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
        [[ -f "${profile}" ]] || touch "${profile}"
        if ! grep -Fq "${nvm_profile_start}" "${profile}"; then
            {
                echo ""
                echo "${nvm_profile_start}"
                echo 'export NVM_DIR="$HOME/.nvm"'
                echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
                echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
                echo "${nvm_profile_end}"
            } >> "${profile}"
        fi
    done

    echo "✅ nvm is configured"
    return 0
}

# ⚫️ checks nvm installation
function bootstrapCheckNvm () {
    if [[ ! -s "${HOME}/.nvm/nvm.sh" ]]; then
        echo "🛠️ installing nvm ..."
        bootstrapInstallNvm || return 1
    else
        echo "✅ nvm is installed"
    fi

    bootstrapConfigNvm || return 1

    if [[ "${DOT_NVM_INSTALL_LTS:-0}" == "1" ]]; then
        export NVM_DIR="${HOME}/.nvm"
        # shellcheck source=/dev/null
        . "${NVM_DIR}/nvm.sh"

        if nvm install --lts && nvm alias default 'lts/*'; then
            echo "✅ node LTS is installed and set as default"
        else
            echo "❌ failed to install node LTS with nvm"
            return 1
        fi
    fi

    return 0
}

# ⚫️ installs iterm2
function bootstrapInstallIterm () {
    if command brew install --cask iterm2
    then
        echo "✅ iterm2 is installed"
        return 0
    else
        echo "❌ iterm2 installation failed"
        return 1
    fi
}

# ⚫️ installs fonts
function bootstrapInstallFonts () {
    if command cp "$ICLOUD"/dot/terminal/fonts/* ~/Library/Fonts/
    then
        echo "✅  fonts are installed"
        return 0
    else
        echo "❌ fonts installation failed"
        return 1
    fi
}

# ⚫️ installs iterm2 themes
function bootstrapInstallThemes () {
    if command gh repo clone apsamuel/iTerm2-Color-Schemes "${HOME}/.themes"
    then
        bash "${HOME}/.themes/tools/import-scheme.sh"
        echo "✅ iterm2 themes are installed"
        return 0
    else
        echo "❌ iterm2 themes installation failed"
        return 1
    fi
}

# ⚫️ installs oh-my-zsh
function bootstrapInstallOhMyZsh () {
    curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install_omz.sh
    chmod +x /tmp/install_omz.sh
    if KEEP_ZSHRC=yes CHSH=no RUNZSH=no /tmp/install_omz.sh; then
        #copy the zshrc in place
        bootstrapConfigOhMyZsh
        echo "✅  oh-my-zsh is installed"
    else
        echo "❌  oh-my-zsh installation failed"
        return 1
    fi

    return 0
}

# ⚫️ installs oh-my-tmux
function bootstrapInstallOhMyTmux () {
    # TODO: check if the folder exists and is not empty, if not, we actually resinstall
    if [ ! -d "${HOME}"/.tmux ]; then
        echo "🛠️ installing oh-my-tmux..."
        if command git clone git@github.com:gpakosz/.tmux.git "${HOME}/.tmux"
        then
            ln -s -f "${HOME}/.tmux/.tmux.conf" "${HOME}/.tmux.conf"
            #cp "${HOME}/.tmux/.tmux.conf.local" "${HOME}/.tmux.conf.local"
            echo "✅  oh-my-tmux is installed"
            return 0
        else
            echo "❌  oh-my-tmux installation failed"
            return 1
        fi
    else
        echo "✅  oh-my-tmux is installed"
        return 0
    fi

}

# ⚫️ installs powerlevel10k
function bootstrapInstallPowershell10K () {
    if command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"
    then
        echo "✅  powerlevel10k is installed"
        return 0
    else
        echo "❌  powerlevel10k installation failed"
        return 1
    fi
}

# ⚫️ checks vim installation
function bootstrapCheckVim () {
    if ! command -v vim &> /dev/null
    then
        echo "❌ vim is not installed"
        bootstrapInstallVim
    else
        echo "✅ vim is installed"
        return 0
    fi
}

# ⚫️ installs vim
function bootstrapInstallVim () {
    echo "🛠️ validating vim..."
    if brew install vim; then
        echo "✅ vim is installed"
        return 0
    fi

    echo "❌ vim installation failed"
    return 1
}

# ⚫️ configures vim
function bootstrapConfigVim () {
    echo "🛠️ configuring vim..."
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    # handle .vimrc
    if [[ ! -f "${HOME}/.vimrc" ]];
    then
        # chec if .vimrc is a link
        ln -s -f "${icloud_directory}/dot/shell/vim/rc" "${HOME}/.vimrc"
    else
        # check if .vimrc is a link
        if [[ ! -L "${HOME}/.vimrc" ]];
        then
            # it isn't, so we'll back it up and link in the new one
            echo "🛠️ backing up your old .vimrc..."
            mv "${HOME}/.vimrc" "${HOME}/.vimrc.bak"
            ln -s -f "${icloud_directory}/dot/shell/vim/rc" "${HOME}/.vimrc"
        else
            # check if .vimrc is a link to the correct file
            if [[ ! "$(readlink "${HOME}/.vimrc")" == "${icloud_directory}/dot/shell/vim/rc" ]];
            then
                rm -f "${HOME}/.vimrc"
                ln -s -f "${icloud_directory}/dot/shell/vim/rc" "${HOME}/.vimrc"
            else
                echo "✅ .vimrc is already configured"
            fi

        fi
    fi

    # handle .vim folder
    if [[ ! -d "${HOME}/.vim" ]];
    then
        # check if .vim is a link
        ln -s -f "${icloud_directory}/dot/shell/vim/rc-dir" "${HOME}/.vim"
    else
        # check if .vim is a link
        if [[ ! -L "${HOME}/.vim" ]];
        then
            # it isn't, so we'll back it up and link in the new one
            echo "🛠️ backing up your old .vim rc directory ..."
            mv "${HOME}/.vim" "${HOME}/.vim.bak"
            ln -s -f "${icloud_directory}/dot/shell/vim/rc-dir" "${HOME}/.vim"
        else
            # check if .vim is a link to the correct file
            if [[ ! "$(readlink "${HOME}/.vim")" == "${icloud_directory}/dot/shell/vim/rc-dir" ]];
            then
                # we don't know what this is linked to, so we'll remove it and link in the right one
                rm -f "${HOME}/.vim"
                ln -s -f "${icloud_directory}/dot/shell/vim/rc-dir" "${HOME}/.vim"
            else
                echo "✅ the .vim rc directory is already configured"
            fi

        fi
    fi

    # handle the .vim_runtime folder
    if [[ ! -d "${HOME}/.vim_runtime" ]];
    then
        # check if .vim_runtime is a link
        ln -s -f "${icloud_directory}/dot/shell/vim/vim_runtime" "${HOME}/.vim_runtime"
    else
        # check if .vim_runtime is a link
        if [[ ! -L "${HOME}/.vim_runtime" ]];
        then
            # it isn't, so we'll back it up and link in the new one
            echo "🛠️ backing up your old .vim_runtime..."
            mv "${HOME}/.vim_runtime" "${HOME}/.vim_runtime.bak"
            ln -s -f "${icloud_directory}/dot/shell/vim/vim_runtime" "${HOME}/.vim_runtime"
        else
            # check if .vim_runtime is a link to the correct file
            if [[ ! "$(readlink "${HOME}/.vim_runtime")" == "${icloud_directory}/dot/shell/vim/vim_runtime" ]];
            then
                # we don't know what this is linked to, so we'll remove it and link in the right one
                rm -f "${HOME}/.vim_runtime"
                ln -s -f "${icloud_directory}/dot/shell/vim/vim_runtime" "${HOME}/.vim_runtime"
            else
                echo "✅ .vim_runtime is already configured"
            fi

        fi
    fi

}

# ⚫️ checks neovim installation
function bootstrapInstallNeovim () {
    if brew install neovim; then
        echo "✅ Neovim is installed"
        return 0
    fi

    echo "❌ Neovim installation failed"
    return 1
}

# ⚫️ checks neovim installation
function bootstrapCheckNeovim () {
    echo "🛠️ validating Neovim..."
    if ! command -v nvim > /dev/null 2>&1
    then
        echo "❌ Neovim is not installed"
        bootstrapInstallNeovim
    else
        echo "✅ Neovim is installed"
        return 0
    fi
}

# ⚫️ configures neovim
function bootstrapConfigNeovim () {
    echo "🛠️ configuring Neovim..."
}

# ⚫️ main bootstrap function
function bootstrapSystem() {
    # load secrets
    __load_secrets
    bootstrapCheckBrew || return 1
    bootstrapDeps || return 1
    bootstrapCheckCloud || return 1

    bootstrapCheckZsh || return 1
    bootstrapConfigZsh || return 1
    bootstrapConfigBash || return 1

    bootstrapConfigSsh || return 1
    bootstrapConfigGit || return 1

    bootstrapCheckNvm || return 1
    bootstrapCheckIterm || return 1
    bootstrapConfigFiglet || return 1
    bootstrapCheckOhMyZsh || return 1
    bootstrapCheckPowershell10K || return 1
    bootstrapCheckOhMyTmux || return 1

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    bootstrapPrint
    bootstrapInfo
    bootstrapSystem
fi

#!/bin/bash
#% description: prepare a new macos machine for my personal use
#% notes: because this must work on bash 3.x.x and 4.x.x, some of the syntax is a bit weird
#% usage: ./bootstrap.sh
# 🕵️ ignore shellcheck warnings about source statements
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# globals
ZSH=${ZSH:-$HOME/.oh-my-zsh}
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# the script is now located in ./bin, this is a hack to get the project root
dot_bootstrap_directory="$(dirname "$(dirname "$0")")"
dot_boostrap_file="${dot_bootstrap_directory}/bin/bootstrap.sh"
dot_bootstrap_deps=${DOT_DEPS:-0}

icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"


if [ ! -d "${dot_bootstrap_directory}" ]; then
    echo "❌  ${dot_bootstrap_directory} does not exist"
    exit 1
fi

. "${dot_bootstrap_directory}/zlib/static/lib/internal.sh"


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

function bootstrapPrint () {
    echo "🛠️ executing ${dot_boostrap_file}"
}

function bootstrapSystem() {
    # load secrets
    __load_secrets
    bootstrapCheckBrew # install brew
    bootstrapDeps # install Brewfile
    # configure icloud links
    # configure bash
    bootstrapConfigZsh
    bootstrapConfigBash
    bootstrapCheckCloud
    # configure ssh
    bootstrapConfigSsh
    bootstrapConfigGit
    # validate and configure iterm
    bootstrapCheckIterm
    bootstrapConfigFiglet
    bootstrapCheckZsh
    bootstrapCheckOhMyZsh
    bootstrapCheckPowershell10K
    bootstrapCheckOhMyTmux

}

function bootstrapDeps () {
    if command brew bundle install --file "${ICLOUD}/dot/Brewfile";
    then
        echo "✅ dependencies ok"
        return 0
    else
        echo "❌ dependencies failed"
        return 1
    fi
}

function bootstrapCheckDependencies () {
    # you can force reinstallation of dependencies by setting DOT_DEPS=1
    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        echo "🛠️ installing bootstrap deps ..."
        installDependencies
    else
        if ! command brew bundle check --file "${dot_bootstrap_directory}/data/Brewfile" &> /dev/null
        then
            echo "🛠️ installing dependencies ..."
            installDependencies
        fi
    fi
}

function installDependencies () {
    if command brew bundle install --file "${dot_bootstrap_directory}/data/Brewfile"
    then
        echo "✅ dependencies installed"
        return 0
    else
        echo "❌ dependencies installation failed"
        return 1
    fi
}

function bootstrapConfigPython () {
    true
}

function bootstrapLinkCloud () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"

    if command ln -s "${icloud_directory}" "${icloud_link}"
    then
        echo "✅ ${icloud_link} is linked to ${icloud_directory}"
        return 0
    else
        echo "❌ ${icloud_link} is not linked to ${icloud_directory}"
        return 1
    fi

}

function bootstrapCheckCloud () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"

    if [[ -d "${icloud_directory}" ]];
    echo "✅ iCloud is enabled"
    then
        if [[ ! -L "${icloud_link}" ]]; then
            echo "🛠️ linking ${icloud_link} ..."
            bootstrapLinkCloud
        fi
    fi
}

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

function bootstrapConfigFiglet () {
    if [[ ! -d "$HOME"/.figlet ]]; then
        git clone git@github.com:xero/figlet-fonts.git "$HOME"/.figlet &> /dev/null
    else
        git -C "$HOME"/.figlet pull &> /dev/null
    fi
    echo "✅  figlet is configured"
}

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

function bootstrapConfigSsh () {
    local ssh_config="${HOME}/.ssh/config"
    local ssh_config_dot="${HOME}/iCloud/dot/ssh/config"
    local ssh_keys=()

    # always update the ssh config file
    rm -f "${ssh_config}" && \
    ln -s "${ssh_config_dot}" "${ssh_config}" && \

    while IFS= read -r -d '' ssh_key; do
        ssh_keys+=("${ssh_key}")
    done < <(find "${HOME}/iCloud/dot/ssh" -type f -print0) # -print0

    local ssh_key_name
    for ssh_key in "${ssh_keys[@]}"; do
        if [[ "${ssh_key}" =~ config ]]; then
            continue
        fi
        ssh_key_name="$(basename "${ssh_key}")"
        local ssh_key_path="${HOME}/.ssh/${ssh_key_name}"
        # a link exists with this identity
        if [[ -L "${ssh_key_path}" ]]; then
            rm -f "${ssh_key_path}" && \
            ln -s "${ssh_key}" "${ssh_key_path}"
        fi

        # neither a link nor file exist with this identity
        if [[ ! -f "${ssh_key_path}" && ! -L "${ssh_key_path}" ]]; then
            ln -s "${ssh_key}" "${ssh_key_path}"
        fi

        # a file exists with this identity, it is not a link
        if [[ -f "${ssh_key_path}" && ! -L "${ssh_key_path}" ]]; then
            mv "${ssh_key_path}" "${ssh_key_path}.bak"
            ln -s "${ssh_key}" "${ssh_key_path}"
        fi
    done
    echo "✅  your ssh client is configured"

}

function bootstrapConfigGit () {
    local git_config="${HOME}/.gitconfig"
    local git_config_dot="${HOME}/iCloud/dot/git/config"

    # always update the git config file
    rm -f "${git_config}" && \
    ln -s "${git_config_dot}" "${git_config}" && \
    echo "✅  your git installation is configured"
}

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
    fi

    echo "✅  your gh installation is configured"

}

function bootstrapConfigZsh () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.zshrc"
    # change users shell
    chsh -s "$(command -v zsh)" "${USER}"
    # link from dot/config/shell/
    ln -s -f "${dot_bootstrap_directory}/config/shell/rc" "${rc}"
    # ln -s -f "${icloud_link}/dot/shell/zsh/rc" "${rc}" && \
    echo "✅  zsh shell is configured, please restart any open shells!"
}

function bootstrapConfigBash () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.bashrc"
    ln -s -f "${icloud_link}/dot/shell/bash/rc" "${rc}"
    echo "✅  bash shell is configured, please restart any open shells!"
}

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

function bootstrapConfigPwsh () {
    return 0
}

function bootstrapConfigOhMyZsh () {
    return 0
}

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

function bootstrapConfigPowershell10K () {
    # TODO: should this be a link to icloud?
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    # cp "${dot_bootstrap_directory}"/config/p10k.zsh "${HOME}/.p10k.zsh"
    ln -s "${icloud_directory}/dot/shell/powerlevel/rc.zsh" "${HOME}/.p10k.zsh"
    echo "✅  powerlevel10k is configured"
}

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

function bootstrapCheckFonts () {
    true
    true
}

function bootstrapCheckThemes () {
    if [[ ! -d "${HOME}/.themes" ]];
    then
        echo "🛠️ installing iterm2 themes ..."
        bootstrapInstallThemes
    fi
}

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

function bootstrapInstallZsh () {
    if ! command brew install zsh
    then
        echo "🛠️ installing zsh..."
        bootstrapInstallZsh
    else
        echo "✅ zsh is installed"
        return 0
    fi
}

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

function bootstrapInstallVim () {
    echo "🛠️ validating vim..."
    if ! command brew install vim
    then
        echo "🛠️ installing vim..."
        bootstrapInstallVim
    else
        echo "✅ vim is installed"
        return 0
    fi
}

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

function bootstrapInstallNeovim () {
    if ! command brew install neovim
    then
        echo "🛠️ installing Neovim..."
        bootstrapInstallNeovim
    else
        echo "✅ Neovim is installed"
        return 0
    fi
}

function bootstrapCheckNeovim () {
    echo "🛠️ validating Neovim..."
    if ! command -v Neovim &> /dev/null
    then
        echo "❌ Neovim is not installed"
        bootstrapInstallNeovim
    else
        echo "✅ Neovim is installed"
        return 0
    fi
}

function bootstrapConfigNeovim () {
    echo "🛠️ configuring Neovim..."
}

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

function __load_secrets () {
    local secret_keys=()
    # declare -A secrets
    while IFS=' ' read -r -d ' ' secret_key; do
        secret_keys+=("${secret_key}")
    done < <(jq -r '. | keys | .[]' "${ICLOUD}"/dot/secrets.json | xargs) # -print0
    touch "${TMPDIR}"/.secrets
    if [[ ${#secret_keys[@]} -gt 0  ]]; then
        echo "#!/bin/bash" > "$TMPDIR"/.secrets
    fi
    for secret_key in "${secret_keys[@]}"; do
        secret_value="$(jq --arg secret_key "${secret_key}" -r '.[$secret_key]' "${ICLOUD}"/dot/secrets.json)"
        echo "${secret_key}=${secret_value}" >> "$TMPDIR"/.secrets
    done
    if [[ -f "$TMPDIR"/.secrets ]]; then
        source "$TMPDIR"/.secrets
        rm -f "$TMPDIR"/.secrets
    else
        echo "no secrets file found"
    fi
    export BOOTSTRAP_SECRETS_LOADED=1
    echo "🛻  loaded ${#secret_keys[@]} secrets"
}

function bootstrap::print () {
    echo "🛠️ executing ${dot_boostrap_file}"
}

function bootstrap::sys() {
    # load secrets
    __load_secrets
    bootstrap::validate::brew # install brew
    installDependencies # install Brewfile
    # configure icloud links
    # configure bash
    bootstrap::configure::zsh
    bootstrap::configure::bash
    bootstrap::validate::cloud
    # configure ssh
    bootstrap::configure::ssh
    bootstrap::configure::git
    # validate and configure iterm
    bootstrap::validate::iterm
    bootstrap::configure::figlet
    bootstrap::validate::zsh
    bootstrap::validate::ohmyzsh
    bootstrap::validate::p10k
    bootstrap::validate::ohmytmux

}

function bootstrap::deps () {
    if command brew bundle install --file "${ICLOUD}/dot/Brewfile";
    then
        echo "✅ dependencies ok"
        return 0
    else
        echo "❌ dependencies failed"
        return 1
    fi
}

function bootstrap::validate::deps () {
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

function bootstrap::link::cloud () {
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

function bootstrap::validate::cloud () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"

    if [[ -d "${icloud_directory}" ]];
    echo "✅ iCloud is enabled"
    then
        if [[ ! -L "${icloud_link}" ]]; then
            echo "🛠️ linking ${icloud_link} ..."
            bootstrap::link::cloud
        fi
    fi
}

function bootstrap::validate::ohmytmux () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local tmux_local_config="${HOME}/.tmux.conf.local"
    ln -s -f "${icloud_link}/dot/shell/tmux/conf" "${tmux_local_config}"
    # start a new tmux session, and install plugins
    if tmux has-session -t bootstrap; then
        tmux kill-session -t bootstrap
    fi
    tmux new-session -d -s bootstrap && \
    tmux send-keys -t bootstrap C-I && \
    tmux kill-session -t bootstrap
    echo "✅  tmux is configured"
}

function bootstrap::configure::figlet () {
    if [[ ! -d "$HOME"/.figlet ]]; then
        git clone git@github.com:xero/figlet-fonts.git "$HOME"/.figlet &> /dev/null
    else
        git -C "$HOME"/.figlet pull &> /dev/null
    fi
    echo "✅  figlet is configured"
}

function bootstrap::configure::iterm () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local dynamic_profiles="${HOME}/Library/Application Support/iTerm2/DynamicProfiles"

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

function bootstrap::configure::ssh () {
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

function bootstrap::configure::git () {
    local git_config="${HOME}/.gitconfig"
    local git_config_dot="${HOME}/iCloud/dot/git/config"

    # always update the git config file
    rm -f "${git_config}" && \
    ln -s "${git_config_dot}" "${git_config}" && \
    echo "✅  your git installation is configured"
}

function bootstrap::configure::gh () {
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


function bootstrap::configure::zsh () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.zshrc"
    chsh -s "$(command -v zsh)" "${USER}"
    ln -s -f "${icloud_link}/dot/shell/zsh/rc" "${rc}" && \
    echo "✅  zsh shell is configured, please restart any open shells!"
}

function bootstrap::configure::bash () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.bashrc"
    ln -s -f "${icloud_link}/dot/shell/bash/rc" "${rc}"
    echo "✅  bash shell is configured, please restart any open shells!"
}

function bootstrap::configure::fish () {
    # TODO: make real
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.config/fish/config.fish"
    ln -s -f "${icloud_link}/dot/shell/fish/rc" "${rc}"
    echo "✅  fish shell is configured, please restart any open shells!"
    true
}

function bootstrap::configure::ksh () {
    # TODO: make real    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.kshrc"
    ln -s -f "${icloud_link}/dot/shell/ksh/rc" "${rc}"
    echo "✅  ksh shell is configured, please restart any open shells!"
    true
}

function bootstrap::configure::csh () {
    # TODO: make real
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.kshrc"
    ln -s -f "${icloud_link}/dot/shell/csh/rc" "${rc}"
    echo "✅  csh shell is configured, please restart any open shells!"
    true
}


function bootstrap::configure::pwsh () {
    true
}

function bootstrap::configure::omz () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"
    local rc="${HOME}/.zshrc"
    ln -s -f "${icloud_link}/dot/shell/zsh/rc" "${rc}"
    # cp "${dot_bootstrap_directory}"/config/zshrc "${HOME}/.zshrc"
    # checkout custom plugins
    local custom_plugins_length
    custom_plugins_length=$(jq -r '.plugins.custom| length' "${HOME}/.dot/data/zsh.json")
    # mapfile -t custom_plugins < <(jq -r '.plugins.custom | .[]' "${HOME}/.dot/data/zsh.json")
    for (( i=1; i<custom_plugins_length; i++ )); do
        local custom_plugin
        # load each dictionary item as an associative array
        custom_plugin=$(
            jq -r --arg index "${i}" '"(", (.plugins.custom[($index |tonumber)] | to_entries | .[] | "["+(.key|@sh)+"]="+(.value|@sh) ), ")"' "${HOME}/.dot/data/zsh.json"
        )
        echo "✅ loading custom OMZ plugin ${custom_plugin}"
    done
}

function bootstrap::configure::p10k () {
    # TODO: should this be a link to icloud?
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    # cp "${dot_bootstrap_directory}"/config/p10k.zsh "${HOME}/.p10k.zsh"
    ln -s "${icloud_directory}/dot/shell/powerlevel/rc.zsh" "${HOME}/.p10k.zsh"
    echo "✅  powerlevel10k is configured"
}

function bootstrap::validate::brew () {
    if ! command -v brew &> /dev/null
    then
        echo "🛠️ installing brew..."
        bootstrap::install::brew
    else
        echo "✅ brew is installed"
        return 0
    fi
}

function bootstrap::validate::zsh () {
    if ! command -v zsh &> /dev/null
    then
        echo "🛠️ installing zsh..."
        bootstrap::install::zsh
    else
        echo "✅ zsh is installed"
    fi

    if [[ ! "$(basename -- "$(dscl . -read "$HOME" UserShell | awk '{print $NF}')")" == "zsh" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        bootstrap::configure::zsh
    else
        echo "✅ zsh is the default terminal"
    fi

    return 0
}

function bootstrap::validate::jq () {
    if ! command -v jq &> /dev/null
    then
        echo "🛠️ installing jq ..."
        bootstrap::install::jq
    else
        echo "✅ jq is installed"
    fi
    return 0

}

function bootstrap::validate::iterm () {
    if ! mdfind "kMDItemKind == 'Application'" | grep -q -Ei '^/Applications/[i]Term.*?.app' &> /dev/null
    then
        echo "🛠️ installing iterm2 ..."
        bootstrap::install::iterm
    else
        echo "✅ iterm2 is installed"
        bootstrap::configure::iterm
        return 0
    fi
}

function bootstrap::validate::fonts () {
    true
#    brew tap homebrew/cask-fonts
#    local desired_fonts=(
#     [powerline]="font-powerline-symbols"
#     [meslo]="font-meslo-for-powerline"
#     [menlo]="font-menlo-for-powerline"
#    )
#    local package
#    for desired_font in "${!desired_fonts[@]}"; do
#        package="${desired_fonts[${desired_font}]}"
#        if ! fc-list | grep -q -Ei "${desired_font}" &> /dev/null
#        then
#            echo "🛠️ installing ${desired_font} font ..."
#            bootstrap::install::font "${package}"
#        fi
#    done
    true
}

function bootstrap::validate::themes () {
    if [[ ! -d "${HOME}/.themes" ]];
    then
        echo "🛠️ installing iterm2 themes ..."
        bootstrap::install::themes
    fi

}

function bootstrap::validate::ohmyzsh () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ ! -d $HOME/.oh-my-zsh ]];
    then
        echo "🛠️ installing oh-my-zsh..."
        bootstrap::install::omz
    fi
    echo "✅ configuring zsh..."
    bootstrap::configure::omz
}

function bootstrap::validate::p10k () {
    # installed
    if [[ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]];
    then
        echo "🛠️  installing powerlevel10k ..."
        bootstrap::install::p10k
    fi
    if [[ -f "${HOME}/.p10k.zsh" ]];
    # configured
    then
        echo "✅  powerlevel10k is configured"
    else
        echo "❌  powerlevel10k is not configured..."
        bootstrap::configure::p10k
    fi
}

function bootstrap::install::brew () {
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        echo "✅ brew is installed"
        return 0
    else
        echo "❌ brew installation failed"
        return 1
    fi
}

function bootstrap::install::zsh () {
    if ! command brew install zsh
    then
        echo "🛠️ installing zsh..."
        bootstrap::install::zsh
    else
        echo "✅ zsh is installed"
        return 0
    fi
}

function bootstrap::install::jq () {
    if command brew install jq
    then
        echo "✅ jq is installed"
        return 0
    else
        echo "❌ jq installation failed"
        return 1
    fi
}

function bootstrap::install::iterm () {
    if command brew install --cask iterm2
    then
        echo "✅ iterm2 is installed"
        return 0
    else
        echo "❌ iterm2 installation failed"
        return 1
    fi
}

function bootstrap::install::fonts () {
    if command cp "$ICLOUD"/dot/terminal/fonts/* ~/Library/Fonts/
    then
        echo "✅  fonts are installed"
        return 0
    else
        echo "❌ fonts installation failed"
        return 1
    fi
}

function bootstrap::install::themes () {
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

function bootstrap::install::omz () {
    curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install_omz.sh
    chmod +x /tmp/install_omz.sh
    if KEEP_ZSHRC=yes CHSH=no RUNZSH=no /tmp/install_omz.sh; then
        #copy the zshrc in place
        bootstrap::configure::omz
        echo "✅  oh-my-zsh is installed"
    else
        echo "❌  oh-my-zsh installation failed"
        return 1
    fi

    return 0
}

function bootstrap::install::ohmytmux () {
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

function bootstrap::install::p10k () {
    if command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"
    then
        echo "✅  powerlevel10k is installed"
        return 0
    else
        echo "❌  powerlevel10k installation failed"
        return 1
    fi
}

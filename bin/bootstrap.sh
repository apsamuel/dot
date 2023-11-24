#!/bin/bash
#% description: prepare a new macos machine for my personal use
#% usage: ./bootstrap.sh
# 🕵️ ignore shellcheck warnings about source statements

# globals
dot_bootstrap_directory="$(dirname "$0")"
dot_boostrap_file="${dot_bootstrap_directory}/bootstrap.sh"
dot_bootstrap_deps=${DOT_DEPS:-0}

function dot::bootstrap::info () {
    echo "🛠️ executing ${dot_boostrap_file}"
}

function dot::bootstrap () {
    # install & configure brew
    dot::validate::brew
    # install our Brewfile
    dot::install::deps
    dot::configure::ssh
    dot::validate::cloud
    dot::validate::iterm
    dot::validate::zsh
    dot::validate::omz
    # dot::validate::p10k
}

function dot::install::deps () {
    if command brew bundle install --file "${dot_bootstrap_directory}/data/Brewfile";
    then
        echo "✅ dependencies ok"
        return 0
    else
        echo "❌ dependencies failed"
        return 1
    fi
}

function dot::validate::deps () {
    # you can force reinstallation of dependencies by setting DOT_DEPS=1
    if [[ "${dot_bootstrap_deps}" -gt 0 ]]; then
        echo "🛠️ installing bootstrap deps ..."
        dot::install::deps
    else
        if ! command brew bundle check --file "${dot_bootstrap_directory}/data/Brewfile" &> /dev/null
        then
            echo "🛠️ installing dependencies ..."
            dot::install::deps
        fi
    fi
}

function dot::link::cloud () {
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

function dot::validate::cloud () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"

    if [[ -d "${icloud_directory}" ]];
    echo "✅ iCloud is enabled"
    then
        if [[ ! -L "${icloud_link}" ]]; then
            echo "🛠️ linking ${icloud_link} ..."
            dot::link::cloud
        fi
    fi
}

function dot::configure::ssh () {
    local ssh_config="${HOME}/.ssh/config"
    local ssh_config_dot="${HOME}/iCloud/dot/ssh/config"
    local ssh_keys=()

    # always update the ssh config file
    rm -f "${ssh_config}" && \
    ln -s "${ssh_config_dot}" "${ssh_config}" && \
    echo "✅ ${ssh_config} is linked to ${ssh_config_dot}"

    # refresh the keys from iCloud
    if [[ "$BASH_VERSION" == 5* ]]; then
        mapfile -t ssh_keys < <(ls "${HOME}/iCloud/dot/ssh/")
    fi

    if [[ "$BASH_VERSION" == 3* || "$BASH_VERSION" == 4* ]]; then
        # ssh_keys=(${HOME}/iCloud/dot/ssh/*)
        # use read -a ssh_keys < <(ls "${HOME}/iCloud/dot/ssh/")
        read -r -a ssh_keys < <(ls "${HOME}/iCloud/dot/ssh/")
    fi


    for ssh_key in "${ssh_keys[@]}"; do
        if [[ "${ssh_key}" =~ config ]]; then
            continue
        fi
        local ssh_key_name
        ssh_key_name="$(basename "${ssh_key}")"
        local ssh_key_path="${HOME}/.ssh/${ssh_key_name}"
        rm -f "${ssh_key_path}" && \
        ln -s "${ssh_key}" "${ssh_key_path}" && \
        echo "✅ ${ssh_key_path} is linked to ${ssh_key}"
    done



}

function dot::install::brew () {
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        echo "✅ brew is installed"
        return 0
    else
        echo "❌ brew installation failed"
        return 1
    fi
}

function dot::validate::brew () {
    if ! command -v brew &> /dev/null
    then
        echo "🛠️ installing brew..."
        dot::install::brew
    else
        echo "✅ brew is installed"
        return 0
    fi
}

function dot::install::zsh () {
    if ! command brew install zsh
    then
        echo "🛠️ installing zsh..."
        dot::install::zsh
    else
        echo "✅ zsh is installed"
        return 0
    fi
}

function dot::configure::zsh () {
    chsh -s "$(command -v zsh)" "${USER}" && \
    echo "✅ zsh is the default terminal, please restart your sessions"
}

function dot::validate::zsh () {
    if ! command -v zsh &> /dev/null
    then
        echo "🛠️ installing zsh..."
        dot::install::zsh
    else
        echo "✅ zsh is installed"
    fi

    if [[ ! "$(basename -- "${SHELL}")" == "zsh" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        dot::configure::zsh
    else
        echo "✅ zsh is the default terminal"
    fi

    return 0
}

function dot::install::jq () {
    if command brew install jq
    then
        echo "✅ jq is installed"
        return 0
    else
        echo "❌ jq installation failed"
        return 1
    fi
}

function dot::validate::jq () {
    if ! command -v jq &> /dev/null
    then
        echo "🛠️ installing jq ..."
        dot::install::jq
    else
        echo "✅ jq is installed"
    fi
    return 0

}

function dot::install::iterm () {
    if command brew install --cask iterm2
    then
        echo "✅ iterm2 is installed"
        return 0
    else
        echo "❌ iterm2 installation failed"
        return 1
    fi
}

function dot::configure::iterm () {
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

}

function dot::validate::iterm () {
    if ! mdfind "kMDItemKind == 'Application'" | grep -q -Ei '^/Applications/[i]Term.*?.app' &> /dev/null
    then
        echo "🛠️ installing iterm2 ..."
        dot::install::iterm
    else
        echo "✅ iterm2 is installed"
        dot::configure::iterm
        return 0
    fi
}

function dot::install::font () {
    local package="${1}"
    if command brew install --cask "${package}"
    then
        echo "✅ ${package} is installed"
        return 0
    else
        echo "❌ ${package} installation failed"
        return 1
    fi
}

function dot::validate::fonts () {
   brew tap homebrew/cask-fonts
   local desired_fonts=(
    [powerline]="font-powerline-symbols"
    [meslo]="font-meslo-for-powerline"
    [menlo]="font-menlo-for-powerline"
   )
   local package
   for desired_font in "${!desired_fonts[@]}"; do
       package="${desired_fonts[${desired_font}]}"
       if ! fc-list | grep -q -Ei "${desired_font}" &> /dev/null
       then
           echo "🛠️ installing ${desired_font} font ..."
           dot::install::font "${package}"
       fi
   done
}

function dot::install::themes () {
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

function dot::validate::themes () {
    if [[ ! -d "${HOME}/.themes" ]];
    then
        echo "🛠️ installing iterm2 themes ..."
        dot::install::themes
    fi

}

function dot::configure::omz () {
    cp "${dot_bootstrap_directory}"/config/zshrc "${HOME}/.zshrc"
    # checkout custom plugins
    # local custom_plugins=()
    local custom_plugins_length
    custom_plugins_length=$(jq -r '.plugins.custom| length' "${HOME}/.dot/data/zsh.json")
    # mapfile -t custom_plugins < <(jq -r '.plugins.custom | .[]' "${HOME}/.dot/data/zsh.json")
    for (( i=1; i<custom_plugins_length; i++ )); do
        local custom_plugin
        # load each dictionary item as an associative array
        custom_plugin=$(
            jq -r --arg index "${i}" '"(", (.plugins.custom[($index)] | to_entries | .[] | "["+(.key|@sh)+"]="+(.value|@sh) ), ")"' "${HOME}/.dot/data/zsh.json"
        )
        echo "✅ loading custom plugin ${custom_plugin}"

    done
}

function dot::install::omz () {
    curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install_omz.sh
    chmod +x /tmp/install_omz.sh
    if KEEP_ZSHRC=yes CHSH=no RUNZSH=no /tmp/install_omz.sh; then
        #copy the zshrc in place
        dot::configure::omz
        echo "✅ oh-my-zsh is installed"
    else
        echo "❌ oh-my-zsh installation failed"
        return 1
    fi

    return 0
}

function dot::validate::omz () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ ! -d $HOME/.oh-my-zsh ]];
    then
        echo "🛠️ installing oh-my-zsh..."
        dot::install::omz
    fi
    echo "✅ configuring zsh..."
    dot::configure::omz
}

function dot::install::p10k () {
    if command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    then
        echo "✅ powerlevel10k is installed"
        return 0
    else
        echo "❌ powerlevel10k installation failed"
        return 1
    fi
}

function dot::configure::p10k () {
    cp "${dot_bootstrap_directory}"/config/p10k.zsh "${HOME}/.p10k.zsh"
}

function dot::validate::p10k () {
    # installed
    if [[ ! -d "${ZSH_CUSTOM}/plugins/themes/powerlevel10k" ]];
    then
        echo "🛠️ installing powerlevel10k ..."
        dot::install::p10k
    fi
    if [[ -f "${HOME}/.p10k.zsh" ]];
    # configured
    then
        echo "✅ powerlevel10k is installed"
    else
        echo "❌ powerlevel10k is not configured..."
        dot::configure::p10k
    fi
}



# dot::bootstrap;
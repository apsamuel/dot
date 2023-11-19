#!/bin/bash
# 🕵️ ignore shellcheck warnings about source statements

dot_bootstrap_directory="$(dirname "$0")"
dot_boostrap_file="${dot_bootstrap_directory}/bootstrap.sh"
echo "🛠️ executing ${dot_boostrap_file}"
dot_bootstrap_deps=${DOT_DEPS:-0}

function dot::bootstrap () {
    # install & configure brew
    if [[ ! $(dot::validate::brew) ]]; then
        echo "🛠️ installing brew ..."
        dot::install::brew
    fi

    # install our Brewfile
    dot::install::deps
    # dot::validate::zsh
    # dot::validate::omz
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

    if [[ -d "${icloud_directory}" ]]
    then
        if [[ ! -L "${icloud_link}" ]]; then
            echo "🛠️ linking ${HOME}/iCloud ..."
            dot::link::cloud
        fi
    fi
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
        return 1
    fi
}

function dot::install::zsh () {
    if ! command brew install zsh
    then
        echo "🛠️ installing zsh..."
        dot::install::zsh
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
    fi

    if [[ ! "$(basename -- "${SHELL}")" == "zsh" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        dot::configure::zsh
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
    fi

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
    echo
}

function dot::validate::iterm () {
    if ! mdfind "kMDItemKind == 'Application'" | grep -q -Ei '^/Applications/[i]Term.*?.app' &> /dev/null
    then
        echo "🛠️ installing iterm2 ..."
        dot::install::iterm
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

function dot::install::omz () {
    curl -L https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > "${TMP}"/install_omz.sh
    chmod +x "${TMP}"/install_omz.sh
    if KEEP_ZSHRC=yes CHSH=no RUNZSH=no ./"${TMP}/install_omz.sh"; then
        echo "✅ oh-my-zsh is installed"
        return 0
    else
        echo "❌ oh-my-zsh installation failed"
        return 1
    fi

}

function dot::validate::omz () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ ! -d $HOME/.oh-my-zsh ]];
    then
        echo "🛠️ installing oh-my-zsh..."
        dot::install::omz
    fi
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
    # TODO: move font installation to a separate function
    brew install font-meslo-for-powerline font-powerline-symbols font-menlo-for-powerline
    cp "${dot_bootstrap_directory}"/config/.p10k.zsh "${HOME}/.p10k.zsh"
}

function dot::validate::p10k () {
    if [[ ! -d "${ZSH_CUSTOM}/plugins/themes/powerlevel10k" ]];
    then
        echo "🛠️ installing powerlevel10k ..."
        dot::install::p10k
    fi
    if [[ -f "${HOME}/.p10k.zsh" ]];
    then
        echo "💡 powerlevel10k is installed"
    else
        echo "🛠️ powerlevel10k is not configured..."
        dot::configure::p10k
        # git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    fi
}



dot::bootstrap;
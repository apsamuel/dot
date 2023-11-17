#!/bin/bash
# 🕵️ ignore shellcheck warnings about source statements

directory="$(basename "$0")"


function bootstrap::preflight () {
    software::validate::brew
    software::validate::zsh
    software::validate::omz
    software::validate::p10k
}

function system::link::cloud () {
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

function system::validate::cloud () {
    local icloud_directory="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_link="${HOME}/iCloud"

    if [[ -d "${icloud_directory}" ]]
    then
        if [[ ! -L "${icloud_link}" ]]; then
            echo "🛠️ linking ${HOME}/iCloud ..."
            system::link::cloud

        fi
    fi
}

function software::install::brew () {
    if command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    then
        echo "✅ brew is installed"
        return 0
    else
        echo "❌ brew installation failed"
        return 1
    fi
}

function software::validate::brew () {
    if ! command -v brew &> /dev/null
    then
        echo "🛠️ installing brew ..."
        software::install::brew
    fi
}

function software::install::zsh () {
    if ! command brew install zsh
    then
        echo "🛠️ installing zsh..."
        software::install::zsh
    fi
}

function software::configure::zsh () {
    chsh -s "$(command -v zsh)" "${USER}" && \
    echo "✅ zsh is the default terminal, please restart your sessions"
}

function software::validate::zsh () {
    if ! command -v zsh &> /dev/null
    then
        echo "🛠️ installing zsh..."
        software::install::zsh
    fi

    if [[ -z "${ZSH}" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        software::configure::zsh
    fi

    return 0
}

function software::install::jq () {
    if command brew install jq
    then
        echo "✅ jq is installed"
        return 0
    else
        echo "❌ jq installation failed"
        return 1
    fi
}

function software::validate::jq () {
    if ! command -v jq &> /dev/null
    then
        echo "🛠️ installing jq ..."
        software::install::jq
    fi

}

function software::install::iterm () {
    if command brew install --cask iterm2
    then
        echo "✅ iterm2 is installed"
        return 0
    else
        echo "❌ iterm2 installation failed"
        return 1
    fi
}

function software::configure::iterm () {
    echo
}

function software::validate::iterm () {
    if ! mdfind "kMDItemKind == 'Application'" | grep -q -Ei '^/Applications/[i]Term.*?.app' &> /dev/null
    then
        echo "🛠️ installing iterm2 ..."
        software::install::iterm
    fi
}

function software::install::font () {
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

function software::validate::fonts () {
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
           software::install::font "${package}"
       fi
   done
}

function software::install::themes () {
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

function software::validate::themes () {
    if [[ ! -d "${HOME}/.themes" ]];
    then
        echo "🛠️ installing iterm2 themes ..."
        software::install::themes
    fi

}

function software::install::omz () {
    if command sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    then
        echo "✅ oh-my-zsh is installed"
        return 0
    else
        echo "❌ oh-my-zsh installation failed"
        return 1
    fi
}

function software::validate::omz () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ ! -d $HOME/.oh-my-zsh ]];
    then
        echo "🛠️ installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        # source ${HOME}/.zshrc
    fi
}

function software::install::p10k () {
    if command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    then
        echo "✅ powerlevel10k is installed"
        return 0
    else
        echo "❌ powerlevel10k installation failed"
        return 1
    fi
}

function software::configure::p10k () {
    # TODO: move font installation to a separate function
    brew install font-meslo-for-powerline font-powerline-symbols font-menlo-for-powerline
    cp "${directory}"/config/.p10k.zsh "${HOME}/.p10k.zsh"
}

function software::validate::p10k () {
    if [[ ! -d "{ZSH_CUSTOM}/plugins/themes/powerlevel10k" ]];
    then
        echo "🛠️ installing powerlevel10k ..."
        software::install::p10k
    fi
    if [[ -f "${HOME}/.p10k.zsh" ]];
    then
        echo "💡 powerlevel10k is installed"
    else
        echo "🛠️ powerlevel10k is not configured..."
        software::configure::p10k
        # git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    fi
}



bootstrap::preflight;
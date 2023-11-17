#!/bin/bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

function bootstrap::preflight () {
    software::validate::brew
    software::validate::zsh
    software::validate::omz
    software::validate::p10k
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
    echo
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
        # git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    fi
}



bootstrap::preflight;
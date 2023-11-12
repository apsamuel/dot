#!/bin/bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

function bootstrap::preflight () {
    bootstrap::check::brew
    bootstrap::check::zsh
    bootstrap::check::omz
    bootstrap::check::p10k
}

function bootstrap::check::brew () {
    if command -v brew &> /dev/null
    then
        echo "💡 brew is installed"
        return 0
    else
        echo "🛠️ brew is not installed"
        return 1
        # command bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

function bootstrap::check::zsh () {
    if command -v zsh &> /dev/null
    then
        echo "💡 zsh is installed"
    else
        echo "🛠️ zsh is not installed..."
        return 1
    fi

    if [[ -z "${ZSH}" ]]; then
        echo "🛠️ zsh is not the default terminal..."
        return 1
    fi

    return 0
}

function bootstrap::install::zsh () {
    if command brew install zsh
    then
        echo "✅ zsh is installed"
        return 0
    else
        echo "❌ zsh installation failed"
        return 1
    fi
}

function bootstrap::check::jq () {
    if command -v jq &> /dev/null
    then
        echo "💡 jq is installed"
    else
        # return 1
        echo "🛠️ jq is not installed..."
        # command brew install jq
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

function bootstrap::check::omz () {
    # TODO: devise a better method of validating omz is actually installed, using type requires sourcing ZSH
    if [[ -d $HOME/.oh-my-zsh ]];
    then
        echo "💡 oh-my-zsh is installed"
    else
        echo "🛠️ oh-my-zsh is not installed..."
        # command sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        # source ${HOME}/.zshrc
    fi
}

function bootstrap::install::omz () {
    if command sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    then
        echo "✅ oh-my-zsh is installed"
        return 0
    else
        echo "❌ oh-my-zsh installation failed"
        return 1
    fi
}

function bootstrap::check::p10k () {
    if [[ -f "${HOME}/.p10k.zsh" ]];
    then
        echo "💡 powerlevel10k is installed"
    else
        echo "🛠️ powerlevel10k is not installed..."
        # git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    fi
}

function bootstrap::install::p10k () {
    if command git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k
    then
        echo "✅ powerlevel10k is installed"
        return 0
    else
        echo "❌ powerlevel10k installation failed"
        return 1
    fi
}

bootstrap::preflight;
#!/bin/bash
#% author: github.com/apsamuel
#% description: wrapper for brew install, uninstall, and upgrade


action="$1"

if [[ -z "$action" ]]; then
    echo "Usage: brew-bootstrap.sh <action>"
    echo "Actions: install, uninstall, upgrade"
    exit 1
fi

if [[ "$action" == "install" ]]; then
    echo "Installing Homebrew"
    read -r -p "This will install Homebrew. Proceed? [y/N] " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Aborted."
        exit 0
    fi
elif [[ "$action" == "uninstall" ]]; then
    echo "Uninstalling Homebrew"
    read -r -p "This will REMOVE Homebrew and all installed packages. Proceed? [y/N] " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    else
        echo "Aborted."
        exit 0
    fi
elif [[ "$action" == "upgrade" ]]; then
    echo "Upgrading Homebrew"
    read -r -p "This will run brew update && brew upgrade. Proceed? [y/N] " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        brew update && brew upgrade
    else
        echo "Aborted."
        exit 0
    fi
elif [[ "$action" == "info" ]]; then
    echo "Homebrew Info"
    echo "Version: $(brew --version)"
    echo "Prefix: $(brew --prefix)"
    echo "Cellar: $(brew --cellar)"
    echo "Repository: $(brew --repository)"
else
    echo "Usage: brew-bootstrap.sh <action>"
    echo "Actions: install, uninstall, upgrade"
    exit 1
fi
# curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh
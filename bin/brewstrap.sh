#!/bin/bash
#% author: github.com/apsamuel
#% description: wrapper for brew install, uninstall, and upgrade


action="$1"

if [[ -z "$action" ]]; then
    echo "Usage: brewstrap.sh <action>"
    echo "Actions: install, uninstall, upgrade"
    exit 1
fi

if [[ "$action" == "install" ]]; then
    echo "Installing Homebrew"
    # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
elif [[ "$action" == "uninstall" ]]; then
    echo "Uninstalling Homebrew"
    # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
elif [[ "$action" == "upgrade" ]]; then
    echo "Upgrading Homebrew"
    # brew update && brew upgrade
elif [[ "$action" == "info" ]]; then
    echo "Homebrew Info"
    echo "Version: $(brew --version)"
    echo "Prefix: $(brew --prefix)"
    echo "Cellar: $(brew --cellar)"
    echo "Repository: $(brew --repository)"
else
    echo "Usage: brewstrap.sh <action>"
    echo "Actions: install, uninstall, upgrade"
    exit 1
fi
# curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh
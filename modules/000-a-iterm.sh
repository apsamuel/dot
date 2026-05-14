# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# TODO: this is a dependency on the iterm2 shell integration script, which needs to be installed separately.
# we should either remove this dependency or add it to the bootstrap process
test -e "${HOME}/.iterm2_shell_integration.zsh" && . "${HOME}/.iterm2_shell_integration.zsh"

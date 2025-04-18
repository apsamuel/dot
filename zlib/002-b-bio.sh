# #!/usr/local/bin/zsh
# - ignore shellcheck warnings ZSH files, we are loading a ZSH environment
# shellcheck disable=SC1071
# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null


# add edirect to path, only if it exists under ~/edirect
if [ -d "${HOME}/edirect" ] ; then
  PATH="${HOME}/edirect:${PATH}"
fi

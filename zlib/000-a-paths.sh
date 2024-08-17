#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

# edirect tools
if [ -d "${HOME}/Tools/edirect" ] ; then
  PATH="${HOME}/Tools/edirect:${PATH}"
fi



# scripts in devops dir
if [ -d "${HOME}/devops/scripts" ] ; then
  PATH="${HOME}/devops/scripts:${PATH}"
fi

# export PATH="$HOME/.jenv/bin:$PATH"
# eval "$(jenv init -)"
# add openjdk to path
PATH="/usr/local/opt/openjdk/bin:$PATH"


export PATH
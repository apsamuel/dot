#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

# edirect tools

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

if [ -d "${HOME}/Tools/edirect" ] ; then
  PATH="${HOME}/Tools/edirect:${PATH}"
fi


# source $DOT_DIR/bin
if [ -d "$DOT_DIR/bin" ] ; then
  PATH="${DOT_DIR}/bin:${PATH}"
fi

# # scripts in devops dir
# if [ -d "${HOME}/devops/scripts" ] ; then
#   PATH="${HOME}/devops/scripts:${PATH}"
# fi



export PATH
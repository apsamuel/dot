#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

_list_zsh_plugins() {
  local plugins=()
  for plugin in "${ZSH_CUSTOM}"/plugins/*; do
    echo "$(basename "${plugin}") - $(git -C "${plugin}" config --get remote.origin.url)"
    if [ -d "${plugin}" ]; then
      if [[ ${plugin} =~ "example" ]]; then
        continue
      fi
      plugins+=("$(basename "${plugin}")")
    fi
  done
}

_update_zsh_plugins() {
  local plugin="${1}"
  git -C "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" pull
}

_install_zsh_plugins() {
  for plugin in $(jq -r '.plugins.custom | map("\(.owner)/\(.repo)") | .[]' "${DOT_DIRECTORY}"/data/zsh.json); do
    if [ -d "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" ]; then
      continue
    fi
    echo "Installing ohmyzsh ${plugin}"
    gh repo clone "${plugin}" "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")"
  done
}

_update_custom_plugins() {
  for plugin in $(jq -r '.plugins.custom | map("\(.owner)/\(.repo)") | .[]' "${DOT_DIRECTORY}"/data/zsh.json); do
    if [ -d "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" ]; then
      echo "Updating ohmyzsh ${plugin}"
      _update_zsh_plugins "${plugin}"
      continue
    fi
  done
}

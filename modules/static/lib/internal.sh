#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

dot::static::internal::_exec-location() {
  loc="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  echo "${loc}"
}

dot::static::internal::_list-zsh-plugins() {
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

dot::static::internal::_update-zsh-plugins() {
  local plugin="${1}"
  git -C "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" pull
}

dot::static::internal::_install-zsh-plugins() {
  for plugin in $(yq '.plugins.custom | map(.owner + "/" + .repo) | .[]' "${DOT_DIRECTORY}"/data/zsh.yaml); do
    if [ -d "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" ]; then
      continue
    fi
    echo "Installing oh-my-zsh plugin: ${plugin}"
    gh repo clone "${plugin}" "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")"
  done
}

dot::static::internal::_update-custom-plugins() {
  for plugin in $(yq '.plugins.custom | map(.owner + "/" + .repo) | .[]' "${DOT_DIRECTORY}"/data/zsh.yaml); do
    if [ -d "${ZSH_CUSTOM}/plugins/$(basename "${plugin}")" ]; then
      echo "Updating oh-my-zsh plugin: ${plugin}"
      dot::static::internal::_update-zsh-plugins "${plugin}"
      continue
    fi
  done
}

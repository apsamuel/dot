# #!/usr/local/bin/zsh
# - ignore shellcheck warnings ZSH files, we are loading a ZSH environment
# shellcheck disable=SC1071
# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

# configure terraform completion if terraform is installed
# if command -v terraform >/dev/null 2>&1; then
#     # shellcheck disable=SC2207
#     TERRAFORM_PATHS=($(command -v terraform))
#     TERRAFORM_PATH="${TERRAFORM_PATHS[0]}"
#     complete -o nospace -C "$TERRAFORM_PATH" terraform
# fi

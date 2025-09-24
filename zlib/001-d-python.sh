# shellcheck shell=bash
# 🕵️ ignore shellcheck warnings about source statements
# shellcheck source=/dev/null

directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

# prepend python to the path $(brew --prefix python)/libexec/bin
# PATH="$(brew --prefix python)/bin:$PATH"


export PATH
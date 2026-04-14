#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null


directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

## These steps are related to <work>
host="$(hostname -s)"

if [[ "$host" != "prometheus" ]]; then
  SRE_CLIENTS="$(realpath "${HOME}/mlb-sre/sre-clients/.sre-clients/bin/sre-clients")"
  alias sre-clients='${SRE_CLIENTS}' #>> ${DOT_DIR}/zlib/999-a-completion.sh
fi
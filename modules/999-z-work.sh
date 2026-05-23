#shellcheck shell=bash
#% note: enable any completion steps here
# shellcheck source=/dev/null


directory=$(dirname "$0")
library=$(basename "$0")

dot::static::logging::loading "${library}" "${directory}"

## These steps are related to <work>
host="$(hostname -s)"

if [[ "$host" != "prometheus" ]]; then
  # source "${HOME}/mlb-sre/sre-clients/.sre-clients/bin/activate"
  SRE_CLIENTS="$(realpath "${HOME}/mlb/mlb-sre/sre-clients/.sre-clients/bin/sre-clients")"
  alias sre-clients='${SRE_CLIENTS}' #>> ${DOT_DIR}/modules/999-a-completion.sh
fi

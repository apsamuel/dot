#% author: Aaron Samuel
#% description: translate and export configuration definitions
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


DOT_CONFIGURATION="${DOT_CONFIGURATION:-${ICLOUD}/dot/data.json}"
export DOT_CONFIGURATION
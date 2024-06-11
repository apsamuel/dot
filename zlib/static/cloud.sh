#% author: Aaron Samuel
#% description: vendor cloud configuration
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


#TODO: expand this to windows, linux, etc. There are multiple cloud storage providers
## detect system and make best case judgement for cloud storage directories
## this is a macOS specific configuration

# let's configure our cloud storage directories
ICLOUD="${ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs}"
ICLOUD_DOCUMENTS="${ICLOUD}/Documents"
ICLOUD_DOWNLOADS="${ICLOUD}/Downloads"
ICLOUD_SCREENSHOTS="${ICLOUD}/ScreenShots"
export ICLOUD ICLOUD_DOCUMENTS ICLOUD_DOWNLOADS ICLOUD_SCREENSHOTS

#% author: Aaron Samuel
#% description: define baseline environment variables required for the dotfiles ecosystem and the shell
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207



unset DOT_ROOT DOT_DIRECTORY DOT_LIBRARY DOT_LIBRARY_FILES DOT_DEBUG

# enable debugging by setting the DOT_DEBUG value to 1
export DOT_DEBUG="${DOT_DEBUG:-0}"
# define the root directory for the dotfiles (DOT_ROOT & DOT_DIRECTORY are synonymous)
export DOT_ROOT="${DOT_ROOT:-${HOME}/.dot}"
export DOT_DIRECTORY="${DOT_DIRECTORY:-${DOT_ROOT}}"
# define the library directory for the dotfiles
export DOT_LIBRARY="${DOT_LIBRARY:-${DOT_ROOT}/zlib}"
# store available library files as sorted list
export DOT_LIBRARY_FILES=($(find "${DOT_LIBRARY}" -maxdepth 1 -type f -name "*.sh" | sort -d))

export DOT_ROOT DOT_DIRECTORY DOT_LIBRARY DOT_LIBRARY_FILES DOT_DEBUG
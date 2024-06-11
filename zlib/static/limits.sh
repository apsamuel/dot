#% author: Aaron Samuel
#% description: configure the user limits for the shell
# shellcheck shell=bash
# shellcheck source=/dev/null
# - ignore shellcheck warnings about read/mapfile
# shellcheck disable=SC2207


# this is a static file, we need to read the DOT_DIRECTORY and DOT_LIBRARY variables from environment

export DOT_DIRECTORY="${DOT_DIRECTORY:-$(dirname "$0")}"
export DOT_LIBRARY="${DOT_LIBRARY:-$(basename "$0")}"

# ulimit -c unlimited
DOT_CPU_TIME_LIMIT="${DOT_CPU_TIME_LIMIT:-$(ulimit -t)}"
DOT_FILE_SIZE_LIMIT="${DOT_FILE_SIZE_LIMIT:-$(ulimit -f)}"
DOT_DATA_SIZE_LIMIT="${DOT_DATA_SIZE_LIMIT:-$(ulimit -d)}"
DOT_STACK_SIZE_LIMIT="${DOT_STACK_SIZE_LIMIT:-$(ulimit -s)}"
DOT_CORE_DUMP_LIMIT="${DOT_CORE_DUMP_LIMIT:-$(ulimit -c)}"
DOT_VIRTUAL_MEMORY_LIMIT="${DOT_VIRTUAL_MEMORY_LIMIT:-$(ulimit -v)}"
DOT_LOCKED_MEMORY_LIMIT="${DOT_LOCKED_MEMORY_LIMIT:-$(ulimit -l)}"
DOT_OPEN_FILES_LIMIT="${DOT_OPEN_FILES_LIMIT:-$(ulimit -n)}"
DOT_FILE_DESCRIPTOR_LIMIT="${DOT_FILE_DESCRIPTOR_LIMIT:-$(ulimit -n)}"

export DOT_DIRECTORY DOT_LIBRARY
export DOT_CPU_TIME_LIMIT
export DOT_FILE_SIZE_LIMIT
export DOT_DATA_SIZE_LIMIT
export DOT_STACK_SIZE_LIMIT
export DOT_CORE_DUMP_LIMIT
export DOT_VIRTUAL_MEMORY_LIMIT
export DOT_LOCKED_MEMORY_LIMIT
export DOT_OPEN_FILES_LIMIT
export DOT_FILE_DESCRIPTOR_LIMIT
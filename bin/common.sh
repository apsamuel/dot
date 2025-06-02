#!/bin/bash

# splitString() {
#   local string="$1"
#   local delimiter="$2"
#   IFS="${delimiter}" read -r parts <<< "${string}"
#   echo "${parts[@]}"
# }

# joinList() {
#   local delimiter="$1"
#   shift
#   local elements=("$@")
#   IFS="${delimiter}" echo "${elements[*]}"
# }
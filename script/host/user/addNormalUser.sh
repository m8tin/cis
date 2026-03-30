#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!

_SCRIPT_FOLDER="$(dirname $(readlink -f "${0}" 2> /dev/null) 2> /dev/null)"
_ROOT="${_SCRIPT_FOLDER%%/script/*}/"    #Removes longest  matching pattern '/script/*' from the end
source "${_ROOT:?"Missing ROOT"}core/addNormalUser.sh" "${1:?"Missing first parameter USER"}" && exit 0 || exit 1

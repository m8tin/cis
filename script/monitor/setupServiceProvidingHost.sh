#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" \
    && exit 0



_SETUP="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SETUP%%/script/monitor/*}/"             #Removes longest  matching pattern '/script/monitor/*' from the end
_CORE_SCRIPTS="${_CIS_ROOT:?"Missing CIS_ROOT"}core/"
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"



echo "Setup the user and permission to enable the monitoring this host ... " \
    && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addNormalUser.sh" monitoring \
    && echo \
    && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${_DEFINITIONS}" monitoring \
    && exit 0

exit 1

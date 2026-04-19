#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" \
    && exit 0



_SETUP="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SETUP%%/script/host/zfs/composition-sync/*}/"             #Removes longest  matching pattern '/script/host/zfs/composition-sync/*' from the end
_CORE_SCRIPTS="${_CIS_ROOT:?"Missing CIS_ROOT"}core/"
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"



echo "Setup the user and permission to enable syncing compositions of this host ... " \
    && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addNormalUser.sh" composition-sync \
    && echo \
    && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${_DEFINITIONS}" composition-sync \
    && echo \
    && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${_DEFINITIONS}" /etc/sudoers.d/allow-composition-sync-send \
    && exit 0

exit 1

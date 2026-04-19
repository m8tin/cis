#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" \
    && exit 0



_SETUP="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SETUP%%/script/host/zfs/composition-sync/*}/"             #Removes longest  matching pattern '/script/host/zfs/composition-sync/*' from the end
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"



function checkPreconditions() {
    [ -d "${_DEFINITIONS:?"Missing DEFINITIONS"}compositions" ] \
        && return 0

    echo "No folder for your defined composition settings found: ${_DEFINITIONS:?"Missing DEFINITIONS"}compositions"
    echo "Please create it and add your custom composition settings in there, following this convention:"
    echo "  1.) './NAME_OF_THE_COMPOSITION/current-host'            containing one line with the FQDN of the host running the composition."
    echo "  2.) './NAME_OF_THE_COMPOSITION/composition-sync-hosts'  containing a list of hosts receiving the composition, one host with its FQDN per line."
    return 1
}



echo "Setup the host that receives the composition of others ... " \
    && checkPreconditions \
    && exit 0

exit 1

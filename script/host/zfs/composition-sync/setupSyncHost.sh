#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" \
    && exit 0

source /cis/core/base.module.sh



function setup() {
    local _COMPOSITION _COMPOSITIONS_FOLDER _CURRENT_HOST_FILE _SYNC_HOSTS_FILE
    _COMPOSITION="${1}"
    _COMPOSITIONS_FOLDER="${CIS[DOMAINDEFINITIONS]}compositions/"
    _CURRENT_HOST_FILE="${_COMPOSITIONS_FOLDER}${_COMPOSITION}/current-host"
    _SYNC_HOSTS_FILE="${_COMPOSITIONS_FOLDER}${_COMPOSITION}/composition-sync-hosts"
    readonly _COMPOSITION _COMPOSITIONS_FOLDER

    echo "Setup the host that receives the composition of others ..."
    echo
    echo "No folder for your defined composition settings found: ${_COMPOSITIONS_FOLDER}"
    echo "Please create it and add your custom composition settings in there, following this convention:"
    echo "  1.) './NAME_OF_THE_COMPOSITION/current-host'            containing one line with the FQDN of the host running the composition."
    echo "  2.) './NAME_OF_THE_COMPOSITION/composition-sync-hosts'  containing a list of hosts receiving the composition, one host with its FQDN per line."
    echo

    [ -d "${_COMPOSITIONS_FOLDER}" ] \
        && echo "Definiton folder for compositions found: ${_COMPOSITIONS_FOLDER}" \
        && echo

    [ -n "${_COMPOSITION}" ] \
        && [ -f "${_CURRENT_HOST_FILE}" ] \
        && echo "Current defined host to run composition '${_COMPOSITION}' is:" \
        && cat "${_CURRENT_HOST_FILE}" \
        && echo

    [ -n "${_COMPOSITION}" ] \
        && [ -f "${_SYNC_HOSTS_FILE}" ] \
        && echo "Following hosts should sync the ZFS of this composition '${COMPOSITION}':" \
        && cat "${_SYNC_HOSTS_FILE}" \
        && echo

    echo "Optionally you can create following file:"
    echo "  - rollback   (e.g.: date +%F > rollback)                 : allows the removal of the newest @SYNC snapshots of this day,"
    echo "                                                                 as long as no normal snapshot is reached."
    echo "  - ssh-port   (e.g.: echo 22 > ssh-port)                  : allows to use a custom port for the SSH connection."
    echo '  - zfs-branch (e.g.: echo zpool1/persistent > zfs-branch) : allows to use a custom zfs prefix like: ${zfs-branch}/${composition}.'
    return 0
}



base.set COMPOSITION "${1}" '^([a-zA-Z0-9][a-zA-Z0-9_-]*)?$' || exit 1
setup "${COMPOSITION}"



#!/bin/bash
if [ $(id -u) -ne 0 ]; then
    sudo "${0}" && exit 0
    exit 1
fi

source /cis/core/base.module.sh
base.loadModule composition



function setup() {
    local _COMPOSITION _COMPOSITIONS_FOLDER
    _COMPOSITION="${1}"
    _COMPOSITIONS_FOLDER="${CIS[DOMAINDEFINITIONS]}compositions/"
    readonly _COMPOSITION _COMPOSITIONS_FOLDER

    echo "Setup the host that receives the composition of others ..."
    echo
    echo "No folder for your defined composition settings found: ${_COMPOSITIONS_FOLDER}"
    echo "Please create it and add your custom composition settings in there, following this convention:"
    echo "  1.) './NAME_OF_THE_COMPOSITION/running-host'            containing one line with the FQDN of the host running the composition."
    echo "  2.) './NAME_OF_THE_COMPOSITION/zfssync-hosts'  containing a list of hosts receiving the composition, one host with its FQDN per line."
    echo

    [ -d "${_COMPOSITIONS_FOLDER}" ] \
        && echo "Definiton folder for compositions found: ${_COMPOSITIONS_FOLDER}" \
        && echo

    [ -n "${_COMPOSITION}" ] \
        && echo "Current defined host to run composition '${_COMPOSITION}' is:" \
        && composition.printRunningHost "${_COMPOSITION}" \
        && echo

    [ -n "${_COMPOSITION}" ] \
        && echo "Following hosts should sync the ZFS of this composition '${COMPOSITION}':" \
        && composition.printAllSyncingHosts "${_COMPOSITION}" \
        && echo

    echo "Optionally you can create following file:"
    echo "  - rollback (e.g.: date +%F > rollback)                         : allows the removal of the newest @SYNC snapshots of this day,"
    echo "                                                                       as long as no normal snapshot is reached."
    echo "  - ssh-port (e.g.: echo 22 > ssh-port)                          : allows to use a custom port for the SSH connection."
    echo '  - zfs      (e.g.: echo zpool1/persistent/${composition} > zfs) : allows to use a custom zfs prefix like: ${zfs}.'
    return 0
}



base.set COMPOSITION "${1}" '^[a-zA-Z0-9][a-zA-Z0-9_-]*$' optional
setup "${COMPOSITION}"



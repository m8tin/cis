#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



function checkSync() {
    local _REMOTE_HOST _MODE _GIVEN_REMOTE_HOSTNAME_FQDN
    _REMOTE_HOST="${1:?"checkSync(): Missing first parameter REMOTE_HOST"}"
    _MODE="${2:?"checkSync(): Missing second parameter MODE"}"
    _GIVEN_REMOTE_HOSTNAME_FQDN="${3}"
    readonly _REMOTE_HOST _MODE _GIVEN_REMOTE_HOSTNAME_FQDN

    local _REMOTE_HOSTNAME_FQDN _REMOTE_HOSTNAME_SHORT _DEFINED_REMOTE_HOSTNAME_FQDN _ZFS_SNAPSHOT_FILTER _NOW_UTC_UNIXTIME _DEBUG_PATH
    _REMOTE_HOSTNAME_FQDN="${_REMOTE_HOST%%:*}"            #Removes longest  matching pattern ':*' from the end
    _REMOTE_HOSTNAME_SHORT="${_REMOTE_HOSTNAME_FQDN%%.*}"  #Removes longest  matching pattern '.*' from the end

    # This is crucial:
    #  - default value for the filter part is extracted from the first parameter (FQDN)
    #  - but you can override this part to to adapt the test during a change of the domain.
    #    (e.g. the short hostname can be an option - or even a better default in the future)
    _DEFINED_REMOTE_HOSTNAME_FQDN="${_GIVEN_REMOTE_HOSTNAME_FQDN:-"${_REMOTE_HOSTNAME_FQDN:?"Missing REMOTE_HOSTNAME_FQDN"}"}"
    _ZFS_SNAPSHOT_FILTER="@SYNC_${_DEFINED_REMOTE_HOSTNAME_FQDN}"

    _NOW_UTC_UNIXTIME=$(date -u +%s)
    _DEBUG_PATH="/tmp/monitor/"
    readonly _REMOTE_HOSTNAME_FQDN _REMOTE_HOSTNAME_SHORT _DEFINED_REMOTE_HOSTNAME_FQDN _ZFS_SNAPSHOT_FILTER _NOW_UTC_UNIXTIME _DEBUG_PATH

    [ "${_MODE}" == "debug" ] \
        && mkdir -p "${_DEBUG_PATH}" > /dev/null \
        && echo "Now: ${_NOW_UTC_UNIXTIME}" > ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOST}.txt

    ! [ -d "${CIS[COMPOSITIONS]:?"Missing global parameter CIS_COMPOSITIONS"}" ] \
        && echo "WARN#no compositions" \
        && return 0

    [ "${_MODE}" == "debug" ] \
        && echo "Snapshot filter: ${_ZFS_SNAPSHOT_FILTER}" >> ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOST}.txt

    # This retrieves the list of the interesting snapshots including creation timestamp
    local _SNAPSHOTS=$(ssh.onHostRun "monitoring@${_REMOTE_HOST}" 'zfs list -po creation,name -r -t snapshot zpool1/persistent' | grep -F ${_ZFS_SNAPSHOT_FILTER})
    [ "${_MODE}" == "debug" ] \
        && echo "${_SNAPSHOTS}" > ${_DEBUG_PATH}SNAPSHOTS_${_REMOTE_HOST}.txt

    [ -z "${_SNAPSHOTS}" ] \
        && echo "FAIL#no snapshots" \
        && return 1

    echo "OK#Checks running"

    local _COMPOSITION_PATH
    for _COMPOSITION_PATH in "${CIS[COMPOSITIONS]}"*; do

        # If remote host is found than it is responsible for this container-composition, otherwise skip
        #   (grep -E "^[[:blank:]]*something" means. Line has to start with "something", leading blank chars are ok.)
        grep -E "^[[:blank:]]*${_REMOTE_HOSTNAME_SHORT}" "${_COMPOSITION_PATH}/composition-sync-hosts" &> /dev/null \
            || continue;

        local _COMPOSITION_NAME="${_COMPOSITION_PATH##*/}"   #Removes longest  matching pattern '*/' from the begin
        local _LAST_SNAPSHOT_UNIXTIME="$(echo "${_SNAPSHOTS}" | grep ${_COMPOSITION_NAME} | tail -n 1 | cut -d' ' -f1)"
        local _SECONDS_BEHIND=$[ ${_NOW_UTC_UNIXTIME} - ${_LAST_SNAPSHOT_UNIXTIME} ]

        [ "${_MODE}" == "debug" ] \
            && echo "${_LAST_SNAPSHOT_UNIXTIME} ${_COMPOSITION_NAME} on ${_REMOTE_HOSTNAME_FQDN} behind: ${_SECONDS_BEHIND}s" >> ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOST}.txt

        [ "${_SECONDS_BEHIND}" -lt 40 ] \
            && continue

        [ "${_SECONDS_BEHIND}" -lt 60 ] \
            && echo "ZFSSYNC_of_${_REMOTE_HOSTNAME_SHORT}_LAGGING?WARN#${_COMPOSITION_NAME} ${_SECONDS_BEHIND}s" \
            && continue

        echo "ZFSSYNC_of_${_REMOTE_HOSTNAME_SHORT}_LAGGING?FAIL#${_COMPOSITION_NAME} ${_SECONDS_BEHIND}s"
    done
}

base.set REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$'
base.set GIVEN_REMOTE_HOSTNAME_FQDN "${2}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)?$'
base.set MODE "${3:-"normal"}" '^(debug|normal)$'

RESULTS=$(checkSync "${REMOTE_HOST}" "${MODE}" "${GIVEN_REMOTE_HOSTNAME_FQDN}")

[ "${MODE}" == "debug" ] \
    && echo "$RESULTS" > ${_DEBUG_PATH}RESULTS_${REMOTE_HOST}.txt

echo "$RESULTS"

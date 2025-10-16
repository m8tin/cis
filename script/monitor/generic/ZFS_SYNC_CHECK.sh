#!/bin/bash

_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SCRIPT%%/script/monitor/*}/"             #Removes longest  matching pattern '/script/monitor/*' from the end
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_COMPOSITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/compositions/"

_REMOTE_HOST="${1:?"FQDN of server missing: e.g. host.example.net[:port]"}"
_REMOTE_HOSTNAME_FQDN="${_REMOTE_HOST%%:*}"            #Removes longest  matching pattern ':*' from the end
_REMOTE_HOSTNAME_SHORT="${_REMOTE_HOSTNAME_FQDN%%.*}"  #Removes longest  matching pattern '.*' from the end
_REMOTE_PORT="${_REMOTE_HOST}:"
_REMOTE_PORT="${_REMOTE_PORT#*:}"                      #Removes shortest matching pattern '*:' from the begin
_REMOTE_PORT="${_REMOTE_PORT%%:*}"                     #Removes longest  matching pattern ':*' from the end
_REMOTE_PORT="${_REMOTE_PORT:-"22"}"
_REMOTE_USER="monitoring"
_SOCKET='~/.ssh/%r@%h:%p'

# This is crucial:
#  - default value for the filter part is extracted from the first parameter (FQDN)
#  - but you can override this part to to adapt the test during a change of the domain.
#    (e.g. the short hostname can be an option - or even a better default in the future)
_ZFS_SNAPSHOT_FILTER="@SYNC_${2:-"${_REMOTE_HOSTNAME_FQDN:?"Missing REMOTE_HOSTNAME_FQDN"}"}"

_MODE="${3:-"normal"}"
_NOW_UTC_UNIXTIME=$(date -u +%s)
_DEBUG_PATH="/tmp/monitor/"



function checkOrStartSSHMaster() {
    timeout --preserve-status 1 ssh -O check -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 2>&1 | grep -q -F 'Master running' \
        && return 0

    ssh -O stop -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} &> /dev/null
    ssh -o ControlMaster=auto \
        -o ControlPath=${_SOCKET} \
        -o ControlPersist=65 \
        -p ${_REMOTE_PORT} \
        -f ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} exit &> /dev/null \
        && return 0

    echo "FAIL#SSH connection (setup ok?)"
    return 1
}

function checkSync() {
    checkOrStartSSHMaster \
        || return 1

    [ "${_MODE}" == "debug" ] \
        && mkdir -p "${_DEBUG_PATH}" > /dev/null \
        && echo "Now: ${_NOW_UTC_UNIXTIME}" > ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOSTNAME_FQDN}.txt

    ! [ -d "${_COMPOSITIONS:?"Missing COMPOSITIONS"}" ] \
        && echo "WARN#no compositions" \
        && return 0

    [ "${_MODE}" == "debug" ] \
        && echo "Snapshot filter: ${_ZFS_SNAPSHOT_FILTER}" >> ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOSTNAME_FQDN}.txt

    # This retrieves the list of the interesting snapshots including creation timestamp
    _SNAPSHOTS="$(ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} zfs list -po creation,name -r -t snapshot zpool1/persistent | grep -F ${_ZFS_SNAPSHOT_FILTER})"
    [ "${_MODE}" == "debug" ] \
        && echo "${_SNAPSHOTS}" > ${_DEBUG_PATH}SNAPSHOTS_${_REMOTE_HOSTNAME_FQDN}.txt

    [ -z "${_SNAPSHOTS}" ] \
        && echo "FAIL#no snapshots" \
        && return 1

    echo "OK#Checks running"

    for _COMPOSITION_PATH in ${_COMPOSITIONS}*; do

        # If remote host is found than it is responsible for this container-composition, otherwise skip
        #   (grep -E "^[[:blank:]]*something" means. Line has to start with "something", leading blank chars are ok.)
        grep -E "^[[:blank:]]*${_REMOTE_HOSTNAME_SHORT}" "${_COMPOSITION_PATH}/zfssync-hosts" &> /dev/null \
            || continue;

        _COMPOSITION_NAME="${_COMPOSITION_PATH##*/}"   #Removes longest  matching pattern '*/' from the begin
        _LAST_SNAPSHOT_UNIXTIME="$(echo "${_SNAPSHOTS}" | grep ${_COMPOSITION_NAME} | tail -n 1 | cut -d' ' -f1)"
        _SECONDS_BEHIND=$[ ${_NOW_UTC_UNIXTIME} - ${_LAST_SNAPSHOT_UNIXTIME} ]

        [ "${_MODE}" == "debug" ] \
            && echo "${_LAST_SNAPSHOT_UNIXTIME} ${_COMPOSITION_NAME} on ${_REMOTE_HOSTNAME_FQDN} behind: ${_SECONDS_BEHIND}s" >> ${_DEBUG_PATH}SECONDS_BEHIND_${_REMOTE_HOSTNAME_FQDN}.txt

        [ "${_SECONDS_BEHIND}" -lt 40 ] \
            && continue

        [ "${_SECONDS_BEHIND}" -lt 60 ] \
            && echo "ZFSSYNC_of_${_REMOTE_HOSTNAME_SHORT}_LAGGING?WARN#${_COMPOSITION_NAME} ${_SECONDS_BEHIND}s" \
            && continue

        echo "ZFSSYNC_of_${_REMOTE_HOSTNAME_SHORT}_LAGGING?FAIL#${_COMPOSITION_NAME} ${_SECONDS_BEHIND}s"
    done
}



RESULTS="$(checkSync)"

[ "${_MODE}" == "debug" ] \
    && echo "$RESULTS" > ${_DEBUG_PATH}RESULTS_${_REMOTE_HOSTNAME_FQDN}.txt

echo "$RESULTS"

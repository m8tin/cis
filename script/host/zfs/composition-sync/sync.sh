#!/bin/bash

# Folders always ends with an tailing '/'
_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CIS_ROOT="${_SCRIPT%/script/host/zfs/composition-sync/sync.sh}/"  #Removes shortest matching pattern '/script/host/zfs/composition-sync/sync.sh' from the end
_DOMAIN="$("${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh")"
_DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"


function stopObsoleteScreenSession() {
    local _RECEIVERHOST _SYNCHOSTS_FILE _SCREEN_SESSION _COMPOSITION _PID
    _RECEIVERHOST="${1:?"stopObsoleteScreenSession(): Missing first parameter RECEIVERHOST"}"
    _SYNCHOSTS_FILE="${2:?"stopObsoleteScreenSession(): Missing second parameter SYNCHOSTS_FILE"}"
    _SCREEN_SESSION="${3:?"stopObsoleteScreenSession(): Missing third parameter SCREEN_SESSION"}"
    _COMPOSITION=$(echo "$_SCREEN_SESSION" | grep -oE "[^.]+$")
    _PID=$(echo "$_SCREEN_SESSION" | grep -oE "^[0-9]+")
    readonly _RECEIVERHOST _SYNCHOSTS_FILE _SCREEN_SESSION _COMPOSITION _PID

    ! grep -qiE "^${_RECEIVERHOST}$" "${_DEFINITIONS}compositions/${_COMPOSITION}/${_SYNCHOSTS_FILE}" \
        && echo "Stopping sync screen session of composition: ${_COMPOSITION}" \
        && screen -XS "${_PID}" quit
}

function cleanSessions() {
    local _RECEIVERHOST _SYNCHOSTS_FILE
    _RECEIVERHOST="${1:?"cleanSessions(): Missing first parameter RECEIVERHOST"}"
    _SYNCHOSTS_FILE="${2:?"cleanSessions(): Missing second parameter SYNCHOSTS_FILE"}"
    readonly _RECEIVERHOST _SYNCHOSTS_FILE

    screen -ls | grep -oE "[0-9]+\.compositionsync\.[a-zA-Z0-9_-]+" | while read -r _SCREEN_SESSION; do
        stopObsoleteScreenSession "${_RECEIVERHOST}" "${_SYNCHOSTS_FILE}" "${_SCREEN_SESSION}"
    done
}

function startMissingScreenSession() {
    local _COMPOSITION _SSH_PORT
    _COMPOSITION="${1:?"startMissingScreenSession(): Missing first parameter COMPOSITION"}"
    _SSH_PORT="${2:-22}"
    readonly _COMPOSITION _SSH_PORT

    ! screen -ls | grep -qoE "[0-9]+\.compositionsync\.${_COMPOSITION}" \
        && echo "Starting screen sync session of composition: ${_COMPOSITION}" \
        && screen -dmS "compositionsync.${_COMPOSITION}" "${_SCRIPT}" --loop "${_COMPOSITION}" "${_SSH_PORT}"
}

function addSessions() {
    local _RECEIVERHOST _SYNCHOSTS_FILE
    _RECEIVERHOST="${1:?"addSessions(): Missing first parameter RECEIVERHOST"}"
    _SYNCHOSTS_FILE="${2:?"addSessions(): Missing second parameter SYNCHOSTS_FILE"}"
    readonly _RECEIVERHOST _SYNCHOSTS_FILE

    local _COMPOSITION
    grep -lrE "^${_RECEIVERHOST}" ${_DEFINITIONS}compositions/*/${_SYNCHOSTS_FILE} | while read -r _CURRENT_SYNCHOSTS_FILE; do
        _SSH_PORT=$(grep -E "^${_RECEIVERHOST} usePort [0-9]*.*$" "${_CURRENT_SYNCHOSTS_FILE}" | cut -d' ' -f3 | xargs)
        _COMPOSITION=$(basename $(dirname "${_CURRENT_SYNCHOSTS_FILE}"))
        startMissingScreenSession "${_COMPOSITION}" "${_SSH_PORT}"
    done
}

function destroySyncSnapshot() {
    local _ZFS _SNAPSHOT
    _ZFS="${1:?"destroySyncSnapshot(): Missing first parameter ZFS"}"
    _SNAPSHOT="${2}"
    readonly _ZFS _SNAPSHOT

    # Nothing to do
    [ -z "${_SNAPSHOT}" ] && return 0

    echo "${_SNAPSHOT}" | grep -qF "${_ZFS:?"destroySyncSnapshot(): Missing ZFS"}@SYNC" \
        && zfs destroy "${_SNAPSHOT}" \
        && return 0

    return 1
}

function protectZFS() {
    local _ZFS
    _ZFS="${1:?"protectZFS(): Missing first parameter ZFS"}"
    readonly _ZFS

    zfs set readonly=on "${_ZFS}"
    zfs set mountpoint=none "${_ZFS}"

    return 0
}

function removeForeignSyncSnapshots() {
    local _RECEIVERHOST _ZFS
    _RECEIVERHOST="${1:?"removeForeignSyncSnapshots(): Missing first parameter RECEIVERHOST"}"
    _ZFS="${2:?"removeForeignSyncSnapshots(): Missing second parameter ZFS"}"
    readonly _RECEIVERHOST _ZFS

    zfs list -t snapshot -H -o name "${_ZFS}" | grep -- "${_ZFS}@SYNC" | grep -v -i "@SYNC_${_RECEIVERHOST}_" | while read _SNAP; do
    echo -n "Removing foreign snapshot:  ${_SNAP} ... " \
        && destroySyncSnapshot "${_ZFS}" "${_SNAP}" \
        && echo "done"
    done

    return 0
}

function removeOutdatedSyncSnapshots() {
    local _RECEIVERHOST _ZFS _NEWEST_SNAPSHOT
    _RECEIVERHOST="${1:?"removeOutdatedSyncSnapshots(): Missing first parameter RECEIVERHOST"}"
    _ZFS="${2:?"removeOutdatedSyncSnapshots(): Missing second parameter ZFS"}"
    _NEWEST_SNAPSHOT=$(zfs list -H -o name -S name -t snapshot "${_ZFS}" | grep -E "^${_ZFS}@SYNC_${_RECEIVERHOST}_" | head -n 1)
    readonly _RECEIVERHOST _ZFS _NEWEST_SNAPSHOT

    # Nothing to do, because if there is no newest snapshot then there cannot be anyone
    [ -z "${_NEWEST_SNAPSHOT}" ] && return 0

    # Remove all but the newest snapshot, which is the common snapshot in the next run
    zfs list -t snapshot -H -o name "${_ZFS}" | grep -- "${_ZFS}@SYNC_${_RECEIVERHOST}_" | grep -v -i "${_NEWEST_SNAPSHOT}" | while read _SNAP; do
    echo -n "Removing outdated snapshot: ${_SNAP} ... " \
        && destroySyncSnapshot "${_ZFS}" "${_SNAP}" \
        && echo "done"
    done

    return 0
}

function receive() {
    local _RECEIVERHOST _COMPOSITION _SEND_SCRIPT
    _RECEIVERHOST="${1:?"receive(): Missing first parameter RECEIVERHOST"}"
    _COMPOSITION="${2:?"receive(): Missing second parameter COMPOSITION"}"
    _SEND_SCRIPT="${_CIS_ROOT:?"Missing CIS_ROOT"}script/host/zfs/composition-sync/sync-send.sh"
    readonly _RECEIVERHOST _COMPOSITION _SEND_SCRIPT

    (
        flock -n 9 || exit 1

        _SOURCEHOST=$(cat ${_DEFINITIONS}compositions/${_COMPOSITION}/current-host)

        _ZFS="zpool1/persistent/${_COMPOSITION}-BACKUP"
        _SSH_COMMAND="ssh -p ${_SSH_PORT} -o ConnectTimeout=20 -o ServerAliveInterval=15 -C composition-sync@${_SOURCEHOST}"

        _COMMON_SNAPSHOT=""
        _RESUME_TOKEN=$(zfs get -H -o value receive_resume_token "${_ZFS}" 2> /dev/null)
        if [ -n "${_RESUME_TOKEN}" ] && [ "${_RESUME_TOKEN}" != "-" ]; then
            echo "Resume token present trying to resume at ${_RESUME_TOKEN}"
            _COMMON_SNAPSHOT="RESUME"
        else
            _RESUME_TOKEN=""
            _COMMON_SNAPSHOT=$(zfs list -H -o name -S creation -t snapshot "${_ZFS}" 2> /dev/null | head -n 1)
            ! [ -z "${_COMMON_SNAPSHOT}" ] \
                && echo "Rolling back to newest snapshot: ${_COMMON_SNAPSHOT}" \
                && zfs rollback -r "${_COMMON_SNAPSHOT}"
        fi

        # Add "-s" for resumable streams in the next line at zfs receive. Not done yet because of: cannot receive resume stream: kernel modules must be upgraded to receive this stream.
        ${_SSH_COMMAND} "sudo ${_SEND_SCRIPT:?"Missing SEND_SCRIPT"} \"${_RECEIVERHOST}\" \"${_COMPOSITION}\" \"${_COMMON_SNAPSHOT#${_ZFS}@}\" \"${_RESUME_TOKEN}\"" | zfs receive -v "${_ZFS}"
        if [ $? -ne 0 ]; then
            tryRollbackToRepair "${_RECEIVERHOST}" "${_ZFS}" && return 0
            echo "Unable to receive stream using these settings:"
            echo "  - Sending host:     ${_SOURCEHOST}:${_SSH_PORT}"
            echo "  - Receiving host:   ${_RECEIVERHOST}"
            echo "  - Composition:      ${_COMPOSITION}"
            echo "  - Offered snapshot: ${_COMMON_SNAPSHOT}"
            echo "  - Resume token:     ${_RESUME_TOKEN}"
            echo "Current state of snapshots:"
            zfs list -t snapshot "${_ZFS}" 2> /dev/null | tail
            return 1
        fi

        protectZFS "${_ZFS}"
        removeForeignSyncSnapshots "${_RECEIVERHOST}" "${_ZFS}"
        removeOutdatedSyncSnapshots "${_RECEIVERHOST}" "${_ZFS}"

    ) 9>>/tmp/synccomposition.${_COMPOSITION}.lock

    [ $? -eq 0 ] && return 0

    return 1
}

function tryRollbackToRepair() {
    local _RECEIVERHOST _ZFS _ROLLBACK_DAY _ROLLBACK_SNAPSHOT
    _RECEIVERHOST="${1:?"tryRollbackToRepair(): Missing first parameter RECEIVERHOST"}"
    _ZFS="${2:?"tryRollbackToRepair(): Missing second parameter ZFS"}"
    _ROLLBACK_DAY=$(head -n 1 "${_DEFINITIONS:?"Missing DEFINITIONS"}/compositions/${_COMPOSITION:?"Missing COMPOSITION"}/rollback")
    _ROLLBACK_SNAPSHOT=$(zfs list -t snapshot -H -o name -S creation "${_ZFS}" | head -n 1 | grep -F -- "@SYNC_${_RECEIVERHOST}_${_ROLLBACK_DAY}_")
    readonly _RECEIVERHOST _ZFS _ROLLBACK_DAY _ROLLBACK_SNAPSHOT

    # Nothing to do
    [ -z "${_ROLLBACK_SNAPSHOT}" ] && return 0

    # Remove at most the two newest sync snapshots, if the day matches with the rollback file
    echo "Try to fix by removing: '${_ROLLBACK_SNAPSHOT}'" \
        && zfs destroy "${_ROLLBACK_SNAPSHOT:?"tryRollbackToRepair(): Missing _ROLLBACK_SNAPSHOT"}" \
        && return 0

    return 1

}



MODE=$(echo "${1:?"MODE missing [--all, --once, --loop]"}" | sed -E 's|[^a-zA-Z0-9_-]*||g')
COMPOSITION=$(echo "${2}" | sed -E 's|[^a-zA-Z0-9_-]*||g')
RECEIVERHOST=$(hostname -b)
_SSH_PORT=$(echo "${3:-22}" | sed -E 's/[^0-9]//g')

[ "${MODE}" == "--all" ] \
    && cleanSessions "${RECEIVERHOST}" composition-sync-hosts \
    && addSessions "${RECEIVERHOST}" composition-sync-hosts \
    && exit 0

[ "${MODE}" == "--once" ] \
    && receive "${RECEIVERHOST}" "${COMPOSITION}" \
    && exit 0

[ "${MODE}" == "--loop" ] && while true; do
    receive "${RECEIVERHOST}" "${COMPOSITION}" \
        && echo "Sleep for 5s" \
        && sleep 5 \
        && echo \
        && continue

    echo
    echo "Waiting 5min then ABORT!"
    sleep 300
    break
done

exit 1

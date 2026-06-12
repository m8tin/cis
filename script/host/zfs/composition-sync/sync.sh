#!/bin/bash
source /cis/core/base.module.sh
base.loadModule composition



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
    _ZFS="${1:?"removeForeignSyncSnapshots(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${CIS[HOST]:?"Missing CIS_HOST"}"
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
    _ZFS="${1:?"removeOutdatedSyncSnapshots(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${CIS[HOST]:?"Missing CIS_HOST"}"
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

function tryRollbackToRepair() {
    local _COMPOSITION _RECEIVERHOST _ZFS _ROLLBACK_DAY _ROLLBACK_SNAPSHOT
    _COMPOSITION="${1:?"tryRollbackToRepair(): Missing first parameter COMPOSITION"}"
    _ZFS="${2:?"tryRollbackToRepair(): Missing second parameter ZFS"}"
    _RECEIVERHOST="${CIS[HOST]:?"Missing CIS_HOST"}"
    _ROLLBACK_DAY=$(head -n 1 "${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/${_COMPOSITION:?"Missing COMPOSITION"}/rollback")
    base.set _ROLLBACK_DAY "${_ROLLBACK_DAY:-'2020-01-01'}" '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    _ROLLBACK_SNAPSHOT=$(zfs list -H -o name -S creation -t snapshot "${_ZFS}" | head -n 1 | grep -F -- "@SYNC_${_RECEIVERHOST}_${_ROLLBACK_DAY}_")
    readonly _COMPOSITION _RECEIVERHOST _ZFS _ROLLBACK_SNAPSHOT

    # Not allowed to do anything
    [ -z "${_ROLLBACK_SNAPSHOT}" ] && return 1

    # Remove at most the two newest sync snapshots, if the day matches with the rollback file
    echo "Try to fix by removing: '${_ROLLBACK_SNAPSHOT}'" \
        && zfs destroy "${_ROLLBACK_SNAPSHOT:?"tryRollbackToRepair(): Missing _ROLLBACK_SNAPSHOT"}" \
        && return 0

    return 1
}

function receive() {
    local _RECEIVERHOST _COMPOSITION _SOURCEHOST _SSH_PORT _SSH_COMMAND _SEND_SCRIPT _ZFS_BRANCH _ZFS
    _COMPOSITION="${1:?"receive(): Missing first parameter COMPOSITION"}"
    _RECEIVERHOST="${CIS[HOST]:?"Missing CIS_HOST"}"
    _SOURCEHOST=$(head -n 1 "${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/${_COMPOSITION}/current-host" 2> /dev/null)
    base.set _SOURCEHOST "${_SOURCEHOST}" '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'
    _SSH_PORT=$(head -n 1 "${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/${_COMPOSITION}/ssh-port" 2> /dev/null)
    base.set _SSH_PORT "${_SSH_PORT:-22}" '^[1-9][0-9]{1,4}$'
    _SSH_COMMAND="ssh -p ${_SSH_PORT} -o ConnectTimeout=20 -o ServerAliveInterval=15 -C composition-sync@${_SOURCEHOST}"
    _SEND_SCRIPT="${CIS[SCRIPTSROOT]:?"Missing CIS_SCRIPTSROOT"}host/zfs/composition-sync/sync-send.sh"
    _ZFS_BRANCH=$(head -n 1 "${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/${_COMPOSITION}/zfs-branch" 2> /dev/null)
    base.set _ZFS_BRANCH "${_ZFS_BRANCH:-zpool1/persistent}" '^[a-zA-Z][a-zA-Z0-9/_-]*[a-zA-Z0-9]$'
    _ZFS="${_ZFS_BRANCH%/}/${_COMPOSITION}-BACKUP"
    readonly _RECEIVERHOST _COMPOSITION _SSH_COMMAND _SEND_SCRIPT _ZFS_BRANCH _ZFS
    (
        flock -n 9 || exit 1

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
        ${_SSH_COMMAND} "sudo ${_SEND_SCRIPT:?"Missing SEND_SCRIPT"} \"${_RECEIVERHOST}\" \"${_ZFS_BRANCH}\" \"${_COMPOSITION}\" \"${_COMMON_SNAPSHOT#${_ZFS}@}\" \"${_RESUME_TOKEN}\"" | zfs receive -v "${_ZFS}"
        if [ $? -ne 0 ]; then
            echo "Unable to receive stream using these settings:"
            echo "  - Sending host:     ${_SOURCEHOST}:${_SSH_PORT}"
            echo "  - Receiving host:   ${_RECEIVERHOST}"
            echo "  - Composition:      ${_COMPOSITION}"
            echo "  - Offered snapshot: ${_ZFS}@${_COMMON_SNAPSHOT#${_ZFS}@}"
            echo "  - Resume token:     ${_RESUME_TOKEN}"
            echo "Current state of snapshots:"
            zfs list -t snapshot "${_ZFS}" 2> /dev/null | tail
            tryRollbackToRepair "${_COMPOSITION}" "${_ZFS}" && return 0
            return 1
        fi

        protectZFS "${_ZFS}"
        removeForeignSyncSnapshots "${_ZFS}"
        removeOutdatedSyncSnapshots "${_ZFS}"

    ) 9>>/tmp/synccomposition.${_COMPOSITION}.lock

    [ $? -eq 0 ] && return 0

    return 1
}

function receiveLoopAll() {
    local _SCRIPT
    _SCRIPT="${CIS[FULLSCRIPTNAME]:?"startMissingScreenSession(): Missing CIS_FULLSCRIPTNAME"}"
    readonly _SCRIPT

    composition.printAllSyncedByThisHost | while read -r _COMPOSITION; do
        ! screen -ls | grep -qoE "[0-9]+\.compositionsync\.${_COMPOSITION}" \
            && echo "Starting screen sync session of composition: ${_COMPOSITION}" \
            && screen -dmS "composition-sync:${_COMPOSITION}" "${_SCRIPT}" --loopSingle "${_COMPOSITION}"
    done
}

function receiveLoopSingle() {
    local _COMPOSITION
    _COMPOSITION="${1:?"receiveLoopSingle(): Missing first parameter COMPOSITION"}"
    readonly _COMPOSITION

    while composition.isSyncedByThisHost "${_COMPOSITION}"; do
        receive "${_COMPOSITION}" \
            && echo "Sleep for 5s" \
            && sleep 5 \
            && echo \
            && continue

        # If there is a screen session this keeps it alive in case of an error for debugging
        echo
        echo "Waiting 5min then ABORT!"
        sleep 300
        return 1
    done

    ! composition.isSyncedByThisHost "${_COMPOSITION}" \
        && echo "This host '${CIS[HOST]}' is no sync-host (anymore) for composition: '${_COMPOSITION}'"
}

function receiveOnceAll() {
    local _COMPOSITION

    composition.printAllSyncedByThisHost | while read -r _COMPOSITION; do
        receive "${_COMPOSITION}"
    done

    return 0
}

function receiveOnceSingle() {
    local _COMPOSITION
    _COMPOSITION="${1:?"receiveOnceSingle(): Missing first parameter COMPOSITION"}"
    readonly _COMPOSITION

    ! composition.isSyncedByThisHost "${_COMPOSITION}" \
        && echo "This host '${CIS[HOST]}' is no sync-host for composition: '${_COMPOSITION}'" \
        && return 1

    receive "${_COMPOSITION}" \
        && return 0

    return 1
}

function usage() {
    echo
    echo 'Commands:'
    echo '  --loopAll                   : This will start one screen session per composition ("composition-sync-hosts"),'
    echo '                                    and run the sync process in an endless loop.'
    echo '  --onceAll                   : This will run the sync process once for each composition ("composition-sync-hosts").'
    echo '                                    e.g.: you can use it in crontab as a daily backup.'
    echo '  --loopSingle COMPOSITION    : This will run the sync process in an endless loop but just for the specified COMPOSITION.'
    echo '  --onceSingle COMPOSITION    : This will run the sync process once just for the specified COMPOSITION.'
    echo
    echo 'Current environment:'
    echo "    Full name of this script  : FULLSCRIPTNAME='${CIS[FULLSCRIPTNAME]}'"
    echo "  Configuration:"
    echo "    Receiving host (this host): RECEIVERHOST='${CIS[HOST]}'"

    return 0
}



# Parameter 2: is optional '()?' and only a subset of alphanumeric characters are allowed and [_-] if not leading (due to: -oProxyCommand=...).
base.set COMPOSITION "${2}" '^([a-zA-Z0-9][a-zA-Z0-9_-]*)?$'

case "${1}" in
    --onceAll)
        receiveOnceAll \
            && exit 0
        ;;
    --onceSingle)
        receiveOnceSingle "${COMPOSITION}" \
            && exit 0
        ;;
    --loopAll)
        receiveLoopAll \
            && exit 0
        ;;
    --loopSingle)
        receiveLoopSingle "${COMPOSITION}" \
            && exit 0
        ;;
    *)
        echo "Unknown command '${1}' '${2}'"
        usage
        exit 1
        ;;
esac

exit 1

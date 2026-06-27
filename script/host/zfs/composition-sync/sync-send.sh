#!/bin/bash
source /cis/core/base.module.sh
base.loadModule composition
base.loadModule print



function printNewestOrdinarySnapshot() {
    local _ZFS _RECEIVERHOST
    _ZFS="${1:?"printNewestOrdinarySnapshot(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${2:?"printNewestOrdinarySnapshot(): Missing second parameter RECEIVERHOST"}"
    readonly _ZFS _RECEIVERHOST

    local _RESULT
    _RESULT=$(zfs list -H -o name -S creation -t snapshot "${_ZFS}" | grep -vF '@SYNC' | head -n 1 | cut -d'@' -f2)

    [ -n "${_RESULT}" ] \
        && echo "@${_RESULT}" \
        && return 0

    echo "NOT AVAILABLE"
    return 1
}

function printNewestSyncSnapshot() {
    local _ZFS _RECEIVERHOST
    _ZFS="${1:?"printNewestSyncSnapshot(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${2:?"printNewestSyncSnapshot(): Missing second parameter RECEIVERHOST"}"
    readonly _ZFS _RECEIVERHOST

    local _RESULT
    _RESULT=$(zfs list -H -o name -S creation -t snapshot "${_ZFS}" | grep -E "^${_ZFS}@SYNC_${_RECEIVERHOST}_" | head -n 1 | cut -d'@' -f2)

    [ -n "${_RESULT}" ] \
        && echo "@${_RESULT}" \
        && return 0

    echo "NOT AVAILABLE"
    return 1
}

function printFoundCommonSnapshot() {
    local _ZFS _RECEIVERHOST _COMMON_SNAPSHOT_CANDIDATE
    _ZFS="${1:?"printFoundCommonSnapshot(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${2:?"printFoundCommonSnapshot(): Missing second parameter RECEIVERHOST"}"
    _COMMON_SNAPSHOT_CANDIDATE="${3:?"printFoundCommonSnapshot(): Missing third parameter COMMON_SNAPSHOT_CANDIDATE"}"
    readonly _ZFS _RECEIVERHOST _COMMON_SNAPSHOT_CANDIDATE

    while read -r _ROW
    do
        if [ "${_ROW}" == "${_ZFS}${_COMMON_SNAPSHOT_CANDIDATE}" ]; then
            echo "${_ROW}"
            return 0
        fi
    done < <(zfs list -H -o name -S creation -t snapshot "${_ZFS}")

    echo "Expected common snapshot not found:" >&2
    echo "  - snapshot candidate from receiver:   ${_COMMON_SNAPSHOT_CANDIDATE}" >&2
    echo "  - newest ordinary snapshot of sender: $(printNewestOrdinarySnapshot "${_ZFS}" "${_RECEIVERHOST}")" >&2
    echo "  - newest sync snapshot of sender:     $(printNewestSyncSnapshot "${_ZFS}" "${_RECEIVERHOST}")" >&2
    return 1
}

function removeReceiverhostsSyncSnapshotsExeptTheCommonOne() {
    local _ZFS _RECEIVERHOST _COMMON_SNAPSHOT
    _ZFS="${1:?"removeReceiverhostsSyncSnapshotsExeptTheCommonOne(): Missing first parameter ZFS"}"
    _RECEIVERHOST="${2:?"removeReceiverhostsSyncSnapshotsExeptTheCommonOne(): Missing second parameter RECEIVERHOST"}"
    _COMMON_SNAPSHOT="${3:?"removeReceiverhostsSyncSnapshotsExeptTheCommonOne(): Missing third parameter COMMON_SNAPSHOT"}"
    readonly _ZFS _RECEIVERHOST _COMMON_SNAPSHOT

    while read -r _ROW
    do
        # Skip the common snapshot to keep it.
        # If the common snapshot is not a sync-snapshot all sync-snapshots will be removed.
        if [ "${_ROW}" == "${_COMMON_SNAPSHOT}" ]; then
            continue
        fi
        # Destroy all remaining sync-snapshots of the receiving host
        zfs destroy "${_ROW}"
    done < <(zfs list -H -o name -S creation -t snapshot "${_ZFS}" | grep -E "^${_ZFS}@SYNC_${_RECEIVERHOST}_")
}

function send() {
    local _COMPOSITION _RECEIVERHOST _RECEIVERS_SNAPSHOT _RESUME_TOKEN _NOW _ZFS _NEW_SNAPSHOT
    _COMPOSITION="${1:?"send(): Missing first parameter COMPOSITION"}"
    _RECEIVERHOST="${2:?"send(): Missing second parameter RECEIVERHOST"}"
    _RECEIVERS_SNAPSHOT="${3:?"send(): Missing third parameter RECEIVERS_SNAPSHOT"}"
    _RESUME_TOKEN="${4}"
    _NOW=$(date -u "+%Y-%m-%d_%H:%M:%SZ")
    _ZFS=$(composition.printZfsVerified "${_COMPOSITION}")
    _NEW_SNAPSHOT="${_ZFS:?"Missing ZFS"}@SYNC_${_RECEIVERHOST:?"Missing RECEIVERHOST"}_${_NOW:?"Missing NOW"}"
    readonly _COMPOSITION _RECEIVERHOST _RECEIVERS_SNAPSHOT _RESUME_TOKEN _NOW _NEW_SNAPSHOT

    [ "${RECEIVERS_SNAPSHOT}" == '@REPLICATION' ] \
        && [ -z "${RESUME_TOKEN}" ] \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R "${_NEW_SNAPSHOT}" \
        && return 0

    [ "${RECEIVERS_SNAPSHOT}" == '@RESUME' ] \
        && [ -n "${RESUME_TOKEN}" ] \
        && zfs send -t "${_RESUME_TOKEN}" \
        && return 0

    # This common snapshot is the starting-point, if available.
    ! _COMMON_SNAPSHOT=$(printFoundCommonSnapshot "${_ZFS}" "${_RECEIVERHOST}" "${_RECEIVERS_SNAPSHOT}") \
        && echo "Failure in sync-send.sh: abort" >&2 \
        && return 1

    [ "${_COMMON_SNAPSHOT}" != "" ] \
        && removeReceiverhostsSyncSnapshotsExeptTheCommonOne "${_ZFS}" "${_RECEIVERHOST}" "${_COMMON_SNAPSHOT}" \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R -I "${_COMMON_SNAPSHOT}" "${_NEW_SNAPSHOT}" \
        && return 0

    return 1
}



base.set COMPOSITION        "${1}" "${REGEX[COMPOSITION]}"
base.set RECEIVERHOST       "${2}" "${REGEX[HOST]}"
base.set RECEIVERS_SNAPSHOT "${3}" "${REGEX[SNAPSHOT]}"
base.set RESUME_TOKEN       "${4}" "${REGEX[RESUMETOKEN]}" optional

! composition.shouldBeSyncedByGivenHost "${COMPOSITION}" "${RECEIVERHOST}" \
    && base.abort "no sync-host available" \
        "Host '${RECEIVERHOST}' is no sync-host for composition: '${COMPOSITION}'"

send "${COMPOSITION}" "${RECEIVERHOST}" "${RECEIVERS_SNAPSHOT}" "${RESUME_TOKEN}" \
    && exit 0

print.failure "Something unexpected happend."
exit 1

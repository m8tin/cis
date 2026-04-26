#!/bin/bash
source /cis/core/base.module.sh



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
    _COMMON_SNAPSHOT_CANDIDATE="@${3#*@}"
    readonly _ZFS _RECEIVERHOST _COMMON_SNAPSHOT_CANDIDATE

    # Nothing to do
    [ "${_COMMON_SNAPSHOT_CANDIDATE}" == "@" ] \
        && return 0

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

function sendResume() {
    local _RESUME_TOKEN
    _RESUME_TOKEN="${1:?"sendResume(): Missing first parameter RESUME_TOKEN"}"
    readonly _RESUME_TOKEN

    zfs send -t "${_RESUME_TOKEN:?"Missing RESUME_TOKEN"}" \
        && return 0

    return 1
}

function send() {
    local _ZFS_BRANCH _COMPOSITION _RECEIVERHOST _RECEIVERS_SNAPSHOT _NOW _ZFS _NEW_SNAPSHOT
    _ZFS_BRANCH="${1:?"send(): Missing first parameter ZFS_BRANCH"}"
    _COMPOSITION="${2:?"send(): Missing first parameter COMPOSITION"}"
    _RECEIVERHOST="${3:?"send(): Missing second parameter RECEIVERHOST"}"
    _RECEIVERS_SNAPSHOT="${4}"
    _NOW=$(date -u "+%Y-%m-%d_%H:%M:%SZ")
    _ZFS="${_ZFS_BRANCH:?"Missing ZFS_BRANCH"}/${_COMPOSITION:?"Missing COMPOSITION"}"
    _NEW_SNAPSHOT="${_ZFS:?"Missing ZFS"}@SYNC_${_RECEIVERHOST:?"Missing RECEIVERHOST"}_${_NOW:?"Missing NOW"}"
    readonly _ZFS_BRANCH _COMPOSITION _RECEIVERHOST _RECEIVERS_SNAPSHOT _NOW _ZFS _NEW_SNAPSHOT

    # This common snapshot is the starting-point, if available.
    ! _COMMON_SNAPSHOT=$(printFoundCommonSnapshot "${_ZFS}" "${_RECEIVERHOST}" "${_RECEIVERS_SNAPSHOT}") \
        && echo "Failure in sync-send.sh: abort" >&2 \
        && return 1

    [ "${_COMMON_SNAPSHOT}" == "" ] \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R "${_NEW_SNAPSHOT}" \
        && return 0

    [ "${_COMMON_SNAPSHOT}" != "" ] \
        && removeReceiverhostsSyncSnapshotsExeptTheCommonOne "${_ZFS}" "${_RECEIVERHOST}" "${_COMMON_SNAPSHOT}" \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R -I "${_COMMON_SNAPSHOT}" "${_NEW_SNAPSHOT}" \
        && return 0

    return 1
}



# Parameter 1: Only alphanumeric characters allowed and [._-]  if not leading (due to: -oProxyCommand=...).
# Parameter 2: Only alphanumeric characters allowed and [/_-]  if not leading (due to: -oProxyCommand=...).
# Parameter 3: Only alphanumeric characters allowed and [.-]   if not leading (due to: -oProxyCommand=...).
# Parameter 4: Only alphanumeric characters allowed and [._:-] if not leading (due to: -oProxyCommand=...), but can be empty.
# Parameter 5: Only alphanumeric characters allowed and [._:-] if not leading (due to: -oProxyCommand=...), but can be empty.
base.set RECEIVERHOST "${1}" '^[a-zA-Z0-9][a-zA-Z0-9._-]*$' || exit 1
base.set ZFS_BRANCH "${2}" '^[a-zA-Z][a-zA-Z0-9/_-]*[a-zA-Z0-9]$' || exit 1
base.set COMPOSITION "${3}" '^[a-zA-Z0-9][a-zA-Z0-9.-]*$' || exit 1
base.set RECEIVERS_SNAPSHOT "${4}" '(^[a-zA-Z0-9][a-zA-Z0-9._:-]*$)?' || exit 1
base.set RESUME_TOKEN "${5}" '(^[a-zA-Z0-9][a-zA-Z0-9._:-]*$)?' || exit 1

# Resume mode
if [ "${RECEIVERS_SNAPSHOT}" == "RESUME" ]; then
    sendResume "${RESUME_TOKEN}"

    # Exit preserving the code
    exit $?
fi

send "${ZFS_BRANCH}" "${COMPOSITION}" "${RECEIVERHOST}" "${RECEIVERS_SNAPSHOT}" \
    && exit 0

echo "Failure in sync-send.sh: Something unexpected happend." >&2
exit 1

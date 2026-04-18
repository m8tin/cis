#!/bin/bash

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

    zfs send -t "${RESUME_TOKEN}" \
        && return 0

    return 1
}

function isValid() {
    # printf '%s'
    #  - always treats the contents of ${1} as pure plain text.
    # grep -qE: checks RegExp, but quiet
    printf '%s' "${1}" | grep -qE "${2:?"isValid(): Missing REGEXP"}"
}

function isValidOptional() {
    [ -z "${1}" ] || isValid "${1}" "${2}"
}



# Parameter 1: Only alphanumeric characters allowed and [._-]  if not leading (due to: -oProxyCommand=...).
# Parameter 2: Only alphanumeric characters allowed and [.-]   if not leading (due to: -oProxyCommand=...).
# Parameter 3: Only alphanumeric characters allowed and [._:-] if not leading (due to: -oProxyCommand=...), but can be empty.
# Parameter 4: Only alphanumeric characters allowed and [._:-] if not leading (due to: -oProxyCommand=...), but can be empty.
if isValid "${1:?"RECEIVERHOST missing"}" '^[a-zA-Z0-9][a-zA-Z0-9._-]*$' \
    && isValid "${2:?"COMPOSITION missing"}" '^[a-zA-Z0-9][a-zA-Z0-9.-]*$' \
    && isValidOptional "${3}" '^[a-zA-Z0-9][a-zA-Z0-9._:-]*$' \
    && isValidOptional "${4}" '^[a-zA-Z0-9][a-zA-Z0-9._:-]*$'
then
    _RECEIVERHOST="${1}"
    _COMPOSITION="${2}"
    _RECEIVERS_SNAPSHOT="${3}"
    _RESUME_TOKEN="${4}"

    _NOW=$(date -u "+%Y-%m-%d_%H:%M:%S")
    _ZFS="zpool1/persistent/${_COMPOSITION:?"COMPOSITION missing"}"
    _NEW_SNAPSHOT="${_ZFS:?"ZFS missing"}@SYNC_${_RECEIVERHOST:?"RECEIVERHOST missing"}_${_NOW:?"NOW missing"}"

    # Resume mode
    if [ "${_RECEIVERS_SNAPSHOT}" == "RESUME" ]; then
        sendResume "${_RESUME_TOKEN}"

        # Exit preserving the code 
        exit $?
    fi

    # This common snapshot is the starting-point, if available.
    ! _COMMON_SNAPSHOT=$(printFoundCommonSnapshot "${_ZFS}" "${_RECEIVERHOST}" "${_RECEIVERS_SNAPSHOT}") \
        && echo "Failure in sync-send.sh: abort" >&2 \
        && exit 1

    [ "${_COMMON_SNAPSHOT}" == "" ] \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R "${_NEW_SNAPSHOT}" \
        && exit 0

    [ "${_COMMON_SNAPSHOT}" != "" ] \
        && removeReceiverhostsSyncSnapshotsExeptTheCommonOne "${_ZFS}" "${_RECEIVERHOST}" "${_COMMON_SNAPSHOT}" \
        && zfs snapshot "${_NEW_SNAPSHOT}" \
        && zfs send -c -R -I "${_COMMON_SNAPSHOT}" "${_NEW_SNAPSHOT}" \
        && exit 0

else
    echo "Failure in sync-send.sh: At least one parameter is invalid." >&2
    exit 1
fi

echo "Failure in sync-send.sh: Something unexpected happend." >&2
exit 1

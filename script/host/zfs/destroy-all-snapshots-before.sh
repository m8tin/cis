#!/bin/bash
source /cis/core/base.module.sh



function listSnapshotsToDestroy() {
    local _FILESYSTEM _SNAPSHOT
    _SNAPSHOT="${1:?"Missing first parameter SNAPSHOT"}"
    _FILESYSTEM="$(echo ${_SNAPSHOT} | cut -d@ -f1)"
    readonly _FILESYSTEM _SNAPSHOT

    for _CURRENT in $(zfs list -Ho name -s creation -t snapshot "${_FILESYSTEM:?"Missing first parameter FILESYSTEM"}")
    do
        [ -z "${_CURRENT}" ] \
            && return 1

        [ "${_SNAPSHOT}" == "${_CURRENT}" ] \
            && break

        echo "${_CURRENT}"
    done
    return 0
}

function main() {
    local _SNAPSHOT
    _SNAPSHOT="${1:?"Missing first parameter SNAPSHOT"}"
    readonly _SNAPSHOT

    ! echo "${_SNAPSHOT}" | grep -q "@" \
        && echo "This is not a snapshot: ${_SNAPSHOT}" \
        && return 1

    ! zfs list "${_SNAPSHOT}" &> /dev/null \
        && echo "The snapshot does not exist: ${_SNAPSHOT}" \
        && return 1

    listSnapshotsToDestroy "${_SNAPSHOT}" | xargs -r -p -n1 zfs destroy \
        && return 0

    return 1
}

base.set SNAPSHOT "${1}" '^[-0-9a-zA-Z_/]@[-0-9a-zA-Z_:.]'
main "${SNAPSHOT:?"Missing first parameter SNAPSHOT"}" && exit 0

echo "Something went wrong."
exit 1


#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

_TIMESTAMP="$(date -u "+%Y%m%d%H%M")"
_ZFS_FILESYSTEM="${1:?"Missing first parameter ZFS_FILESYSTEM."}"
echo "${_ZFS_FILESYSTEM}" | grep -E '\-prod$' &> /dev/null \
    && zfs snapshot "${_ZFS_FILESYSTEM}@SNAPMINUTLY_${_TIMESTAMP}" \
    && exit 0

echo "Snapshot konnte nicht angelegt werden:"
echo "  - ${_ZFS_FILESYSTEM}@SNAPMINUTLY_${_TIMESTAMP}"
echo "  (Minuten-Snapshots sollen nur auf 'PROD'-Containeren angelegt werden, sodass diese dann syncronisiert werden)"
exit 1

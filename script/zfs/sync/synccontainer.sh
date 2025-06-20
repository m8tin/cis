#!/bin/bash
BACKUPHOST=$(hostname)
CONTAINER=${1:?"Kein Container angegeben"}
DATASET="zpool1/persistent/$CONTAINER"
SNAPSHOT_PREFIX="${DATASET}@SYNC_${BACKUPHOST}_"

while true; do

	/invra/scripts/hosts/zfs/synccontainer-receiver.sh "$CONTAINER"
	sleep 5

#	LAST_SNAPSHOT_NAME=$(zfs list -Hr -o name -S name -t snapshot "${DATASET}" | grep -E "^${SNAPSHOT_PREFIX}" | head -n 1)
#	LAST_SNAPSHOT_TIME=${LAST_SNAPSHOT_NAME#${SNAPSHOT_PREFIX}}
#	LAST_SNAPSHOT_TIME="$(echo "${LAST_SNAPSHOT_TIME}" | sed "s/_/ /g")"
#	LAST_SNAPSHOT_UNIXTIME=$(date -u --date="TZ=\"UTC\" ${LAST_SNAPSHOT_TIME}" +%s)
#	CURRENT_UNIXTIME=$(date -u +%s)
#	SECONDS_BEHIND=$[ $CURRENT_UNIXTIME - $LAST_SNAPSHOT_UNIXTIME ]
#	mkdir -p /var/www/html/monitoring > /dev/null 2>&1
#	echo $CURRENT_UNIXTIME > "/var/www/html/monitoring/containersync.${CONTAINER}"
#	echo "OK: $SECONDS_BEHIND seconds behind" >> "/var/www/html/monitoring/containersync.${CONTAINER}"

done


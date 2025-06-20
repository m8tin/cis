#!/bin/bash
TMP="$(mktemp)"
(
	HOSTNAME="$(hostname)"
	HOSTOWNER="$(cat /invra/hostowner)"
	MAX_BEHIND=0
	CURRENT_UNIXTIME=$(date -u +%s)
	echo "OK#Checks running" 
	for CONTAINER_PATH in /invra/state/${HOSTOWNER}/containers/*; do 
		grep -E "^${HOSTNAME}$" "${CONTAINER_PATH}/standby-hosts" &> /dev/null || continue;
		CONTAINER_NAME="$(basename "$CONTAINER_PATH")";
		TS=$(zfs list -o name -r -t snapshot "zpool1/persistent/${CONTAINER_NAME}-BACKUP" | grep "@SYNC_${HOSTNAME}" | head -n1 | grep -oP "\\d{4}-\\d{2}-\\d{2}_\\d{2}:\\d{2}:\\d{2}")
		LAST_SNAPSHOT_TIME="$(echo "${TS}" | sed "s/_/ /g")"
		LAST_SNAPSHOT_UNIXTIME=$(date -u --date="TZ=\"UTC\" ${LAST_SNAPSHOT_TIME}" +%s)
		SECONDS_BEHIND=$[ $CURRENT_UNIXTIME - $LAST_SNAPSHOT_UNIXTIME ]
		if [ "$SECONDS_BEHIND" -gt "$MAX_BEHIND" ]; then
			MAX_BEHIND="$SECONDS_BEHIND"
		fi
		if [ "$SECONDS_BEHIND" -gt 30 ]; then
			echo "LAGGING_SYNC_${CONTAINER_NAME}_${HOSTNAME}?FAIL#${SECONDS_BEHIND} behind"
			
		fi
	done
	echo $CURRENT_UNIXTIME
) > "$TMP"
chmod 655 "$TMP"
mkdir -p /var/www/html/monitoring &>/dev/null
mv "$TMP" /var/www/html/monitoring/synccontainer.check.txt



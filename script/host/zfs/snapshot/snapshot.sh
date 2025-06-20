#!/bin/bash
HOUR=$(date -u "+%Y%m%d%H")
DAY=${HOUR:0:8}
MONTH=${HOUR:0:6}
HOSTOWNER=$(cat /invra/hostowner)
if [ ! -d /tmp/locks ]; then
	mkdir /tmp/locks
fi

zfs list -Hr -o name zpool1/persistent | grep -v -- -BACKUP | tail -n +2 | while read DATASET; do
	CONTAINER=${DATASET#zpool1/persistent/}
	(
		flock -n 9 || exit 1

		MODE_FILE="/invra/state/$HOSTOWNER/containers/$CONTAINER/snapshot-mode"
		HOURLY=1
		DAILY=1
		MONTHLY=1

		if [ -f "$MODE_FILE" ]; then
			grep -i "NONE" "$MODE_FILE" &> /dev/null
			if [ $? -eq 0 ]; then
				exit
			fi
			grep -i "HOURLY" "$MODE_FILE" &> /dev/null
			if [ $? -ne 0 ]; then
				HOURLY=0
			fi
			grep -i "DAILY" "$MODE_FILE" &> /dev/null
			if [ $? -ne 0 ]; then
				DAILY=0
			fi
			grep -i "MONTHLY" "$MODE_FILE" &> /dev/null
			if [ $? -ne 0 ]; then
				MONTHLY=0
			fi
		fi
		SNAPSHOT_HOUR="${DATASET}@SNAPHOURLY_${HOUR}"
		SNAPSHOT_DAY="${DATASET}@SNAPDAILY_${DAY}"
		SNAPSHOT_MONTH="${DATASET}@SNAPMONTHLY_${MONTH}"

		zfs list -H -t snapshot -o name -r "$DATASET" | grep -E "^${SNAPSHOT_HOUR}$" > /dev/null
		if [[ $? -ne 0 && $HOURLY -eq 1 ]]; then
			zfs snapshot "${SNAPSHOT_HOUR}"
		fi

		zfs list -H -t snapshot -o name -r "$DATASET" | grep -E "^${SNAPSHOT_DAY}$" > /dev/null
		if [[ $? -ne 0 && $DAILY -eq 1 ]]; then
			zfs snapshot "${SNAPSHOT_DAY}"
		fi

		zfs list -H -t snapshot -o name -r "$DATASET" | grep -E "^${SNAPSHOT_MONTH}$" > /dev/null
		if [[ $? -ne 0 && $MONTHLY -eq 1 ]]; then
			zfs snapshot "${SNAPSHOT_MONTH}"
		fi
	) 9>>/tmp/locks/snapshot.${CONTAINER}.lock
done

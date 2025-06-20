#!/bin/bash

BACKUPHOST=${1:?"BACKUPHOST missing"}
CONTAINER=${2:?"CONTAINER missing"}
BACKUPHOST=$(echo $1 | sed -E 's|[^a-zA-Z0-9._-]*||g')
CONTAINER=$(echo $2 | sed -E 's|[^a-zA-Z0-9_-]*||g')
LAST_SNAPSHOT=$(echo $3 | sed -E 's|[^a-zA-Z0-9._:-]*||g')
NEW_SNAPSHOT=$(date -u "+%Y-%m-%d_%H:%M:%S")

if [[ "${LAST_SNAPSHOT}" == "RESUME" ]]; then
	RESUME_TOKEN=$(echo $4 | sed -E 's|[^a-zA-Z0-9._:-]*||g')
        zfs send -t "${RESUME_TOKEN}"
        exit
fi

DATASET="zpool1/persistent/$CONTAINER"
SNAPSHOT_PREFIX="${DATASET}@SYNC_${BACKUPHOST}_"
LAST_SNAPSHOT_NAME="${SNAPSHOT_PREFIX}${LAST_SNAPSHOT}"
NEW_SNAPSHOT_NAME="${SNAPSHOT_PREFIX}${NEW_SNAPSHOT}"
SNAPSHOT_FOUND=""

# Existiert der Snapshot?
while read -r ZEILE
do
	if [[ "$ZEILE" == "$LAST_SNAPSHOT_NAME" ]]; then
		SNAPSHOT_FOUND="1"
		continue
	fi
done < <(zfs list -H -o name -s name -t snapshot "${DATASET}" | grep -E "^${SNAPSHOT_PREFIX}")

# Falls ja, alle anderen Snapshots wegräumen - eine frühere Version des Skripts hat hier nur die Älteren weggeräumt. Das führt allerdings zum Vollmüllen
# mit neueren Snapshots, wenn der Sync immer wieder fehlschlägt - im Einzelfall bis zur Unbenutzbarkeit des Senders
if [[ "${SNAPSHOT_FOUND}x" == "1x" ]]; then
	while read -r ZEILE
	do
	        if [[ "$ZEILE" == "$LAST_SNAPSHOT_NAME" ]]; then
        	        continue
	        fi
        	zfs destroy "$ZEILE"
	done < <(zfs list -H -o name -s name -t snapshot "${DATASET}" | grep -E "^${SNAPSHOT_PREFIX}")
fi

zfs snapshot "$NEW_SNAPSHOT_NAME"

if [[ "$LAST_SNAPSHOT" != "" ]]; then
	if [[ "$SNAPSHOT_FOUND" == "" ]]; then
		echo "Angeforderter Snapshot '${LAST_SNAPSHOT}' nicht vorhanden"
		exit 1;
	fi
	zfs send -I "${LAST_SNAPSHOT_NAME}" "${NEW_SNAPSHOT_NAME}"
else
	zfs send "${NEW_SNAPSHOT_NAME}"
fi

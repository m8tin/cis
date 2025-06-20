#!/bin/bash
CONTAINER=${1:?"CONTAINER missing"}
CONTAINER=$(echo $1 | sed -E 's|[^a-zA-Z0-9_-]*||g')
(
	flock -n 9 || exit 1

	BACKUPHOST=$(hostname)
	HOSTOWNER=$(cat /invra/hostowner)
	SOURCEHOST=$(cat /invra/state/${HOSTOWNER}/containers/${CONTAINER}/current-host)

	MOUNTPOINT="none"
	DATASET="zpool1/persistent/${CONTAINER}-BACKUP"
	SNAPSHOT_PREFIX="${DATASET}@SYNC_${BACKUPHOST}_"

	LAST_SNAPSHOT_NAME=""
	RESUME_TOKEN=""
	zfs list -Hr -o name -s name "${DATASET}" | grep -E "^${DATASET}$" > /dev/null
	if [ $? -eq 0 ]; then
		LAST_SNAPSHOT_NAME=$(zfs list -H -o name -S name -t snapshot -r "${DATASET}" | grep -E "^${SNAPSHOT_PREFIX}" | head -n 1)
		RESUME_TOKEN="$(zfs get -o value -H receive_resume_token "${DATASET}")"
	fi

	if [[ "x$RESUME_TOKEN" != "x" && "x$RESUME_TOKEN" != "x-" ]]; then
		echo "Resume token present trying to resume at $RESUME_TOKEN"
		LAST_SNAPSHOT_NAME="RESUME"
	fi
	
	if [[ "x${LAST_SNAPSHOT_NAME}" != "x" && "${LAST_SNAPSHOT_NAME}" != "RESUME" ]]; then
		zfs rollback -r "${LAST_SNAPSHOT_NAME}"
	fi

	# Beiim zfs receive in der nächsten Zeile fehlt noch das "-s" für resumable streams. Der tzrlxsrv kann das aber momentan nicht. Fehlermeldung: cannot receive resume stream: kernel modules must be upgraded to receive this stream.
	(while sleep 1; do echo; done) | ssh -o ConnectTimeout=20 -C invencom@${SOURCEHOST} "sudo /invra/scripts/hosts/zfs/synccontainer-sender.sh \"${BACKUPHOST}\" \"${CONTAINER}\" \"${LAST_SNAPSHOT_NAME#$SNAPSHOT_PREFIX}\"" \"${RESUME_TOKEN}\" | zfs receive -v "${DATASET}"
	if [ $? -ne 0 ]; then
		exit 1
	fi

	# Dataset gegen Veränderungen sichern
	zfs set readonly=on "${DATASET}"
	zfs set "mountpoint=${MOUNTPOINT}" "${DATASET}"

	# Aufsetzpunkte fremder Synchronisierer wegräumen
	zfs list -t snapshot -o name -r "${DATASET}" | grep -- "${DATASET}@SYNC" | grep -v -i "_${BACKUPHOST}_" | while read SNAP; do
		echo "Destroying $SNAP"
		zfs destroy $SNAP
	done

	# Alte Snapshots wegräumen
	while read -r ZEILE
	do
		if [ "$ZEILE" = "" ]; then
			break
		fi
		if [[ "$ZEILE" > "$LAST_SNAPSHOT_NAME"  ]]; then
			break
		fi
		zfs destroy "$ZEILE"
	done < <(zfs list -Hr -o name -s name -t snapshot "${DATASET}" | grep -E "^${SNAPSHOT_PREFIX}")
) 9>>/tmp/synccontainer.${CONTAINER}.lock

if [ $? -ne 0 ]; then
	exit 1
fi
exit 0

#!/bin/bash
HOSTOWNER=$(cat /invra/hostowner)
BACKUPHOST=$(hostname)
STATE_DIR=/invra/state/${HOSTOWNER}/containers/;

screen -ls | grep -oE "[0-9]+\.synccontainer\.[a-zA-Z0-9_-]+" | while read -r SCREEN_SESSION; do
	CONTAINER=$(echo "$SCREEN_SESSION" | grep -oE "[^.]+$")
	PID=$(echo "$SCREEN_SESSION" | grep -oE "^[0-9]+")
	grep -iE "^${BACKUPHOST}$" ${STATE_DIR}/${CONTAINER}/standby-hosts > /dev/null
	if [ $? -ne 0 ]; then
		echo "quit screen session ${SCREEN_SESSION}"
		screen -XS "$PID" quit
	fi
done

grep -lrE "^${BACKUPHOST}$" /invra/state/${HOSTOWNER}/containers/*/standby-hosts > /dev/null
if [ $? -eq 0 ]; then
	grep -lrE "^${BACKUPHOST}$" /invra/state/${HOSTOWNER}/containers/*/standby-hosts | while read -r STANDBY_FILE; do
		CONTAINER=$(basename $(dirname ${STANDBY_FILE}))
		screen -ls | grep -oE "[0-9]+\.synccontainer\.$CONTAINER" > /dev/null
		if [ $? -ne 0 ]; then
			echo "starte container sync"
			screen -dmS "synccontainer.$CONTAINER" /invra/scripts/hosts/zfs/synccontainer.sh "$CONTAINER"
		fi
	done
fi


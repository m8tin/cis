#!/bin/bash
MIN_MIN=$(date --date="- 5 minutes" -u "+%Y%m%d%H%M")
HOUR_MIN=$(date --date="- 1 days" -u "+%Y%m%d%H")
DAY_MIN=$(date --date="- 7 days" -u "+%Y%m%d")
MONTH_MIN=$(date --date="- 3 years" -u "+%Y%m")
 
zfs list -Hr -o name -t snapshot -r "zpool1/persistent" | grep -E "^zpool1/persistent/[a-zA-Z0-9_-]+@(SNAPHOURLY|SNAPDAILY|SNAPMONTHLY|SNAPMINUTLY)_[0-9]{6,12}$" | while read SNAPSHOT; do
        SNAPSHOT_TIME=$(echo "$SNAPSHOT" | grep -oE "[0-9]+$")
        if [[ ${#SNAPSHOT_TIME} == 12 && "$SNAPSHOT_TIME" < "${MIN_MIN}" ]]; then
                zfs destroy "${SNAPSHOT}"
        fi
        if [[ ${#SNAPSHOT_TIME} == 10 && "$SNAPSHOT_TIME" < "${HOUR_MIN}" ]]; then
                zfs destroy "${SNAPSHOT}"
        fi
        if [[ ${#SNAPSHOT_TIME} == 8 && "${SNAPSHOT_TIME}" < "${DAY_MIN}" ]]; then
                zfs destroy "${SNAPSHOT}"
        fi
        if [[ ${#SNAPSHOT_TIME} == 6 && "${SNAPSHOT_TIME}" < "${MONTH_MIN}" ]]; then
                zfs destroy "${SNAPSHOT}"
        fi
done
 
 
 
MONTH_MIN_QA=$(date --date="- 1 month" -u "+%Y%m")
 
zfs list -Hr -o name -t snapshot -r "zpool1/persistent" | grep -E "^zpool1/persistent/[a-zA-Z0-9_-]+-qa@SNAPMONTHLY_[0-9]{6}$" | while read SNAPSHOT_QA; do
        SNAPSHOT_TIME_QA=$(echo "$SNAPSHOT_QA" | grep -oE "[0-9]+$")
        if [[ "${SNAPSHOT_TIME_QA}" < "${MONTH_MIN_QA}" ]]; then
                zfs destroy "${SNAPSHOT_QA}"
        fi
done


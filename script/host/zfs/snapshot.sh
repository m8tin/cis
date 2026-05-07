#!/bin/bash
source /cis/core/base.module.sh



function cleanup() {
    local _MIN_MIN _HOUR_MIN _DAY_MIN _MONTH_MIN
    _MINUTELY_MIN=5
    _HOURLY_MIN=24
    _DAILY_MIN=7
    _MONTHLY_MIN=36
    readonly _MIN_MIN _HOUR_MIN _DAY_MIN _MONTH_MIN

    local _COMPOSITION _CURRENT_HOST _ZFS_BRANCH _ZFS
    ls -d "${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}"*/ | while read -r _COMPOSITION
    do
        _COMPOSITION="${_COMPOSITION%/}"      #Remove tailing '/' if exists
        _COMPOSITION="${_COMPOSITION##*/}"    #Remove leading parts
        _CURRENT_HOST="$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/current-host" 2> /dev/null)"
        _ZFS_BRANCH="$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/zfs-branch" 2> /dev/null)"
        _ZFS_BRANCH="${_ZFS_BRANCH%/}"        #Remove tailing '/' if exists

        if [ "${_CURRENT_HOST}" == "${CIS[HOST]:?"Missing CIS_HOST"}" ]; then
            _ZFS="$(zfs list -H -o name "${_ZFS_BRANCH:-"zpool1/persistent"}/${_COMPOSITION}" 2> /dev/null)"
        else
            _ZFS="$(zfs list -H -o name "${_ZFS_BRANCH:-"zpool1/persistent"}/${_COMPOSITION}-BACKUP" 2> /dev/null)"
        fi

        [ -n "${_ZFS}" ] \
            && printf %b "Cleaning snapshots of: '${_ZFS}'\n" \
            && local _LIST=( $(zfs list -t snap -H -o name -S creation "${_ZFS}" | grep -F '@SNAP' ) )

        # Nothing to do
        [ ${#_LIST[@]} -eq 0 ] && continue

        _COUNT_MINUTELY=0
        _COUNT_HOURLY=0
        _COUNT_DAILY=0
        _COUNT_MONTHLY=0

        for _SNAPSHOT in "${_LIST[@]}"; do
            case "${_SNAPSHOT}" in
                *"@SNAPMINUTELY_"*) 
                    ((_COUNT_MINUTELY++))
                    if [ ${_COUNT_MINUTELY} -gt ${_MINUTELY_MIN} ]; then
                        printf %s "  - remove snapshot (${_COUNT_MINUTELY}): '@${_SNAPSHOT#*@}' ... " >&2
                        zfs destroy "${_SNAPSHOT}" \
                            && printf %b '(done)\n' \
                            || printf %b '(FAIL)\n'
                    fi
                    ;;
                *"@SNAPHOURLY_"*) 
                    ((_COUNT_HOURLY++))
                    if [ ${_COUNT_HOURLY} -gt ${_HOURLY_MIN} ]; then
                        printf %s "  - remove snapshot (${_COUNT_HOURLY}): '@${_SNAPSHOT#*@}' ... " >&2
                        zfs destroy "${_SNAPSHOT}" \
                            && printf %b '(done)\n' \
                            || printf %b '(FAIL)\n'
                    fi
                    ;;
                *"@SNAPDAILY_"*) 
                    ((_COUNT_DAILY++))
                    if [ ${_COUNT_DAILY} -gt ${_DAILY_MIN} ]; then
                        printf %s "  - remove snapshot (${_COUNT_DAILY}): '@${_SNAPSHOT#*@}' ... " >&2
                        zfs destroy "${_SNAPSHOT}" \
                            && printf %b '(done)\n' \
                            || printf %b '(FAIL)\n'
                    fi
                    ;;
                *"@SNAPMONTHLY_"*) 
                    ((_COUNT_MONTHLY++))
                    if [ ${_COUNT_MONTHLY} -gt ${_MONTHLY_MIN} ]; then
                        printf %s "  - remove snapshot (${_COUNT_MONTHLY}): '@${_SNAPSHOT#*@}' ... " >&2
                        zfs destroy "${_SNAPSHOT}" \
                            && printf %b '(done)\n' \
                            || printf %b '(FAIL)\n'
                    fi
                    ;;
            esac
        done
    done
}

function snapshot() {
    local _MINUTE _HOUR _DAY _MONTH
    _MINUTE="$(date -u "+%Y-%m-%d_%H:%M")Z"
    _HOUR="${_MINUTE:0:13}Z"
    _DAY="${_MINUTE:0:10}Z"
    _MONTH="${_MINUTE:0:7}Z"
    readonly _MINUTE _HOUR _DAY _MONTH

    [ ! -d /tmp/locks ] && mkdir /tmp/locks

    local _COMPOSITION _CURRENT_HOST _MODE _ZFS_BRANCH _ZFS
    ls -d "${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}"*/ | while read -r _COMPOSITION
    do
        _COMPOSITION="${_COMPOSITION%/}"      #Remove tailing '/' if exists
        _COMPOSITION="${_COMPOSITION##*/}"    #Remove leading parts
        _CURRENT_HOST="$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/current-host" 2> /dev/null)"
        _MODE="${1:-"$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/snapshot-mode" 2> /dev/null)"}"
        _MODE="${_MODE:-"HOURLY"}"
        _ZFS_BRANCH="$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/zfs-branch" 2> /dev/null)"
        _ZFS_BRANCH="${_ZFS_BRANCH%/}"        #Remove tailing '/' if exists

        [ "${_CURRENT_HOST}" != "${CIS[HOST]:?"Missing CIS_HOST"}" ] \
            && printf %b "ZFS will be skipped, because this host '${CIS[HOST]}' is not running the composition:\n" >&2 \
            && printf %b "  - Composition : ${_COMPOSITION}\n" >&2 \
            && printf %b "  - Current host: ${_CURRENT_HOST}\n" >&2 \
            && continue

        _ZFS="$(zfs list -H -o name "${_ZFS_BRANCH:-"zpool1/persistent"}/${_COMPOSITION}" 2> /dev/null)"
        [ -z "${_ZFS}" ] \
            && printf %b "FAILURE - ZFS not found: ${_ZFS_BRANCH:-"zpool1/persistent"}/${_COMPOSITION}\n" >&2 \
            && continue

        (
            flock -n 9 || return 1

            case "${_MODE:?"Missing MODE"}" in
                MINUTELY) zfs snapshot "${_ZFS}@SNAPMINUTELY_${_MINUTE}" 2> /dev/null \
                              && echo "Snapshot created: '${_ZFS}@SNAPMINUTELY_${_MINUTE}'" >&2 ;& # Forces execution to continue in the next block
                HOURLY)   zfs snapshot "${_ZFS}@SNAPHOURLY_${_HOUR}" 2> /dev/null \
                              && echo "Snapshot created: '${_ZFS}@SNAPHOURLY_${_HOUR}'" >&2 ;&
                DAILY)    zfs snapshot "${_ZFS}@SNAPDAILY_${_DAY}" 2> /dev/null \
                              && echo "Snapshot created: '${_ZFS}@SNAPDAILY_${_DAY}'" >&2 ;&
                MONTHLY)  zfs snapshot "${_ZFS}@SNAPMONTHLY_${_MONTH}" 2> /dev/null \
                              && echo "Snapshot created: '${_ZFS}@SNAPMONTHLY_${_MONTH}'" >&2 ;;
                NONE)     ;;
                *)        echo "No valid mode to create snapshots: '${_MODE}'" >&2 ;;
            esac

        ) 9>>/tmp/locks/snapshot.${_COMPOSITION}.lock
   done
}



# Parameter 1: Only one of these values (MINUTELY, HOURLY, DAILY, MONTHLY, NONE) are allowed, or empty.
base.set MODE "${1}" '^(MINUTELY|HOURLY|DAILY|MONTHLY|NONE)?$' || exit 1

snapshot "${MODE}"
cleanup

exit 0

#!/bin/bash
source /cis/core/base.module.sh
base.loadModule composition
base.loadModule print



function cleanup() {
    local _KEEP_MINUTELY _KEEP_HOURLY _KEEP_DAILY _KEEP_MONTHLY
    _KEEP_MINUTELY=5
    _KEEP_HOURLY=24
    _KEEP_DAILY=7
    _KEEP_MONTHLY=36
    readonly _KEEP_MINUTELY _KEEP_HOURLY _KEEP_DAILY _KEEP_MONTHLY

    local _COMPOSITION _ZFS
    composition.printAll | while read -r _COMPOSITION; do

        _ZFS="$(composition.printZFS "${_COMPOSITION}")"
        [ -n "${_ZFS}" ] \
            && printf -- "Cleaning snapshots of: '%b'\n" "${_ZFS}" \
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
                    if [ ${_COUNT_MINUTELY} -gt ${_KEEP_MINUTELY} ]; then
                        print.message "  - remove snapshot (${_COUNT_MINUTELY}): '@${_SNAPSHOT#*@}' ... "
                        zfs destroy "${_SNAPSHOT}" \
                            && print.done \
                            || print.fail
                    fi
                    ;;
                *"@SNAPHOURLY_"*)
                    ((_COUNT_HOURLY++))
                    if [ ${_COUNT_HOURLY} -gt ${_KEEP_HOURLY} ]; then
                        print.message "  - remove snapshot (${_COUNT_HOURLY}): '@${_SNAPSHOT#*@}' ... "
                        zfs destroy "${_SNAPSHOT}" \
                            && print.done \
                            || print.fail
                    fi
                    ;;
                *"@SNAPDAILY_"*)
                    ((_COUNT_DAILY++))
                    if [ ${_COUNT_DAILY} -gt ${_KEEP_DAILY} ]; then
                        print.message "  - remove snapshot (${_COUNT_DAILY}): '@${_SNAPSHOT#*@}' ... "
                        zfs destroy "${_SNAPSHOT}" \
                            && print.done \
                            || print.fail
                    fi
                    ;;
                *"@SNAPMONTHLY_"*)
                    ((_COUNT_MONTHLY++))
                    if [ ${_COUNT_MONTHLY} -gt ${_KEEP_MONTHLY} ]; then
                        print.message "  - remove snapshot (${_COUNT_MONTHLY}): '@${_SNAPSHOT#*@}' ... "
                        zfs destroy "${_SNAPSHOT}" \
                            && print.done \
                            || print.fail
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

    local _COMPOSITION _MODE _ZFS
    composition.printAllRunningOnThisHost | while read -r _COMPOSITION; do
        _MODE="${1:-"$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/snapshot-mode" 2> /dev/null)"}"
        _MODE="${_MODE:-"HOURLY"}"

        _ZFS="$(composition.printZFS "${_COMPOSITION}")"
        if [ -n "${_ZFS}" ]; then
            (
                flock -n 9 || return 1

                case "${_MODE:?"Missing MODE"}" in
                    MINUTELY) zfs snapshot "${_ZFS}@SNAPMINUTELY_${_MINUTE}" 2> /dev/null \
                                && print.success "Snapshot created: '${_ZFS}@SNAPMINUTELY_${_MINUTE}'" ;& # Forces execution to continue in the next block
                    HOURLY)   zfs snapshot "${_ZFS}@SNAPHOURLY_${_HOUR}" 2> /dev/null \
                                && print.success "Snapshot created: '${_ZFS}@SNAPHOURLY_${_HOUR}'" ;&
                    DAILY)    zfs snapshot "${_ZFS}@SNAPDAILY_${_DAY}" 2> /dev/null \
                                && print.success "Snapshot created: '${_ZFS}@SNAPDAILY_${_DAY}'" ;&
                    MONTHLY)  zfs snapshot "${_ZFS}@SNAPMONTHLY_${_MONTH}" 2> /dev/null \
                                && print.success "Snapshot created: '${_ZFS}@SNAPMONTHLY_${_MONTH}'" ;;
                    NONE)     ;;
                    *)        print.warn "No valid mode to create snapshots: '${_MODE}'" ;;
                esac

            ) 9>>/tmp/locks/snapshot.${_COMPOSITION}.lock
        fi
   done
}



# Parameter 1: Only one of these values (MINUTELY, HOURLY, DAILY, MONTHLY, NONE) are allowed, or empty.
base.set MODE "${1}" '^(MINUTELY|HOURLY|DAILY|MONTHLY|NONE)$' optional

snapshot "${MODE}"
cleanup

exit 0

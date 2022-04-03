#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addToCrontabEveryHour() {
    local _ROOT _MINUTE_VALUE _STRING
    _ROOT="${0%%/core/*}/"                              #Removes longest  matching pattern '/core/*' from the end
    ! [ -z "${2##*[!0-9]*}" ] && _MINUTE_VALUE=$((${2}%60)) # if second parameter is integer then (minute-value % 60) as safe guard
    _STRING="${_MINUTE_VALUE:?"Missing MINUTE_VALUE"} * * * * ${1:?"Missing first parameter COMMAND"} > /dev/null 2>&1"
    readonly _ROOT _MINUTE_VALUE _STRING

    [ "$(id -u)" == "0" ] \
        && crontab -l | grep -qF "${_STRING:?"Missing CRON_STRING"}" \
        && echo "SUCCESS: Entry already is registered to crontab:   ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && echo "${_ROOT:?"Missing ROOT"}" | grep "home" &> /dev/null \
        && echo "SUCCESS: Although the entry will be skipped:       ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && echo "  that is because the current environment is:" \
        && echo "    - ${_ROOT}" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && (crontab -l; \
            echo "# Every hour at ?:${_MINUTE_VALUE:?"Missing MINUTE_VALUE"}:"; \
            echo "${_STRING:?"Missing CRON_STRING"}") | crontab - \
        && crontab -l | grep -qF "${_STRING:?"Missing CRON_STRING"}" \
        && echo "SUCCESS: Entry is registered to crontab now:       ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && return 0

    echo "FAIL: Entry could not be registered to crontab:    ("$(readlink -f ${0})")"
    echo "  - '${_STRING:?"Missing CRON_STRING"}'"
    echo "  - due to an error or insufficient rights."
    return 1
}

# sanitizes all parameters
addToCrontabEveryHour \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

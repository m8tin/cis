#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Folders always ends with an tailing '/'
_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CORE_SCRIPTS="$(dirname ${_SCRIPT:?"Missing SCRIPT"} 2> /dev/null)/"
_CIS_ROOT="$(dirname ${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"} 2> /dev/null)/"

# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addToCrontabEveryHour() {
    local _MINUTE_VALUE _STRING
    ! [ -z "${2##*[!0-9]*}" ] && _MINUTE_VALUE=$((${2}%60)) # if second parameter is integer then (minute-value % 60) as safe guard
    _STRING="${_MINUTE_VALUE:?"Missing MINUTE_VALUE"} * * * * ${1:?"Missing first parameter COMMAND"} > /dev/null 2>&1"
    readonly _MINUTE_VALUE _STRING

    [ "$(id -u)" == "0" ] \
        && crontab -l | grep -qF "${_STRING:?"Missing CRON_STRING"}" \
        && echo "SUCCESS: Entry already is registered to crontab:   ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && echo "${_CIS_ROOT:?"Missing CIS_ROOT"}" | grep -F 'home' &> /dev/null \
        && echo "SUCCESS: Although the entry will be skipped:       ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && echo "  that is because the current environment is:" \
        && echo "    - ${_CIS_ROOT}" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && (crontab -l; \
            echo "# Every hour at ?:${_MINUTE_VALUE:?"Missing MINUTE_VALUE"}:"; \
            echo "${_STRING:?"Missing CRON_STRING"}") | crontab - \
        && crontab -l | grep -qF "${_STRING:?"Missing CRON_STRING"}" \
        && echo "SUCCESS: Entry is registered to crontab now:       ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && return 0

    echo "FAIL: Entry could not be registered to crontab:    ("$(readlink -f ${0})")" >&2
    echo "  - '${_STRING:?"Missing CRON_STRING"}'" >&2
    echo "  - due to an error or insufficient rights." >&2
    return 1
}

# sanitizes all parameters
addToCrontabEveryHour \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0

exit 1

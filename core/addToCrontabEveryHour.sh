#!/bin/bash
source /cis/core/base.module.sh

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addToCrontabEveryHour() {
    ! [ -z "${2##*[!0-9]*}" ] && local -r _MINUTE_VALUE=$((${2}%60)) # if second parameter is integer then (minute-value % 60) as safe guard
    local -r _STRING="${_MINUTE_VALUE:?"Missing MINUTE_VALUE"} * * * * ${1:?"Missing first parameter COMMAND"} > /dev/null 2>&1"

    [ "$(id -u)" == "0" ] \
        && crontab -l | grep -qF "${_STRING:?"Missing CRON_STRING"}" \
        && echo "SUCCESS: Entry already is registered to crontab:   ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && echo "${CIS[ROOT]:?"Missing CIS_ROOT"}" | grep -F 'home' &> /dev/null \
        && echo "SUCCESS: Although the entry will be skipped:       ("$(readlink -f ${0})")" \
        && echo "  - '${_STRING}'" \
        && echo "  that is because the current environment is:" \
        && echo "    - ${CIS[ROOT]}" \
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
declare -A EXPECTED_ARGS=(
    ["--command"]="required: command to add to the crontab.::${REGEX[COMMAND]}"
     ["--minute"]="required: the minute of each hour were the command will be run.::${REGEX[INTEGER]}"
)
base.readArguments "${@}"
addToCrontabEveryHour "${ARGS[command]}" "${ARGS[minute]}" \
    && exit 0

exit 1

#!/bin/bash

#curl:
# --connect-timeout SECONDS  Maximum time allowed for connection
# -k                         Allow connections to SSL sites without certs (H)
# -L                         Follow redirects (H)
# --max-time        SECONDS  Maximum time allowed for the transfer
# -s                         Silent mode. Don't output anything
# --head                     Show head information only
# --no-progress-meter        Clean output for grep

#grep:
# -q                         Quite, no output just status codes
# -F                         Interpret search term as plain text
function checkUrl() {
    local _URL
    _URL="${1:?"URL of site missing"}"
    readonly _URL

    local _RESULT
    _RESULT="$(curl --connect-timeout 10 --max-time 10 --head --no-progress-meter --verbose "${_URL}" 2>&1 | grep -o -E '(expire.*|^HTTP.*200 OK)')"
    readonly _RESULT

    ! echo "${_RESULT}" | grep -q -F '200 OK' \
        && echo "FAIL#Status code 200 not found" \
        && return 1

    local _ENDDATE
    _ENDDATE="$(echo "${_RESULT}" | grep -F 'expire' | cut -d':' -f2-)"
    _ENDDATE="$(date --date="${_ENDDATE}" --utc +%s)"
    readonly _ENDDATE

    ! echo "${_ENDDATE}" | grep -q -E "^[0-9]*$" \
        && echo "FAIL#Unable to parse end date of certificate" \
        && return 1

    local _NOW _REMAINING_DAYS
    _NOW="$(date --date now +%s)"
    _REMAINING_DAYS="$(( (_ENDDATE - _NOW) / 86400 ))"
    readonly _NOW _REMAINING_DAYS

    # less than 30 days remaining => should be warned
    [ "${_REMAINING_DAYS}" -le "30" ] \
        && echo "WARN#Certificate: only ${_REMAINING_DAYS} days left" \
        && return 1

    echo "OK#Certificate: ${_REMAINING_DAYS} days remaining"
    return 0
}

#((curl --connect-timeout 10 --max-time 10 -k -s --head --no-progress-meter "${_URL}" | grep -qF '200 OK') && echo OK) || echo FAIL
checkUrl "${@}" && exit 0 || exit 1

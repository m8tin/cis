#!/bin/bash

function checkPostgresSSLCertificate() {
    local _SERVER
    _SERVER="${1:?"FQDN of server missing"}"
    readonly _SERVER

    local _RESULT
    _RESULT="$(echo | openssl s_client -starttls postgres -connect "${_SERVER}":5432 -servername "${_SERVER}" 2> /dev/null | openssl x509 -noout -enddate | grep -F 'notAfter=' | cut -d'=' -f2)"
    readonly _RESULT

    [ -z "${_RESULT}" ] \
        && echo "FAIL#Unable to get cert's end date from ${_SERVER}:5432" \
        && return 1

    local _ENDDATE
    _ENDDATE="$(date --date="${_RESULT}" --utc +%s)"
    readonly _ENDDATE

    ! echo "${_ENDDATE}" | grep -q -E "^[0-9]*$" \
        && echo "FAIL#Unable to parse end date of certificate" \
        && return 1

    local _NOW _REMAINING_DAYS
    _NOW="$(date --date now +%s)"
    _REMAINING_DAYS="$(( (_ENDDATE - _NOW) / 86400 ))"
    readonly _NOW _REMAINING_DAYS

    [ -z "${_REMAINING_DAYS}" ] \
        && echo "WARN#Only ${_REMAINING_DAYS} days left" \
        && return 1

    echo "OK#${_REMAINING_DAYS} days remaining"
    return 0
}

checkPostgresSSLCertificate "${@}" && exit 0 || exit 1

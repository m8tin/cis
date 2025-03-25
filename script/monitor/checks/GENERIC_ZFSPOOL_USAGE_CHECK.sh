#!/bin/bash

SERVER="${1:?"FQDN of server missing"}"

function testSpace(){
        local _RESULT=$(/sbin/zpool list -H -o capacity,name | /usr/bin/sort)
        local _SPACE_USED=$(echo "${_RESULT}" | /usr/bin/tail -n 1 | /usr/bin/cut -f1)
        local _POOL=$(echo "${_RESULT}" | /usr/bin/tail -n 1 | /usr/bin/cut -f2)

        [ -z "${_SPACE_USED}" ] \
                && echo "FAIL#NO value" \
                && return 0

        [ "${1:?"Missing OK_THRESHOLD"}" -ge "${_SPACE_USED%\%*}" ] \
                && echo "OK#${_SPACE_USED} used ${_POOL}." \
                && return 0

        [ "${2:?"Missing INFO_THRESHOLD"}" -ge "${_SPACE_USED%\%*}" ] \
                && echo "INFO#${_SPACE_USED} already used ${_POOL}." \
                && return 0

        echo "FAIL#${_SPACE_USED} used ${_POOL}!"
        return 0
}

testSpace 80 90

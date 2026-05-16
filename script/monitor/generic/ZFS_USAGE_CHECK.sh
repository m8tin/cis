#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



function testSpace(){
    local _RESULT=$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" 'zpool list -H -o name,capacity')
    local _POOL=$(echo "${_RESULT}" | tail -n 1 | cut -f1)
    local _SPACE_USED=$(echo "${_RESULT}" | tail -n 1 | cut -f2)

    [ -z "${_SPACE_USED}" ] \
        && echo "FAIL#NO value" \
        && return 0

    [ "${2:?"Missing OK_THRESHOLD"}" -ge "${_SPACE_USED%\%*}" ] \
        && echo "OK#${_SPACE_USED} used ${_POOL}." \
        && return 0

    [ "${3:?"Missing INFO_THRESHOLD"}" -ge "${_SPACE_USED%\%*}" ] \
        && echo "INFO#${_SPACE_USED} already used ${_POOL}." \
        && return 0

    echo "FAIL#${_SPACE_USED} used ${_POOL}!"
    return 0
}

base.set REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$'
testSpace "${REMOTE_HOST}" 80 90 && exit 0

exit 1

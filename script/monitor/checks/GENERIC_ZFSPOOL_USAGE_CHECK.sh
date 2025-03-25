#!/bin/bash

_REMOTE_HOST="${1:?"FQDN of server missing"}"
_REMOTE_PORT="${2:-"22"}"
_REMOTE_USER="monitoring"
_SOCKET='~/.ssh/%r@%h:%p'

function checkOrStartSSHMaster() {
    timeout --preserve-status 1 "ssh -O check -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOST}" &> /dev/null \
        && echo "master checked" \
        && return 0

    ssh -O stop -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOST} &> /dev/null
    ssh -o ControlMaster=auto \
        -o ControlPath=${_SOCKET} \
        -o ControlPersist=65 \
        -p ${_REMOTE_PORT} \
        -f ${_REMOTE_USER}@${_REMOTE_HOST} exit &> /dev/null \
        && return 0

    echo "Fail: checkOrStartMaster()"
    return 1
}

function testSpace(){
    checkOrStartSSHMaster \
        || return 1

    local _RESULT="$(ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOST} 'zpool list -H -o capacity,name')"
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

testSpace 80 90 && exit 0

exit 1

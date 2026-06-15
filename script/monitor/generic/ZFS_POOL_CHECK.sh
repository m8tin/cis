#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



function testPool(){
    local _RESPONSE=$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" "zpool status ${2:?"Missing REMOTE_POOL"} | grep -F scrub")
    local _RESULT=$(echo "${_RESPONSE}" | grep -F 'scrub repaired 0B' | grep -F '0 errors')
    _RESULT="${_RESULT#*on}"  #Removes shortest matching pattern '*on' from the begin

    [ -z "${_RESULT}" ] \
        && echo "FAIL#CHECK POOL: ${_ZFS_POOL}" \
        && return 0

    echo "OK#Scrubbed on ${_RESULT}."
    return 0
}

base.set REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$'
base.set REMOTE_POOL "${2:?"Missing name of zpool: e.g. zpool1"}" '^[a-zA-Z0-9_-]+$'
testPool "${REMOTE_HOST}" "${REMOTE_POOL}" && exit 0

exit 1

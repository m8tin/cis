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



declare -A EXPECTED_ARGS=(
     ["--host"]="required: FQDN of the remote host: e.g. host.example.net[:port].::${REGEX[DOMAIN]}(:${REGEX[PORT]})?"
    ["--zpool"]="required: ZFS pool name to test.::[a-zA-Z0-9_-]+"
)
base.readArguments "${@}"
testPool "${ARGS[host]}" "${ARGS[zpool]}" && exit 0

exit 1

#!/bin/bash

_REMOTE_HOST="${1:?"FQDN of server missing: e.g. host.example.net[:port]"}"
_ZFS_POOL="${2:?"Name of zfs pool missing: e.g. zpool1"}"
_REMOTE_HOSTNAME_FQDN="${_REMOTE_HOST%%:*}"            #Removes longest  matching pattern ':*' from the end
_REMOTE_HOSTNAME_SHORT="${_REMOTE_HOSTNAME_FQDN%%.*}"  #Removes longest  matching pattern '.*' from the end
_REMOTE_PORT="${_REMOTE_HOST}:"
_REMOTE_PORT="${_REMOTE_PORT#*:}"                      #Removes shortest matching pattern '*:' from the begin
_REMOTE_PORT="${_REMOTE_PORT%%:*}"                     #Removes longest  matching pattern ':*' from the end
_REMOTE_PORT="${_REMOTE_PORT:-"22"}"
_REMOTE_USER="monitoring"
_SOCKET='~/.ssh/%r@%h:%p'



function checkOrStartSSHMaster() {
    timeout --preserve-status 1 ssh -O check -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 2>&1 | grep -q -F 'Master running' \
        && return 0

    ssh -O stop -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} &> /dev/null
    ssh -o ControlMaster=auto \
        -o ControlPath=${_SOCKET} \
        -o ControlPersist=65 \
        -p ${_REMOTE_PORT} \
        -f ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} exit &> /dev/null \
        && return 0

    echo "FAIL#SSH connection (setup ok?)"
    return 1
}

function testPool(){
    checkOrStartSSHMaster \
        || return 1

    local _RESPONSE="$(ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 'zpool status ${_ZFS_POOL} | grep -F scrub')"
    local _RESULT=$(echo "${_RESPONSE}" | grep -F 'scrub repaired 0B' | grep -F '0 errors')
    _RESULT="${_RESULT#*on}"  #Removes shortest matching pattern '*on' from the begin

    [ -z "${_RESULT}" ] \
        && echo "FAIL#CHECK POOL: ${_ZFS_POOL}" \
        && return 0

    echo "OK#Scrubbed on ${_RESULT}."
    return 0
}

testPool && exit 0

exit 1

#!/bin/bash

_REMOTE_HOST="${1:?"FQDN of server missing: e.g. host.example.net[:port]"}"
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

function testSpace(){
    checkOrStartSSHMaster \
        || return 1

    local _RESULT="$(ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 'zpool list -H -o capacity,name')"
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

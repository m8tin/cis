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

function checkViaHTTP() {
    _STATUS="$(curl -I http://${_REMOTE_HOSTNAME_FQDN} 2>/dev/null | head -n 1 | cut -d$' ' -f2)"
    [ "${_STATUS}" == "200" ] \
        && echo "OK" \
        && return 0

    return 1
}

function checkViaHTTPS() {
    _STATUS="$(curl -k -I https://${_REMOTE_HOSTNAME_FQDN} 2>/dev/null | head -n 1 | cut -d$' ' -f2)"
    [ "${_STATUS}" == "200" ] \
        && echo "OK" \
        && return 0

    return 1
}

#grep:
# -E                         Use regexp, '.*' => any chars between 'Active:' and '(running)', the round brackets are escaped.

#cut:
# -d                         Delimiter, marker where to cut (here ;)
# -f                         Index of column to show (One based, so there is no -f0)
function checkViaSSH() {
    checkOrStartSSHMaster \
        || return 1

    _RESULT=$(ssh -S ${_SOCKET} -p ${_REMOTE_PORT} ${_REMOTE_USER}@${_REMOTE_HOSTNAME_FQDN} 'systemctl status nginx.service' | grep -E 'Active:.*\(running\)' | cut -d';' -f2)
    ! [ -z "${_RESULT}" ] && echo "OK#UPTIME:${_RESULT}" || echo "FAIL"
}

#checkViaHTTP && exit 0
#checkViaHTTPS && exit 0
checkViaSSH && exit 0

exit 1

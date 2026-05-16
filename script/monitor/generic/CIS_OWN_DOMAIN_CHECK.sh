#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



function testDomain(){
    local _RESULT=$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" 'bash /cis/core/printOwnDomain.sh' 2>&1 1>/dev/null)

    [ -z "${_RESULT}" ] \
        && echo "OK" \
        && return 0

    local _DOMAIN=$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" 'bash /cis/core/printOwnDomain.sh' 2>/dev/null)
    echo "WARNING#Overwritten to '${_DOMAIN}'"
    return 0
}

base.set REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$'
testDomain "${REMOTE_HOST}" && exit 0

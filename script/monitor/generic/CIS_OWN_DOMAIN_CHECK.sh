#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



function testDomain() {
    if [ -n "${1}" ]; then
        local _RESULT="$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" '/cis/script/monitor/generic/CIS_OWN_DOMAIN_CHECK.sh' 2>/dev/null)"

        [ -n "${_RESULT}" ] \
            && echo "${_RESULT}" \
            && return 0

        echo "FAIL#check ssh connection"
        return 1
    else
        [ -z "${CIS[DOMAIN]}" ] \
            && echo "FAIL" \
            && return 1

        [ "$(hostname -s).${CIS[DOMAIN]}" == "${CIS[HOST]}" ] \
            && echo "OK" \
            && return 0

        echo "WARNING#Overwritten to '${CIS[DOMAIN]}'"
        return 0
    fi
}

# FQDN of server: e.g. host.example.net[:port]
base.set REMOTE_HOST "${1}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$' optional
testDomain "${REMOTE_HOST}" && exit 0
exit 1

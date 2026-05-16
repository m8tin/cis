#!/bin/bash
source /cis/core/base.module.sh
base.loadModule ssh



#grep:
# -E                         Use regexp, '.*' => any chars between 'Active:' and '(running)', the round brackets are escaped.

#cut:
# -d                         Delimiter, marker where to cut (here ;)
# -f                         Index of column to show (One based, so there is no -f0)
function checkViaSSH() {
    local _RESULT=$(ssh.onHostRun "monitoring@${1:?"Missing REMOTE_HOST"}" 'systemctl status nginx.service' | grep -E 'Active:.*\(running\)' | cut -d';' -f2)
    ! [ -z "${_RESULT}" ] && echo "OK#UPTIME:${_RESULT}" || echo "FAIL"
}

base.set REMOTE_HOST "${1:?"FQDN of server missing: e.g. host.example.net[:port]"}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)+(:[0-9]+)?$'
checkViaSSH "${REMOTE_HOST}" && exit 0

exit 1

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



declare -A EXPECTED_ARGS=(
    ["--host"]="required: FQDN of the remote host: e.g. host.example.net[:port].::${REGEX[DOMAIN]}(:${REGEX[PORT]})?"
)
base.readArguments "${@}"
checkViaSSH "${ARGS[host]}" && exit 0

exit 1

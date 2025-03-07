#!/bin/bash

_SERVER="${1:?"FQDN of server missing"}"
_PORT="${2:-"22"}"
_USER="monitoring"

#grep:
# -F                         Use fixed text, no regexp which has to be interpreted

#cut:
# -d                         Delimiter, marker where to cut (here ;)
# -f                         Index of column to show (One based, so there is no -f0)
_RESULT="$(ssh -p "${_PORT}" "${_USER}"@"${_SERVER}" 'systemctl status nginx.service' | grep -F Active: | grep -F running | cut -d';' -f2)"
! [ -z "${_RESULT}" ] && echo "OK#UPTIME:${_RESULT}" || echo "FAIL"

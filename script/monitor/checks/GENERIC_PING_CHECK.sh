#!/bin/bash

_SERVER="${1:?"FQDN of server missing"}"

# -4                         Use IPv4
# -W            SECONDS      Wait seconds for an answer
# -c            COUNT_VALUE  Count of pings being executed
_RESULT="$(ping -4 -W 1 -c 1 "${_SERVER}" | grep "time=" | cut -d'=' -f4)"
! [ -z "${_RESULT}" ] && echo "OK#RTT: ${_RESULT}" || echo "FAIL#PLEASE USE FALLBACK!"

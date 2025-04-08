#!/bin/bash

_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CIS_ROOT="${_SCRIPT%%/core/*}/"               #Removes longest  matching pattern '/core/*' from the end

[ -d "${_CIS_ROOT}" ] \
    && [ -d "${_CIS_ROOT}definitions/" ] \
    && [ -d "${_CIS_ROOT}states/" ] \
    && echo "${_CIS_ROOT}" \
    && exit 0

echo "FAIL: Unable to detect CIS_ROOT" >&2
exit 1

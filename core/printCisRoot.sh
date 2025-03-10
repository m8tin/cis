#!/bin/bash

_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_SCRIPT_FOLDER="$(dirname ${_SCRIPT:?"Missing SCRIPT"} 2> /dev/null)/"
_CIS_ROOT="$(dirname ${_SCRIPT_FOLDER:?"Missing SCRIPT_FOLDER"} 2> /dev/null)/"

[ -d "${_CIS_ROOT}" ] \
    && [ -d "${_CIS_ROOT}definitions/" ] \
    && [ -d "${_CIS_ROOT}states/" ] \
    && echo "${_CIS_ROOT}" \
    && exit 0

echo "FAIL: Unable to detect CIS_ROOT" >&2
exit 1

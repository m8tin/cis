#!/bin/bash

_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"

# Folders always ends with an tailing '/'
_CIS_ROOT="${_SCRIPT%%/script/check/*}/"               #Removes longest  matching pattern '/script/check/*' from the end
_SCRIPT_PATH="${_CIS_ROOT:?"Missing CIS_ROOT"}script/"
_OWN_DOMAIN="$(${_CIS_ROOT}core/printOwnDomain.sh)"
_OWN_DEFINITIONS="${_CIS_ROOT}definitions/${_OWN_DOMAIN:?"Missing OWN_DOMAIN"}/"



function run_as_root() {
    [ "0" == "$(id -u)" ] \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

function scripts_are_updateable_by_git() {
        git -C "${_SCRIPT_PATH:?"Missing SCRIPT_PATH"}" pull > /dev/null 2>&1 \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

function allChecks() {
    local _CHECK_PATH _MODE_PATH
    _CHECK_PATH="${1:?"allChecks(): Missing first parameter CHECK_PATH"}check/"
    _MODE_PATH="${2:-all}/"
    readonly _CHECK_PATH _MODE_PATH

    echo "  - ${_CHECK_PATH}host/${_MODE_PATH}*.check.sh"
    [ "$(ls -1 ${_CHECK_PATH}host/${_MODE_PATH}*.check.sh 2> /dev/null | grep -cE '.*')" == "0"  ] \
       && echo "  nothing to do" \
       && return 0

    for _CURRENT_CHECK in ${_CHECK_PATH}host/${_MODE_PATH}*.check.sh; do
        _NAME="$(basename ${_CURRENT_CHECK} | cut -d'.' -f1)"
        _CONTEXT="$(echo ${_NAME} | cut -d'_' -f1)"
        _CHECK="$(echo ${_NAME} | cut -d'_' -f2- | tr '_' ' ')"
        _RESULT="$("${_CURRENT_CHECK}" && echo OK || echo FAIL)"
        echo "  ${_CONTEXT^^} ${_CHECK}: ${_RESULT}"
    done
}

echo "PRECONDITION run as root: $(run_as_root)"
echo "PRECONDITION scripts are updateable by git: $(scripts_are_updateable_by_git)"
echo
echo "Check all (common):"
allChecks "${_SCRIPT_PATH}"
echo "Check all (own):"
allChecks "${_OWN_DEFINITIONS}"
echo "Check this host:"
allChecks "${_OWN_DEFINITIONS}" "$(hostname -s)"

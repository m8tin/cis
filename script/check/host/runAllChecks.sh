#!/bin/bash

_OWN_PATH="$(dirname $(readlink -f $0))"

function run_as_root() {
    [ "0" == "$(id -u)" ] \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

function scripts_are_updateable_by_git() {
        git -C "${_OWN_PATH:?"Missing OWN_PATH"}" pull > /dev/null 2>&1 \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

echo "PRECONDITION run as root: $(run_as_root)"
echo "PRECONDITION scripts are updateable by git: $(scripts_are_updateable_by_git)"
echo
echo "Check all:"
for _CURRENT_CHECK in ${_OWN_PATH}/checks/*.check.sh; do
    _NAME="$(basename ${_CURRENT_CHECK} | cut -d'.' -f1)"
    _CONTEXT="$(echo ${_NAME} | cut -d'_' -f1)"
    _CHECK="$(echo ${_NAME} | cut -d'_' -f2- | tr '_' ' ')"
    _RESULT="$("${_CURRENT_CHECK}" && echo OK || echo FAIL)"
    echo "  ${_CONTEXT^^} ${_CHECK}: ${_RESULT}"
done

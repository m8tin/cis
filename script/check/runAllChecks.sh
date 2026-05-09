#!/bin/bash
source /cis/core/base.module.sh



function run_as_root() {
    [ "0" == "$(id -u)" ] \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

function scripts_are_updateable_by_git() {
        git -C "${CIS[SCRIPTDIR]?"Missing CIS_SCRIPTDIR"}" pull > /dev/null 2>&1 \
        && echo OK \
        && return 0

    echo FAIL
    return 1
}

function allChecks() {
    local _CHECK_PATH _MODE_PATH _CHECK_FILES
    _CHECK_PATH="${1:?"allChecks(): Missing first parameter CHECK_PATH"}check/"
    _MODE_PATH="${2:-all}/"
    _CHECK_FILES="${_CHECK_PATH}${_MODE_PATH}"
    readonly _CHECK_PATH _MODE_PATH _CHECK_FILES

    local _CHECK_FOUND="false"
    echo "  - ${_CHECK_FILES}*.check.sh"
    for _CURRENT_CHECK in "${_CHECK_FILES}"*.check.sh; do
        ! [ -x "${_CURRENT_CHECK}" ] \
            && continue
        _CHECK_FOUND="true"
        _NAME="$(basename ${_CURRENT_CHECK} | cut -d'.' -f1)"
        _CONTEXT="$(echo ${_NAME} | cut -d'_' -f1)"
        _CHECK="$(echo ${_NAME} | cut -d'_' -f2- | tr '_' ' ')"
        _RESULT="$("${_CURRENT_CHECK}" && echo OK || echo FAIL)"
        echo "  ${_CONTEXT^^} ${_CHECK}: ${_RESULT}"
    done

    [ "${_CHECK_FOUND}" == "false" ] \
       && echo "  nothing to do" \
       && return 0
}

echo "PRECONDITION run as root: $(run_as_root)"
echo "PRECONDITION scripts are updateable by git: $(scripts_are_updateable_by_git)"
echo
echo "Check all (common):"
allChecks "${CIS[DEFAULTDEFINITIONS]?"Missing CIS_DEFAULTDEFINITIONS"}"
echo "Check all (own):"
allChecks "${CIS[DOMAINDEFINITIONS]?"Missing CIS_DOMAINDEFINITIONS"}"
echo "Check this host:"
allChecks "${CIS[DOMAINDEFINITIONS]}" "$(hostname -s)"

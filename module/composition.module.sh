#!/bin/bash
source /cis/core/base.module.sh



function composition.printAll() {
    local _COMPOSITIONS _CURRENTHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    readonly _COMPOSITIONS _CURRENTHOST_FILE

    local _composition
    for _composition in "${_COMPOSITIONS}"*/; do
        if [ -f "${_composition}${_CURRENTHOST_FILE}" ]; then
            _composition="${_composition%/}"
            _composition="${_composition##*/}"
            echo "${_composition}"
        fi
    done
}

function composition.printAllRunningOnThisHost() {
    local _COMPOSITIONS _CURRENTHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    readonly _COMPOSITIONS _CURRENTHOST_FILE

    local _composition
    for _composition in "${_COMPOSITIONS}"*/; do
        if grep -q -F "${CIS[HOST]}" "${_composition}${_CURRENTHOST_FILE}"; then
            _composition="${_composition%/}"
            _composition="${_composition##*/}"
            echo "${_composition}"
        fi
    done
}

function composition.printAllWhereThisHostSyncs() {
    local _COMPOSITIONS _CURRENTHOST_FILE _SYNCHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    _SYNCHOST_FILE="composition-sync-hosts"
    readonly _COMPOSITIONS _CURRENTHOST_FILE _SYNCHOST_FILE

    local _composition
    for _composition in "${_COMPOSITIONS}"*/; do
        if grep -q -F "${CIS[HOST]}" "${_composition}${_CURRENTHOST_FILE}"; then
            # This host either runs the composition or syncs it.
            continue
        fi
        if grep -q -F "${CIS[HOST]}" "${_composition}${_SYNCHOST_FILE}"; then
            _composition="${_composition%/}"
            _composition="${_composition##*/}"
            echo "${_composition}"
        fi
    done
}

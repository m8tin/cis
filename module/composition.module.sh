#!/bin/bash
source /cis/core/base.module.sh



function composition.isRunningOnThisHost() {
    local _COMPOSITION _COMPOSITIONS _COMPOSITION_PATH _CURRENTHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _COMPOSITION="${1:?"Missing first parameter COMPOSITION"}"
    _COMPOSITION_PATH="${_COMPOSITIONS}${_COMPOSITION}/"
    _CURRENTHOST_FILE="current-host"
    readonly _COMPOSITION _COMPOSITIONS _COMPOSITION_PATH _CURRENTHOST_FILE

    [ -n "${CIS[HOST]}" ] \
         && [ -f "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" ] \
         && head -n 1 -- "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" | grep -q -E -- "^${CIS[HOST]}" \
         && return 0

    return 1
}

function composition.isSyncedByThisHost() {
    local _COMPOSITION _COMPOSITIONS _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _COMPOSITION="${1:?"Missing first parameter COMPOSITION"}"
    _COMPOSITION_PATH="${_COMPOSITIONS}${_COMPOSITION}/"
    _CURRENTHOST_FILE="current-host"
    _SYNCHOSTS_FILE="composition-sync-hosts"
    readonly _COMPOSITION _COMPOSITIONS _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE

    # This host either runs the composition or syncs it.
    # If there is no CURRENTHOST_FILE than the definition is invalid and should not be synced.
    [ -n "${CIS[HOST]}" ] \
         && [ -f "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" ] \
         && head -n 1 -- "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" | grep -q -v -E -- "^${CIS[HOST]}" \
         && grep -q -E -- "^${CIS[HOST]}" "${_COMPOSITION_PATH}${_SYNCHOSTS_FILE}" \
         && return 0

    return 1
}

function composition.printAll() {
    local _COMPOSITIONS _CURRENTHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    readonly _COMPOSITIONS _CURRENTHOST_FILE

    ls -1 "${_COMPOSITIONS}"*/"${_CURRENTHOST_FILE}" | while read -r _CURRENTHOST_FILE_PATH; do
        # Like dirname: removes tailing '/${_CURRENTHOST_FILE}'
        local _COMPOSITION="${_CURRENTHOST_FILE_PATH%/${_CURRENTHOST_FILE}}"
        # Like basename
        echo "${_COMPOSITION##*/}"
    done
}

function composition.printAllRunningOnThisHost() {
    local _COMPOSITIONS _CURRENTHOST_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    readonly _COMPOSITIONS _CURRENTHOST_FILE

    for _COMPOSITION_DIR in "${_COMPOSITIONS}"*; do

        # Like basename
        local _COMPOSITION="${_COMPOSITION_DIR##*/}"

        composition.isRunningOnThisHost "${_COMPOSITION}" \
            && echo "${_COMPOSITION}"
    done
}

function composition.printAllSyncedByThisHost() {
    local _COMPOSITIONS
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    readonly _COMPOSITIONS

    for _COMPOSITION_DIR in "${_COMPOSITIONS}"*; do

        # Like basename
        local _COMPOSITION="${_COMPOSITION_DIR##*/}"

        composition.isSyncedByThisHost "${_COMPOSITION}" \
             && echo "${_COMPOSITION}"
    done
}



# Check if this module was started correctly using source
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Script was executed directly
    echo "FAILURE: you are using this module 'composition.module.sh' in a wrong way."
    echo "    It is intended as a utility library and should not be called directly."
    echo
    echo "Usage: Call this module at the beginning of your script e.g. like this:"
    echo
    echo '    #!/bin/bash'
    echo '    source /cis/core/base.module.sh'
    echo
    echo '    #Loads this module'
    echo '    base.loadModule composition'
    echo
    echo "Now you can use the functions provided by this module inside your script:"
    echo "-------------------------------------------------------------------------"
    declare -F | grep "composition." | cut -d" " -f3
    exit 1
fi

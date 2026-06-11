#!/bin/bash
source /cis/core/base.module.sh



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

    grep -l -F "${CIS[HOST]}" "${_COMPOSITIONS}"*/"${_CURRENTHOST_FILE}" | while read -r _CURRENTHOST_FILE_PATH; do
        # Like dirname: removes tailing '/${_CURRENTHOST_FILE}'
        local _COMPOSITION="${_CURRENTHOST_FILE_PATH%/${_CURRENTHOST_FILE}}"
        # Like basename
        echo "${_COMPOSITION##*/}"
    done
}

function composition.printAllWhereThisHostSyncs() {
    local _COMPOSITIONS _CURRENTHOST_FILE _SYNCHOSTS_FILE
    _COMPOSITIONS="${CIS[DOMAINDEFINITIONS]:?"Missing CIS_DOMAINDEFINITIONS"}compositions/"
    _CURRENTHOST_FILE="current-host"
    _SYNCHOSTS_FILE="composition-sync-hosts"
    readonly _COMPOSITIONS _CURRENTHOST_FILE _SYNCHOSTS_FILE

    grep -lF "${CIS[HOST]}" "${_COMPOSITIONS}"*/"${_SYNCHOSTS_FILE}" | while read -r _SYNCHOSTS_FILE_PATH; do

        # Like dirname: removes tailing '/${_SYNCHOSTS_FILE}'
        local _COMPOSITION="${_SYNCHOSTS_FILE_PATH%/${_SYNCHOSTS_FILE}}"

        # This host either runs the composition or syncs it.
        # If there is no CURRENTHOST_FILE than the definition is invalid and should not be synced.
        [ -f "${_COMPOSITION}/${_CURRENTHOST_FILE}" ] \
             && grep -q -v -F "${CIS[HOST]}" "${_COMPOSITION}/${_CURRENTHOST_FILE}" \
             && echo "${_COMPOSITION##*/}"
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

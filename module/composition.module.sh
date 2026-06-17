#!/bin/bash
source /cis/core/base.module.sh



# composition.isRunningOnThisHost COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function checks if the given composition runs or should run on this host.
# Therefore a file 'current-host' defines the the current host where the composition runs.
function composition.isRunningOnThisHost() {
    local _COMPOSITION _CURRENTHOST_FILE
    _COMPOSITION="${1:?"Missing first parameter COMPOSITION"}"
    _CURRENTHOST_FILE="${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}${_COMPOSITION}/current-host"
    readonly _COMPOSITION _CURRENTHOST_FILE

    ! [ -f "${_CURRENTHOST_FILE}" ] \
         && echo "FAILURE: Missing file current-host for composition: '${_COMPOSITION}'" >&2 \
         && return 1

    [ -n "${CIS[HOST]}" ] \
         && head -n 1 -- "${_CURRENTHOST_FILE}" | grep -q -E -- "^${CIS[HOST]}" \
         && return 0

    return 1
}

# composition.isSyncedByThisHost COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function checks if the given composition is or should be synced to this host.
# Therefore a file 'composition-sync-hosts' defines a list of host, one per line, where the composition should be synced to.
# This host either runs the composition or syncs it.
function composition.isSyncedByThisHost() {
    local _COMPOSITION _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE
    _COMPOSITION="${1:?"Missing first parameter COMPOSITION"}"
    _COMPOSITION_PATH="${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}${_COMPOSITION}/"
    _CURRENTHOST_FILE="current-host"
    _SYNCHOSTS_FILE="composition-sync-hosts"
    readonly _COMPOSITION _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE

    # This host either runs the composition or syncs it.
    # If there is no CURRENTHOST_FILE than the definition is invalid and should not be synced.
    [ -n "${CIS[HOST]}" ] \
         && [ -f "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" ] \
         && head -n 1 -- "${_COMPOSITION_PATH}${_CURRENTHOST_FILE}" | grep -q -v -E -- "^${CIS[HOST]}" \
         && grep -q -E -- "^${CIS[HOST]}" "${_COMPOSITION_PATH}${_SYNCHOSTS_FILE}" \
         && return 0

    return 1
}

# composition.printAll
#
# This function prints a list of all compositions, one per line.
function composition.printAll() {
    local _COMPOSITIONS
    _COMPOSITIONS="${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}"
    readonly _COMPOSITIONS

    local _COMPOSITION_PATH
    ls -d1 "${_COMPOSITIONS}"*/ | while read -r _COMPOSITION_PATH; do
        # Like dirname: removes tailing '/'
        local _COMPOSITION="${_COMPOSITION_PATH%/}"
        # Like basename
        echo "${_COMPOSITION##*/}"
    done
}

# composition.printAllRunningOnThisHost
#
# This function prints a list of all compositions which run or should run on this host, one per line.
#   see also: composition.isRunningOnThisHost
function composition.printAllRunningOnThisHost() {

    composition.printAll | while read -r _COMPOSITION; do
        composition.isRunningOnThisHost "${_COMPOSITION}" \
            && echo "${_COMPOSITION}"
    done
}

# composition.printAllSyncedByThisHost
#
# This function prints a list of all compositions which should be synced to this host, one per line.
#   see also: composition.isSyncedByThisHost
function composition.printAllSyncedByThisHost() {

    composition.printAll | while read -r _COMPOSITION; do
        composition.isSyncedByThisHost "${_COMPOSITION}" \
             && echo "${_COMPOSITION}"
    done
}

# composition.start COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function starts the given composition on this host, provided that this is the defined result.
function composition.start() {
    local _COMPOSITION _COMPOSITION_FILE_BACKUP _COMPOSITION_HOME _COMPOSITION_HOME_FILE
    _COMPOSITION="${1:?"composition.start(): Missing first parameter COMPOSITION"}"
    _COMPOSITION_FILE_BACKUP="/persistent/${_COMPOSITION}/docker-compose.yml"
    _COMPOSITION_HOME_FILE="${CIS[COMPOSITIONS]:?"Missing CIS_COMPOSITIONS"}${_COMPOSITION}/home"

    # The regex should ensure a path starts and ends with a '/' and it should limit the allowed set of characters
    base.set _COMPOSITION_HOME "$(head -n 1 "${_COMPOSITION_HOME_FILE}" 2> /dev/null)" "${REGEX[FULLDIRPATH]}" optional
    readonly _COMPOSITION _COMPOSITION_FILE_BACKUP _COMPOSITION_HOME _COMPOSITION_HOME_FILE

    local _COMPOSITION_FILE
    if [ -n "${_COMPOSITION_HOME}" ]; then
        readonly _COMPOSITION_FILE="${_COMPOSITION_HOME}docker-compose.yml"
        [ ! -f "${_COMPOSITION_FILE}" ] \
            && echo "FAILURE: No composition file found, using the information from file 'home': '${_COMPOSITION_FILE}'" >&2 \
            && return 1
    else
        readonly _COMPOSITION_FILE="${_COMPOSITION_FILE_BACKUP}"
        [ ! -f "${_COMPOSITION_FILE}" ] \
            && echo "FAILURE: No composition file found, falling back to convention: '${_COMPOSITION_FILE}'" >&2 \
            && return 1
    fi

    printf -- "Starting composition: '%s'\n" "${_COMPOSITION}" >&2

    ! composition.isRunningOnThisHost "${_COMPOSITION}" \
        && echo "SKIPPED: This composition does not run on this host" >&2 \
        && return 0

    if [ "$(docker compose version 2> /dev/null)" ]; then
        docker compose --file "${_COMPOSITION_FILE}" start \
            && echo "SUCCESS" >&2 \
            && return 0
    elif [ "$(docker-compose version 2> /dev/null)" ]; then
        docker-compose --file "${_COMPOSITION_FILE}" start \
            && echo "SUCCESS" >&2 \
            && return 0
    fi

    echo "FAILURE: Missing command: 'docker compose'" >&2
    echo "  (maybe you have to install it via: 'apt install docker-compose-v2')" >&2
    return 1
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
    base.explain 'composition' "${1}" "${2}"
    echo
    exit 1
fi

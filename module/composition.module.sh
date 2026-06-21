#!/bin/bash
source /cis/core/base.module.sh
base.loadModule print



# composition.printAll
#
# This function prints a list of all compositions, one per line.
function composition.printAll() {
    local _COMPOSITIONS
    _COMPOSITIONS="${CIS[COMPOSITIONS]:?"composition.printAll(): Missing CIS_COMPOSITIONS"}"
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
#   see also: composition.shouldRunOnThisHost
function composition.printAllRunningOnThisHost() {

    composition.printAll | while read -r _COMPOSITION; do
        composition.shouldRunOnThisHost "${_COMPOSITION}" \
            && echo "${_COMPOSITION}"
    done
}

# composition.printAllSyncedByThisHost
#
# This function prints a list of all compositions which should be synced to this host, one per line.
#   see also: composition.shouldBeSyncedByGivenHost
function composition.printAllSyncedByThisHost() {

    composition.printAll | while read -r _COMPOSITION; do
        composition.shouldBeSyncedByGivenHost "${_COMPOSITION}" "${CIS[HOST]}" \
             && echo "${_COMPOSITION}"
    done
}

# composition.printZFS
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function prints zhe matching ZFS of zje given composition which stores the data or is synced.
function composition.printZFS() {
    local _COMPOSITION _ZFS_BRANCH _ZFS _ZFS_VERIFIED
    _COMPOSITION="${1:?"composition.printZfsOfComposition(): Missing first parameter COMPOSITION"}"
    _ZFS_BRANCH="$(cat "${CIS[COMPOSITIONS]}${_COMPOSITION}/zfs-branch" 2> /dev/null)"
    _ZFS_BRANCH="${_ZFS_BRANCH%/}"        #Remove tailing '/' if exists
    _ZFS="${_ZFS_BRANCH:-"zpool1/persistent"}/${_COMPOSITION}"
    readonly _COMPOSITION _ZFS_BRANCH _ZFS

    if composition.shouldRunOnThisHost "${_COMPOSITION}"; then
        _ZFS_VERIFIED="$(zfs list -H -o name "${_ZFS}" 2> /dev/null)"
    else
        _ZFS_VERIFIED="$(zfs list -H -o name "${_ZFS}-BACKUP" 2> /dev/null)"
    fi

    [ -n "${_ZFS_VERIFIED}" ] \
        && echo "${_ZFS_VERIFIED}" \
        && return 0

    print.failure "ZFS not found:" "${_ZFS}"
    return 1
}

# composition.shouldRunOnThisHost COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function checks if the given composition runs or should run on this host.
# Therefore a file 'current-host' defines the the current host where the composition runs.
function composition.shouldRunOnThisHost() {
    local _COMPOSITION _CURRENTHOST_FILE
    _COMPOSITION="${1:?"composition.shouldRunOnThisHost(): Missing first parameter COMPOSITION"}"
    _CURRENTHOST_FILE="${CIS[COMPOSITIONS]:?"composition.shouldRunOnThisHost(): Missing CIS_COMPOSITIONS"}${_COMPOSITION}/current-host"
    readonly _COMPOSITION _CURRENTHOST_FILE

    ! [ -f "${_CURRENTHOST_FILE}" ] \
         && print.failure "Missing file current-host for composition: '${_COMPOSITION}'" \
         && return 1

    [ -n "${CIS[HOST]}" ] \
         && head -n 1 -- "${_CURRENTHOST_FILE}" | grep -q -E -- "^${CIS[HOST]}" \
         && return 0

    return 1
}

# composition.shouldBeSyncedByGivenHost COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#  - HOST        mandatory: "server.your-domain.net"
#
# This function checks if the given composition is or should be synced to the given host.
# Therefore a file 'composition-sync-hosts' defines a list of host, one per line, where the composition should be synced to.
# The given host either runs the composition or syncs it.
function composition.shouldBeSyncedByGivenHost() {
    local _COMPOSITION _HOST _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE
    _COMPOSITION="${1:?"composition.shouldBeSyncedByGivenHost(): Missing first parameter COMPOSITION"}"
    _HOST="${2:?"composition.shouldBeSyncedByGivenHost(): Missing second parameter HOST"}"
    _COMPOSITION_PATH="${CIS[COMPOSITIONS]:?"composition.shouldBeSyncedByGivenHost(): Missing CIS_COMPOSITIONS"}${_COMPOSITION}/"
    _CURRENTHOST_FILE="${_COMPOSITION_PATH}current-host"
    _SYNCHOSTS_FILE="${_COMPOSITION_PATH}composition-sync-hosts"
    readonly _COMPOSITION _HOST _COMPOSITION_PATH _CURRENTHOST_FILE _SYNCHOSTS_FILE

    # This host either runs the composition or syncs it.
    # If there is no CURRENTHOST_FILE than the definition is invalid and should not be synced.
    [ -f "${_CURRENTHOST_FILE}" ] \
         && head -n 1 -- "${_CURRENTHOST_FILE}" | grep -q -v -E -- "^${_HOST}" \
         && grep -q -E -- "^${_HOST}" "${_SYNCHOSTS_FILE}" \
         && return 0

    return 1
}

# composition.start COMPOSITION
#  - COMPOSITION mandatory: "uptime-kuma-prod"
#
# This function starts the given composition on this host, provided that this is the defined result.
function composition.start() {
    local _COMPOSITION _COMPOSITION_HOME_FILE _COMPOSITION_HOME _COMPOSITION_FILE
    _COMPOSITION="${1:?"composition.start(): Missing first parameter COMPOSITION"}"
    _COMPOSITION_HOME_FILE="${CIS[COMPOSITIONS]:?"composition.start(): Missing CIS_COMPOSITIONS"}${_COMPOSITION}/home"

    # The regex should ensure a path starts and ends with a '/' and it should limit the allowed set of characters
    base.set _COMPOSITION_HOME "$(head -n 1 "${_COMPOSITION_HOME_FILE}" 2> /dev/null)" "${REGEX[DIRPATH]}" optional
    _COMPOSITION_FILE="${_COMPOSITION_HOME}docker-compose.yml"
    readonly _COMPOSITION _COMPOSITION_HOME_FILE _COMPOSITION_HOME _COMPOSITION_FILE

    ! composition.shouldRunOnThisHost "${_COMPOSITION}" \
        && echo "SKIPPED: The composition '${_COMPOSITION}' should not run on this host." >&2 \
        && return 0

    [ -z "${_COMPOSITION_HOME}" ] \
        && print.failure "There was no file 'home' defined." \
        && return 1

    [ ! -f "${_COMPOSITION_FILE}" ] \
        && print.failure "No composition file found: '${_COMPOSITION_FILE}'" \
        && return 1

    printf -- "Starting composition: '%s'\n" "${_COMPOSITION}" >&2

    if [ "$(docker compose version 2> /dev/null)" ]; then
        docker compose --file "${_COMPOSITION_FILE}" start \
            && echo "SUCCESS" >&2 \
            && return 0
    elif [ "$(docker-compose version 2> /dev/null)" ]; then
        docker-compose --file "${_COMPOSITION_FILE}" start \
            && echo "SUCCESS" >&2 \
            && return 0
    fi

    print.failure "Missing command: 'docker compose'" \
        "(maybe you have to install it via: 'apt install docker-compose-v2')"
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

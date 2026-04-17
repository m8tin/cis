#!/bin/bash

# No write permission, but terminal => restart as root using sudo, user jenkins can do this without password
! [ -w "${0}" ] \
    && [ -t 0 ] \
    && sudo "${0}" "${1}" \
    && exit 0

# No write permission and no terminal => restart as root using sudo non-interactive, user jenkins can do this without password
! [ -w "${0}" ] \
    && ! [ -t 0 ] \
    && sudo -n "${0}" "${1}" \
    && exit 0

# Still no write permission => was not called as root
! [ -w "${0}" ] \
    && echo "Host $HOSTNAME: insufficient rights." \
    && exit 1



function update_repositories() {
    local _CIS_ROOT _DEFINITIONS _DOMAIN _MODE _STATES _UPDATE_REPOSITORIES
    _UPDATE_REPOSITORIES="$(readlink -f "${0}" 2> /dev/null)"
    _CIS_ROOT="${_UPDATE_REPOSITORIES%/updateRepositories.sh}/"               #Removes shortest matching pattern '/updateRepositories.sh' from the end
    _MODE="${1:-"--core"}"
    _DOMAIN="$(${_CIS_ROOT:?"Missing CIS_ROOT"}core/printOwnDomain.sh)"
    _DEFINITIONS="${_CIS_ROOT}definitions/${_DOMAIN:?"Missing DOMAIN from file: ${_CIS_ROOT}domainOfHostOwner"}/"
    _STATES="${_CIS_ROOT}states/${_DOMAIN:?"Missing DOMAIN from file: ${_CIS_ROOT}domainOfHostOwner"}/"
    readonly _CIS_ROOT _DEFINITIONS _DOMAIN _MODE _STATES _UPDATE_REPOSITORIES

    [ "${_MODE}" == "--repair" ] \
        && (git -C "${_CIS_ROOT}" reset --hard origin/main; \
            git -C "${_DEFINITIONS}" reset --hard origin/main; \
            git -C "${_STATES}" reset --hard origin/main; \
            echo "Run repairs") \
        && return 0

    [ "${_MODE}" == "--test" ] \
        && git -C "${_CIS_ROOT}" pull \
        && git -C "${_DEFINITIONS}" pull \
        && git -C "${_STATES}" pull \
        && echo "Run in testMode successfully." \
        && return 0

    [ "${_MODE}" == "--scripts" ] \
        && printf "Host $HOSTNAME updating scripts: ${_CIS_ROOT} ... " \
        && (git -C "${_CIS_ROOT}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--definitions" ] \
        && echo "Host ${HOSTNAME} updating definitions: ${_DEFINITIONS} ... " \
        && (git -C "${_DEFINITIONS}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--states" ] \
        && echo "Host ${HOSTNAME} updating states: ${_STATES} ... " \
        && (git -C "${_STATES}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--core" ] \
        && echo "Host ${HOSTNAME} updating core including scripts, definitions and states: ${_STATES} ... " \
        && (git -C "${_CIS_ROOT}" pull &> /dev/null) \
        && (git -C "${_DEFINITIONS}" pull &> /dev/null) \
        && (git -C "${_STATES}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    echo "FAILED: an error occurred during an update."
    return 1
}

function isValid() {
    # printf '%s'
    #  - always treats the contents of ${1} as pure plain text.
    # grep -qE: checks RegExp, but quiet
    printf '%s' "${1}" | grep -qE "${2:?"isValid(): Missing REGEXP"}"
}

function isValidOptional() {
    [ -z "${1}" ] || isValid "${1}" "${2}"
}



# Parameter 1: Only one of these values are allowed (--core, --definitions, --repair, --scripts, --states, --test)
if isValidOptional "${1}" '^(--core|--definitions|--repair|--scripts|--states|--test)$'
then
    update_repositories "${1}" \
        && exit 0
else
    echo "Failure: At least one parameter is invalid" >&2
    exit 1
fi

exit 1

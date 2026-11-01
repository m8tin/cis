#!/bin/bash

# This script is independent from all modules intentionally.
# The reason is that tempoary bugs may prefent the ability to deploy fixes.



# No write permission, but terminal => restart as root using sudo, user jenkins can do this without password
! [ -w "${0}" ] \
    && [ -t 0 ] \
    && sudo "${0}" "${1:-}" \
    && exit 0

# No write permission and no terminal => restart as root using sudo non-interactive, user jenkins can do this without password
! [ -w "${0}" ] \
    && ! [ -t 0 ] \
    && sudo -n "${0}" "${1:-}" \
    && exit 0

# Still no write permission => was not called as root
! [ -w "${0}" ] \
    && echo "Host ${CIS[HOST]:?"Missing HOST"}: insufficient rights." \
    && exit 1



function update_repositories() {
    local -r _MODE="${1:?"update_repositories(): Missing first parameter MODE"}"

    local -r _CIS_ROOT="$(realpath ${0%/*})/"
    # Take OVERRIDING_DOMAIN_FILE without empty lines and comments, then take the first line without leading spaces
    local -r _OVERRIDE_DOMAIN_FILE="${_CIS_ROOT:?"Missing CIS_ROOT"}overrideOwnDomain"
    local -r _OVERRIDE_DOMAIN="$(grep -vE '^[[:space:]]*$|^[[:space:]]*#' "${_OVERRIDE_DOMAIN_FILE}" 2> /dev/null | head -n 1 | xargs)"
    # There has to be one dot at least in BOOT_DOMAIN.
    if [ -n "${_OVERRIDE_DOMAIN}" ] && [ -d "${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_OVERRIDE_DOMAIN}" ]; then
        local -r _DOMAIN="${_OVERRIDE_DOMAIN}"
    else
        # There has to be one dot at least in BOOT_DOMAIN.
        local -r _DOMAIN="$(hostname -b | grep -F '.' | cut -d. -f2-)"
    fi
    local -r _CIS_DOMAINDEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}/"
    local -r _CIS_DOMAINSTATES="${_CIS_ROOT:?"Missing CIS_ROOT"}states/${_DOMAIN:?"Missing DOMAIN"}/"


    [ "${_MODE}" == "--repair" ] \
        && (git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" reset --hard origin/main; \
            git -C "${_CIS_DOMAINDEFINITIONS:?"Missing DEFINITIONS"}" reset --hard origin/main; \
            umask 0027; git -C "${_CIS_DOMAINSTATES:?"Missing STATES"}" reset --hard origin/main; \
            echo "Run repairs") \
        && return 0

    [ "${_MODE}" == "--test" ] \
        && git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" pull \
        && git -C "${_CIS_DOMAINDEFINITIONS:?"Missing DEFINITIONS"}" pull \
        && (umask 0027; git -C "${_CIS_DOMAINSTATES:?"Missing STATES"}" pull) \
        && echo "Run in testMode successfully." \
        && return 0

    [ "${_MODE}" == "--scripts" ] \
        && printf -- "Host $HOSTNAME updating scripts: ${_CIS_ROOT:?"Missing CIS_ROOT"} ... " \
        && (git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--definitions" ] \
        && printf -- "Host ${HOSTNAME} updating definitions: ${_CIS_DOMAINDEFINITIONS:?"Missing DEFINITIONS"} ... " \
        && (git -C "${_CIS_DOMAINDEFINITIONS:?"Missing DEFINITIONS"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--states" ] \
        && printf -- "Host ${HOSTNAME} updating states: ${_CIS_DOMAINSTATES:?"Missing STATES"} ... " \
        && (umask 0027; git -C "${_CIS_DOMAINSTATES:?"Missing STATES"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--core" ] \
        && printf -- "Host ${HOSTNAME} updating core including scripts, definitions and states ... " \
        && (git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" pull &> /dev/null) \
        && (git -C "${_CIS_DOMAINDEFINITIONS:?"Missing DEFINITIONS"}" pull &> /dev/null) \
        && (umask 0027; git -C "${_CIS_DOMAINSTATES:?"Missing STATES"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    echo "FAILED: an error occurred during an update."
    return 1
}



# Parameter 1: Only one of these values are allowed, or empty (--core, --definitions, --repair, --scripts, --states, --test)?
update_repositories "${1:-"--core"}" \
    && exit 0

exit 1

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
    local _ROOT _DEFINITIONS _DOMAIN _MODE _STATES _UPDATE_REPOSITORIES
    _UPDATE_REPOSITORIES="$(readlink -f "${0}" 2> /dev/null)"
    _MODE="${1:-"all"}"
    _ROOT="$(dirname ${_UPDATE_REPOSITORIES:?"Missing UPDATE_REPOSITORIES"} 2> /dev/null || echo "/iss")/"
    _DOMAIN="$(cat ${_ROOT:?"Missing ROOT"}domainOfHostOwner)"
    _DEFINITIONS="${_ROOT}definitions/${_DOMAIN:?"Missing DOMAIN from file: ${_ROOT}domainOfHostOwner"}/"
    _STATES="${_ROOT}states/${_DOMAIN:?"Missing DOMAIN from file: ${_ROOT}domainOfHostOwner"}/"
    readonly _ROOT _DEFINITIONS _DOMAIN _MODE _STATES _UPDATE_REPOSITORIES

    [ "${_MODE}" == "--repair" ] \
        && (git -C "${_ROOT}" reset --hard origin/master; \
            git -C "${_DEFINITIONS}" reset --hard origin/master; \
            git -C "${_STATES}" reset --hard origin/master; \
            echo "Run repairs") \
        && return 0

    [ "${_MODE}" == "--test" ] \
        && git -C "${_ROOT}" pull \
        && git -C "${_DEFINITIONS}" pull \
        && git -C "${_STATES}" pull \
        && echo "Run in testMode successfully." \
        && return 0

    [ "${_MODE}" == "--scripts" ] \
        && echo "Host $HOSTNAME updating scripts: ${_ROOT} ..." \
        && (git -C "${_ROOT}" pull &> /dev/null &) \
        && return 0

    [ "${_MODE}" == "--definitions" ] \
        && echo "Host ${HOSTNAME} updating definitions: ${_DEFINITIONS} ..." \
        && (git -C "${_DEFINITIONS}" pull &> /dev/null &) \
        && return 0

    [ "${_MODE}" == "--states" ] \
        && echo "Host ${HOSTNAME} updating states: ${_STATES} ..." \
        && (git -C "${_STATES}" pull &> /dev/null &) \
        && return 0

    echo "Host ${HOSTNAME} updating ${_MODE}:" \
        && echo "  - ${_ROOT}" \
        && echo "  - ${_DEFINITIONS}" \
        && echo "  - ${_STATES}"
    git -C "${_ROOT}" pull &> /dev/null
    git -C "${_DEFINITIONS}" pull &> /dev/null
    git -C "${_STATES}" pull &> /dev/null
}

# sanitizes all parameters
update_repositories \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

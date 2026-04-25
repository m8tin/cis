#!/bin/bash
source /cis/core/base.module.sh



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
    && echo "Host ${CIS[HOST]:?"Missing HOST"}: insufficient rights." \
    && exit 1



function update_repositories() {
    local _MODE="${1:-"--core"}"
    readonly _MODE

    [ "${_MODE}" == "--repair" ] \
        && (git -C "${CIS[ROOT]:?"Missing CISROOT"}" reset --hard origin/main; \
            git -C "${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"}" reset --hard origin/main; \
            git -C "${CIS[DOMAINSTATES]:?"Missing STATES"}" reset --hard origin/main; \
            echo "Run repairs") \
        && return 0

    [ "${_MODE}" == "--test" ] \
        && git -C "${CIS[ROOT]:?"Missing CISROOT"}" pull \
        && git -C "${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"}" pull \
        && git -C "${CIS[DOMAINSTATES]:?"Missing STATES"}" pull \
        && echo "Run in testMode successfully." \
        && return 0

    [ "${_MODE}" == "--scripts" ] \
        && printf "Host $HOSTNAME updating scripts: ${CIS[ROOT]:?"Missing CISROOT"} ... " \
        && (git -C "${CIS[ROOT]:?"Missing CISROOT"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--definitions" ] \
        && printf "Host ${HOSTNAME} updating definitions: ${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"} ... " \
        && (git -C "${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--states" ] \
        && printf "Host ${HOSTNAME} updating states: ${CIS[DOMAINSTATES]:?"Missing STATES"} ... " \
        && (git -C "${CIS[DOMAINSTATES]:?"Missing STATES"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    [ "${_MODE}" == "--core" ] \
        && printf "Host ${HOSTNAME} updating core including scripts, definitions and states ... " \
        && (git -C "${CIS[ROOT]:?"Missing CISROOT"}" pull &> /dev/null) \
        && (git -C "${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"}" pull &> /dev/null) \
        && (git -C "${CIS[DOMAINSTATES]:?"Missing STATES"}" pull &> /dev/null) \
        && echo "(done)" \
        && return 0

    echo "FAILED: an error occurred during an update."
    return 1
}



# Parameter 1: Only one of these values are allowed, or empty (--core, --definitions, --repair, --scripts, --states, --test)?
base.set MODE "${1}" '^(--core|--definitions|--repair|--scripts|--states|--test)?$' || exit 1
update_repositories "${MODE}" \
    && exit 0

exit 1

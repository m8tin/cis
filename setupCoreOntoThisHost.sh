#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" "${1}" \
    && exit 0




function checkPathsAreAvaiable() {
    grep --version &> /dev/null \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /usr/local/sbin)" -ge 1 ] \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /usr/local/bin)" -ge 1 ] \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /usr/sbin)" -ge 1 ] \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /usr/bin)" -ge 1 ] \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /sbin)" -ge 3 ] \
        && [ "$(echo ${PATH} | tr ':' '\n' | grep -c /bin)" -ge 3 ] \
        && return 0

    echo "Content of variable PATH is not available."
    return 1
}

function checkGitIsAvailable() {
    git --version &> /dev/null \
        && return 0

    apt update &> /dev/null
    echo "Git seams to be unavailable. Please install it using 'apt install git'."
    return 1
}

function checkPreconditions() {
    local _ROOT _DOMAIN
    _ROOT="${1:?"Missing parameter ROOT"}"
    _DOMAIN="${2}" # Optional parameter DOMAIN
    readonly _ROOT _DOMAIN

    ! [ -z "${_DOMAIN}" ] \
        && [ "$(hostname -d)" != "${_DOMAIN}" ] \
        && echo \
        && echo "WARNING: system-domain DOES NOT MATCH domainOfHostOwner: '$(hostname -d)' != '${_DOMAIN}'" \
        && echo

    # Given domain verfügbar (nicht leer)
    ! [ -z "${_DOMAIN}" ] \
        && checkPathsAreAvaiable \
        && checkGitIsAvailable \
        && git -C "${_ROOT}" pull &> /dev/null \
        && return 0

    echo
    echo "The preconditions were not met."

    # Given domain verfügbar (nicht leer) => Text unten unnötig
    ! [ -z "${_DOMAIN}" ] \
        && return 1

    echo
    echo "The needed domain provided by the owner of this host is not available."
    echo "You have to configure the host correctly, e.g.:"
    echo "    hostnamectl set-hostname 'SHORT_HOSTNAME.DOMAIN.TLD'"
    echo
    echo "If you are root you can specify the domain information as a parameter, e.g.:"
    echo "    ${0} DOMAIN.TLD"
    echo "Then the specified domain is appended to the current short hostname: '$(hostname -s)'"

    return 1
}

function getOrSetDomain() {
    local _ROOT _DOMAIN_FILE _GIVEN_DOMAIN
    _ROOT="${1:?"Missing parameter ROOT"}"
    _DOMAIN_FILE="${_ROOT:?"Missing ROOT"}domainOfHostOwner"
    _GIVEN_DOMAIN="${2}" # Optional parameter DOMAIN
    readonly _ROOT _DOMAIN_FILE _GIVEN_DOMAIN

    # Wenn DOMAIN_FILE enhält lesbare Daten
    grep '[^[:space:]]' "${_DOMAIN_FILE:?"Missing DOMAIN_FILE"}" &> /dev/null \
        && cat "${_DOMAIN_FILE}" \
        && return 0

    # Der boot-hostname muss mindestens einen Punkt enthalten, dann wird die hintere Hälfte als Domain genommen
    hostname -b | grep "\." | cut -d. -f2- > "${_DOMAIN_FILE}"
    grep '[^[:space:]]' "${_DOMAIN_FILE}" &> /dev/null \
        && cat "${_DOMAIN_FILE}" \
        && return 0

    # Given domain is set (nicht leer)
    ! [ -z "${_GIVEN_DOMAIN}" ] \
        && [ "$(id -u)" == "0" ] \
        && hostnamectl set-hostname "$(hostname -s).${_GIVEN_DOMAIN}" \
        && hostname -b | grep "\." | cut -d. -f2- > "${_DOMAIN_FILE}" \
        && grep '[^[:space:]]' "${_DOMAIN_FILE}" &> /dev/null \
        && cat "${_DOMAIN_FILE}" \
        && return 0

    return 1
}

function getRemoteRepositoryPath() {
    local _ROOT
    _ROOT="${1:?"Missing parameter ROOT"}"
    readonly _ROOT

    _RESULT="$(git -C "${_ROOT:?"Missing ROOT"}" remote show origin | grep -i 'fetch' | xargs -n 1 | grep -i 'ssh://')"
    _RESULT="${_RESULT%/*}"                        #Removes shortest matching pattern '/*' from the end
    ! [ -z "${_RESULT}" ] \
        && echo "${_RESULT}" \
        && return 0

    return 1
}

function addDefinition(){
    local _ROOT _CORE_SCRIPTS _DEFINITIONS _REPOSITORY
    _DEFINITIONS="${1:?"Missing parameter DEFINITIONS"}"
    _REPOSITORY="${2:?"Missing parameter REPOSITORY"}"
    _ROOT="${_DEFINITIONS%%/definitions/*}/"   #Removes longest  matching pattern '/definitions/*' from the end
    _CORE_SCRIPTS="${_ROOT:?"Missing ROOT"}core/"
    readonly _ROOT _CORE_SCRIPTS _DEFINITIONS _REPOSITORY
    [ "$(id -u)" == "0" ] \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_DEFINITIONS}" "${_REPOSITORY}" readonly \
        && echo "  - definitions are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_DEFINITIONS}" "${_REPOSITORY}" writable \
        && echo "  - definitions are usable, as working copy." \
        && return 0

    return 1
}

function addState() {
    local _ROOT _CORE_SCRIPTS _STATES _REPOSITORY
    _STATES="${1:?"Missing parameter STATES"}"
    _REPOSITORY="${2:?"Missing parameter REPOSITORY"}"
    _ROOT="${_STATES%%/states/*}/"             #Removes longest  matching pattern '/states/*' from the end
    _CORE_SCRIPTS="${_ROOT:?"Missing ROOT"}core/"
    readonly _ROOT _CORE_SCRIPTS _STATES _REPOSITORY

    [ "$(id -u)" == "0" ] \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_STATES}" "${_REPOSITORY}" writable \
        && echo "  - states are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_STATES}" "${_REPOSITORY}" writable \
        && echo "  - states are usable, as working copy." \
        && return 0

    return 1
}

function setupCoreFunctionality() {
    local _ROOT _CORE_SCRIPTS _DEFINITIONS _MINUTE_FROM_OWN_IP _SETUP
    _DEFINITIONS="${1:?"Missing DEFINITIONS: 'ROOT/definitions/DOMAIN'"}"
    _ROOT="${_DEFINITIONS%%/definitions/*}/"   #Removes longest  matching pattern '/definitions/*' from the end
    _CORE_SCRIPTS="${_ROOT:?"Missing ROOT"}core/"
    _MINUTE_FROM_OWN_IP="$(hostname -I | xargs -n 1 | grep -F . | head -n 1 | cut -d. -f4 || echo 0)" #uses last value from first own ipv4 or 0 as minute value
    _SETUP="${2:?"Missing SETUP"}"
    readonly _ROOT _CORE_SCRIPTS _DEFINITIONS _MINUTE_FROM_OWN_IP _SETUP

    [ "$(id -u)" != "0" ] \
        && echo "Configuration of host skipped because of insufficient rights." \
        && return 1

    [ "$(id -u)" == "0" ] \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${_DEFINITIONS}" root \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addNormalUser.sh" jenkins \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${_DEFINITIONS}" jenkins \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${_DEFINITIONS}" /etc/sudoers.d/allow-jenkins-updateRepositories \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addToCrontabEveryHour.sh" "${_SETUP}" "${_MINUTE_FROM_OWN_IP}" \
        && return 0

    return 1
}

function setup() {
    local _ROOT _DEFINITIONS _DEFINITIONS_REPOSITORY _DOMAIN _REPOSITORY_PATH _SETUP _STATES _STATES_REPOSITORY
    _SETUP="$(readlink -f "${0}" 2> /dev/null)"
    _ROOT="$(dirname ${_SETUP:?"Missing SETUP"} 2> /dev/null || echo "/iss")/"
    _DOMAIN="$(getOrSetDomain "${_ROOT:?"Missing ROOT"}" "${1}")"
    _REPOSITORY_PATH="$(getRemoteRepositoryPath "${_ROOT:?"Missing ROOT"}")"

    ! checkPreconditions "${_ROOT:?"Missing ROOT"}" "${_DOMAIN}" \
        && return 1

    _DEFINITIONS="${_ROOT:?"Missing ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}"
    _DEFINITIONS_REPOSITORY="${_REPOSITORY_PATH:?"Missing REPOSITORY_PATH"}/iss-definition-${_DOMAIN:?"Missing DOMAIN"}.git"
    _STATES="${_ROOT:?"Missing ROOT"}states/${_DOMAIN:?"Missing DOMAIN"}"
    _STATES_REPOSITORY="${_REPOSITORY_PATH:?"Missing REPOSITORY_PATH"}/iss-state-${_DOMAIN:?"Missing DOMAIN"}.git"
    readonly _ROOT _DEFINITIONS _DEFINITIONS_REPOSITORY _DOMAIN _REPOSITORY_PATH _SETUP _STATES _STATES_REPOSITORY

    echo \
        && echo "Running setup using repositories of: '${_REPOSITORY_PATH:?"Missing REPOSITORY_PATH"}' ..." \
        && echo \
        && addDefinition "${_DEFINITIONS:?"Missing DEFINITIONS"}" "${_DEFINITIONS_REPOSITORY:?"Missing DEFINITIONS_REPOSITORY"}" \
        && echo \
        && addState "${_STATES:?"Missing STATES"}" "${_STATES_REPOSITORY:?"Missing STATES_REPOSITORY"}" \
        && echo \
        && echo "Using definitions: '${_DEFINITIONS:?"Missing DEFINITIONS"}' ..." \
        && setupCoreFunctionality "${_DEFINITIONS:?"Missing DEFINITIONS"}" "${_SETUP:?"Missing SETUP"}" \
        && return 0

    echo "FAIL: setup is incomplete:                        ("$(readlink -f ${0})")"
    echo "  - due to an error or insufficient rights."
    return 1
}

# sanitizes all parameters
setup \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

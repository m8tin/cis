#!/bin/bash

[ "$(id -u)" != "0" ] \
    && sudo "${0}" "${1}" \
    && exit 0



# Folders always ends with an tailing '/'
_SETUP="$(readlink -f "${0}" 2> /dev/null)"
_CIS_ROOT="${_SETUP%/setupCoreOntoThisHost.sh}/"             #Removes shortest matching pattern '/setupCoreOntoThisHost.sh' from the end
_CORE_SCRIPTS="${_CIS_ROOT:?"Missing CIS_ROOT"}core/"



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
    local _DOMAIN
    _DOMAIN="${1}" # Optional parameter DOMAIN
    readonly _DOMAIN

    ! [ -z "${_DOMAIN}" ] \
        && [ "$(hostname -d)" != "${_DOMAIN}" ] \
        && echo \
        && echo "WARNING: system-domain DOES NOT MATCH overrideOwnDomain: '$(hostname -d)' != '${_DOMAIN}'" \
        && echo

    # Given domain verfügbar (nicht leer)
    ! [ -z "${_DOMAIN}" ] \
        && checkPathsAreAvaiable \
        && checkGitIsAvailable \
        && git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" pull &> /dev/null \
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
    local _CURRENT_DOMAIN _GIVEN_DOMAIN _OVERRIDE_DOMAIN_FILE
    _CURRENT_DOMAIN="$("${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}printOwnDomain.sh")"
    _GIVEN_DOMAIN="${1}" # Optional parameter DOMAIN
    _OVERRIDE_DOMAIN_FILE="${_CIS_ROOT:?"Missing CIS_ROOT"}overrideOwnDomain"
    readonly _CURRENT_DOMAIN _GIVEN_DOMAIN _OVERRIDE_DOMAIN_FILE

    ! [ -z "${_CURRENT_DOMAIN}" ] \
        && [ -z "${_GIVEN_DOMAIN}" ] \
        && echo "${_CURRENT_DOMAIN}" \
        && return 0

    ! [ -z "${_CURRENT_DOMAIN}" ] \
        && [ "${_CURRENT_DOMAIN}" == "${_GIVEN_DOMAIN}" ] \
        && echo "${_CURRENT_DOMAIN}" \
        && return 0

    # If there is a given domain it will be set or it will override the current one
    [ -z "${_CURRENT_DOMAIN}" ] \
        && ! [ -z "${_GIVEN_DOMAIN}" ] \
        && [ "$(id -u)" == "0" ] \
        && echo "Setting hostname to: $(hostname -s).${_GIVEN_DOMAIN}" >&2 \
        && hostnamectl set-hostname "$(hostname -s).${_GIVEN_DOMAIN}" \
        && echo "${_GIVEN_DOMAIN}" \
        && return 0

    ! [ -z "${_GIVEN_DOMAIN}" ] \
        && echo "Overwriting domain to: ${_GIVEN_DOMAIN}" >&2 \
        && echo "${_GIVEN_DOMAIN}" > "${_OVERRIDE_DOMAIN_FILE}" \
        && echo "${_GIVEN_DOMAIN}" \
        && return 0

    return 1
}

function getRemoteRepositoryPath() {
    _REPOSITORY="$(git -C "${_CIS_ROOT:?"Missing CIS_ROOT"}" config --get remote.origin.url 2> /dev/null | grep -i 'git@')"
    _PATH="${_REPOSITORY%/*}"                        #Removes shortest matching pattern '/*' from the end
    ! [ -z "${_PATH}" ] \
        && echo "${_PATH}/" \
        && return 0

    return 1
}

function addDefinition(){
    local _DEFINITIONS _REPOSITORY
    _DEFINITIONS="${1:?"Missing first parameter DEFINITIONS"}"
    _REPOSITORY="$(getRemoteRepositoryPath)cis-definition-${2:?"Missing second parameter DOMAIN"}.git"
    readonly _DEFINITIONS _REPOSITORY

    [ "$(id -u)" == "0" ] \
        && echo "Running setup as 'root' trying to add definition repository:" \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_DEFINITIONS}" readonly "${_REPOSITORY}" \
        && echo "  - definitions are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && echo "Running setup as 'user' trying to add definition repository:" \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_DEFINITIONS}" writable "${_REPOSITORY}" \
        && echo "  - definitions are usable, as working copy." \
        && return 0

    return 1
}

function addState() {
    local _STATES _REPOSITORY
    _STATES="${1:?"Missing first parameter STATES"}"
    _REPOSITORY="$(getRemoteRepositoryPath)cis-state-${2:?"Missing second parameter DOMAIN"}.git"
    readonly _STATES _REPOSITORY

    [ "$(id -u)" == "0" ] \
        && echo "Running setup as 'root' trying to add state repository:" \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_STATES}" writable "${_REPOSITORY}" \
        && echo "  - states are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && echo "Running setup as 'user' trying to add state repository:" \
        && echo \
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${_STATES}" writable "${_REPOSITORY}" \
        && echo "  - states are usable, as working copy." \
        && return 0

    return 1
}

function setupCoreFunctionality() {
    local _DEFINITIONS _MINUTE_FROM_OWN_IP
    _DEFINITIONS="${1:?"Missing DEFINITIONS: 'ROOT/definitions/DOMAIN'"}"
    _MINUTE_FROM_OWN_IP="$(hostname -I | xargs -n 1 | grep -F '.' | head -n 1 | cut -d. -f4 || echo 0)" #uses last value from first own ipv4 or 0 as minute value
    readonly _DEFINITIONS _MINUTE_FROM_OWN_IP

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
        && "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}addToCrontabEveryHour.sh" "${_SETUP:?"Missing SETUP"}" "${_MINUTE_FROM_OWN_IP}" \
        && return 0

    return 1
}

function setup() {
    local _DEFINITIONS _DOMAIN _STATES
    _DOMAIN="$(getOrSetDomain "${1}")"

    ! checkPreconditions "${_DOMAIN}" \
        && return 1

    _DEFINITIONS="${_CIS_ROOT:?"Missing CIS_ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}"
    _STATES="${_CIS_ROOT:?"Missing CIS_ROOT"}states/${_DOMAIN:?"Missing DOMAIN"}"
    readonly _DEFINITIONS _DOMAIN _STATES

    echo \
        && addDefinition "${_DEFINITIONS:?"Missing DEFINITIONS"}" "${_DOMAIN:?"Missing DOMAIN"}" \
        && echo \
        && addState "${_STATES:?"Missing STATES"}" "${_DOMAIN:?"Missing DOMAIN"}" \
        && echo \
        && echo "Using definitions: '${_DEFINITIONS:?"Missing DEFINITIONS"}' ..." \
        && setupCoreFunctionality "${_DEFINITIONS:?"Missing DEFINITIONS"}" \
        && return 0

    echo "FAIL: setup is incomplete:                         ("$(readlink -f ${0})")" >&2
    echo "  - due to an error or insufficient rights." >&2
    return 1
}

# sanitizes all parameters
setup "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0

exit 1

#!/bin/bash
source ${CUSTOM_CIS_ROOT:-/}./cis/core/base.module.sh



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
        && git -C "${CIS[ROOT]:?"Missing CIS_ROOT"}" pull &> /dev/null \
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
    _CURRENT_DOMAIN="${CIS[DOMAIN]:?"Missing CIS_DOMAIN"}"
    _GIVEN_DOMAIN="${1}" # Optional parameter DOMAIN
    _OVERRIDE_DOMAIN_FILE="${CIS[ROOT]:?"Missing CIS_ROOT"}overrideOwnDomain"
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
    local _REPOSITORY="$(git -C "${CIS[ROOT]:?"Missing CIS_ROOT"}" config --get remote.origin.url 2> /dev/null | grep -i 'git@')"
    local _PATH="${_REPOSITORY%/*}"                        #Removes shortest matching pattern '/*' from the end
    readonly _REPOSITORY _PATH

    ! [ -z "${_PATH}" ] \
        && echo "${_PATH}/" \
        && return 0

    return 1
}

function addDefinition(){
    local _REPOSITORY
    _REPOSITORY="$(getRemoteRepositoryPath)cis-definition-${CIS[DOMAIN]}.git"
    readonly _REPOSITORY

    [ "$(id -u)" == "0" ] \
        && echo \
        && echo "Running setup as 'root' trying to add definition repository:" \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${CIS[DOMAINDEFINITIONS]}" readonly "${_REPOSITORY}" \
        && echo "  - definitions are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && echo \
        && echo "Running setup as 'user' trying to add definition repository:" \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${CIS[DOMAINDEFINITIONS]}" writable "${_REPOSITORY}" \
        && echo "  - definitions are usable, as working copy." \
        && return 0

    return 1
}

function addState() {
    local _REPOSITORY
    _REPOSITORY="$(getRemoteRepositoryPath)cis-state-${CIS[DOMAIN]}.git"
    readonly _REPOSITORY

    [ "$(id -u)" == "0" ] \
        && echo \
        && echo "Running setup as 'root' trying to add state repository:" \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${CIS[DOMAINSTATES]}" writable "${_REPOSITORY}" \
        && echo "  - states are usable for this host." \
        && return 0

    [ "$(id -u)" != "0" ] \
        && echo \
        && echo "Running setup as 'user' trying to add state repository:" \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addAndCheckGitRepository.sh" "${CIS[DOMAINSTATES]}" writable "${_REPOSITORY}" \
        && echo "  - states are usable, as working copy." \
        && return 0

    return 1
}

function setupCoreFunctionality() {
    local _MINUTE_FROM_OWN_IP
    _MINUTE_FROM_OWN_IP="$(hostname -I | xargs -n 1 | grep -F '.' | head -n 1 | cut -d. -f4 || echo 0)" #uses last value from first own ipv4 or 0 as minute value
    readonly _MINUTE_FROM_OWN_IP

    [ "$(id -u)" != "0" ] \
        && echo \
        && echo "Configuration of host skipped because of insufficient rights." \
        && return 1

    [ "$(id -u)" == "0" ] \
        && echo \
        && echo "Using definitions: '${CIS[DOMAINDEFINITIONS]:?"Missing DEFINITIONS"}' ..." \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${CIS[DOMAINDEFINITIONS]}" root \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${CIS[DOMAINDEFINITIONS]}" /etc/adduser.conf \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addNormalUser.sh" jenkins \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" "${CIS[DOMAINDEFINITIONS]}" jenkins \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${CIS[DOMAINDEFINITIONS]}" /etc/sudoers.d/allow-jenkins-updateRepositories \
        && echo \
        && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addToCrontabEveryHour.sh" "${CIS[FULLSCRIPTNAME]:?"Missing FULLSCRIPTNAME"}" "${_MINUTE_FROM_OWN_IP}" \
        && return 0

    return 1
}

function setup() {
    local _DOMAIN="$(getOrSetDomain "${1}")"
    readonly _DOMAIN

    ! checkPreconditions "${_DOMAIN}" \
        && return 1

    addDefinition \
        && addState \
        && setupCoreFunctionality \
        && return 0

    echo "FAIL: setup is incomplete:                         ("$(readlink -f ${0})")" >&2
    echo "  - due to an error or insufficient rights." >&2
    return 1
}



# Parameter 1: is optional '()?' and only alphanumeric characters are allowed and [.-] if not leading (due to: -oProxyCommand=...).
base.set DOMAIN "${1}" '^([a-zA-Z0-9][a-zA-Z0-9.-]*)?$' || exit 1
setup "${DOMAIN}" \
    && exit 0

exit 1

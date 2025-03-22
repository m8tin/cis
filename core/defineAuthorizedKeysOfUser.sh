#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!

function prepareFolder() {
    local _HOME_FOLDER _SSH_FOLDER _USER
    _SSH_FOLDER="${1:?"prepareFolder(): Missing parameter SSH_PATH"}"
    _HOME_FOLDER="${_SSH_FOLDER%%/.ssh*}"  #Removes longest matching pattern '/.ssh*' from the end
    _USER="${_HOME_FOLDER##*/}"            #Removes longest matching pattern '*/'     from the begin
    readonly _HOME_FOLDER _SSH_FOLDER _USER

    ! [ -d "${_HOME_FOLDER}" ] \
        && echo "FAIL: The home folder is unavailable:              ("$(readlink -f ${0})")" \
        && echo "  - '${_HOME_FOLDER}'" \
        && return 1

    #The ssh folder already exists
    [ -d "${_SSH_FOLDER}" ] \
        && [ "$(stat -c '%U:%G' "${_SSH_FOLDER}")" == "${_USER}:${_USER}" ] \
        && [ "$(stat -c '%a' "${_SSH_FOLDER}")" == "700" ] \
        && echo "SUCCESS: The ssh folder already exists:            ("$(readlink -f ${0})")" \
        && echo "  - '${_SSH_FOLDER}'" \
        && return 0

    #The calling user can create its own folder
    ! [ -d "${_SSH_FOLDER}" ] \
        && [ "${_USER:?"Missing USER"}" == "$(whoami)" ] \
        && mkdir -p "${_SSH_FOLDER}" \
        && chown "${_USER}:${_USER}" "${_SSH_FOLDER}" \
        && chmod go-rwx "${_SSH_FOLDER}" \
        && echo "SUCCESS: The ssh folder was created:               ("$(readlink -f ${0})")" \
        && echo "  - '${_SSH_FOLDER}'" \
        && return 0

    #The root user can create every folder
    ! [ -d "${_SSH_FOLDER}" ] \
        && [ "${_USER:?"Missing USER"}" != "$(whoami)" ] \
        && [ "$(id -u)" == "0" ] \
        && mkdir -p "${_SSH_FOLDER}" \
        && chown "${_USER}:${_USER}" "${_SSH_FOLDER}" \
        && chmod go-rwx "${_SSH_FOLDER}" \
        && echo "SUCCESS: The ssh folder was created:               ("$(readlink -f ${0})")" \
        && echo "  - '${_SSH_FOLDER}'" \
        && return 0

    echo "FAIL: The ssh folder could not be prepared:        ("$(readlink -f ${0})")" >&2
    echo "  - '${_SSH_FOLDER}'" >&2
    echo "  - due to an error or insufficient rights." >&2
    return 1
}

function defineAuthorizedKeysOfUser() {
    local _CIS_ROOT _CORE_SCRIPTS _DOMAIN _DEFINITIONS _USER
    _DEFINITIONS="$(realpath -s "${1:?"Missing first parameter DEFINITIONS: 'ROOT/definitions/DOMAIN'"}")"
    _CIS_ROOT="${_DEFINITIONS%%/definitions/*}/"  #Removes longest  matching pattern '/definitions/*' from the end
    _DOMAIN="${_DEFINITIONS##*/definitions/}"     #Removes longest  matching pattern '*/definitions/' from the begin
    _DOMAIN="${_DOMAIN%/}"                        #Removes shortest matching pattern '/'              from the end
    #Build from components for safety
    _DEFINITIONS="${_CIS_ROOT:?"Missing ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}"

    _USER="${2:?"Missing second parameter USER"}"
    _CORE_SCRIPTS="${_CIS_ROOT:?"Missing ROOT"}core/"
    readonly _CIS_ROOT _CORE_SCRIPTS _DOMAIN _DEFINITIONS _USER

    case "${_USER:?"Missing USER"}" in
        root)
            prepareFolder "/root/.ssh" \
                && echo \
                && source "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${_DEFINITIONS}" "/root/.ssh/authorized_keys" \
                && return 0 || return 1
            ;;
        *)
            prepareFolder "/home/${_USER}/.ssh" \
                && echo \
                && source "${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" "${_DEFINITIONS}" "/home/${_USER}/.ssh/authorized_keys" \
                && return 0 || return 1
            ;;
    esac
}

# sanitizes all parameters
defineAuthorizedKeysOfUser \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0

exit 1

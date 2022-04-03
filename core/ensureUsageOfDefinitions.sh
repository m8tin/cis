#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!

function printIfEqual() {
    [ "${1:?"Missing first parameter"}" == "${2}" ] \
        && echo "${1}" \
        && return 0

    return 1
}

function isCoreDefinition() {
    echo "${1:?"Missing first parameter FILE"}" | grep "/root/.ssh/authorized_keys" &> /dev/null \
        && return 0

    echo "${1:?"Missing first parameter FILE"}" | grep "/home/jenkins/.ssh/authorized_keys" &> /dev/null \
        && return 0

    echo "${1:?"Missing first parameter FILE"}" | grep "/etc/sudoers.d/allow-jenkins-updateRepositories" &> /dev/null \
        && return 0

    return 1
}

function printSelectedDefinition() {
    local _CORE_FILE_DEFINED_ALL_HOSTS _CORE_FILE_DEFINED_THIS_HOST _FILE_DEFINED_ALL_HOSTS _FILE_DEFINED_THIS_HOST
    _CORE_FILE_DEFINED_ALL_HOSTS="${1:?"Missing DEFINITIONS"}/core/all${2:?"Missing CURRENT_FULLFILE"}"
    _CORE_FILE_DEFINED_THIS_HOST="${1:?"Missing DEFINITIONS"}/core/$(hostname -s)${2:?"Missing CURRENT_FULLFILE"}"
    _FILE_DEFINED_ALL_HOSTS="${1:?"Missing DEFINITIONS"}/hosts/all${2:?"Missing CURRENT_FULLFILE"}"
    _FILE_DEFINED_THIS_HOST="${1:?"Missing DEFINITIONS"}/hosts/$(hostname -s)${2:?"Missing CURRENT_FULLFILE"}"
    readonly _CORE_FILE_DEFINED_ALL_HOSTS _CORE_FILE_DEFINED_THIS_HOST _FILE_DEFINED_ALL_HOSTS _FILE_DEFINED_THIS_HOST

    #The following are special definitions that affect the core functionality.
    #Try this host first because it should be priorized.
    isCoreDefinition "${2:?"Missing CURRENT_FULLFILE"}" \
        && [ -s "${_CORE_FILE_DEFINED_THIS_HOST}" ] \
        && echo "${_CORE_FILE_DEFINED_THIS_HOST}" \
        && return 0

    #The following are special definitions that affect the core functionality.
    isCoreDefinition "${2:?"Missing CURRENT_FULLFILE"}" \
        && [ -s "${_CORE_FILE_DEFINED_ALL_HOSTS}" ] \
        && echo "${_CORE_FILE_DEFINED_ALL_HOSTS}" \
        && return 0

    #Try this host first because it should be priorized.
    ! isCoreDefinition "${2:?"Missing CURRENT_FULLFILE"}" \
        && [ -s "${_FILE_DEFINED_THIS_HOST}" ] \
        && echo "${_FILE_DEFINED_THIS_HOST}" \
        && return 0

    ! isCoreDefinition "${2:?"Missing CURRENT_FULLFILE"}" \
        && [ -s "${_FILE_DEFINED_ALL_HOSTS}" ] \
        && echo "${_FILE_DEFINED_ALL_HOSTS}" \
        && return 0

    return 1
}

function createSymlinkToDefinition() {
    local _CURRENT_FOLDER _CURRENT_FULLFILE _DEFINED_FULLFILE _SAVED_FULLFILE
    _CURRENT_FOLDER="${1:?"Missing CURRENT_FOLDER"}"
    _CURRENT_FULLFILE="${2:?"Missing CURRENT_FULLFILE"}"
    _DEFINED_FULLFILE="${3:?"Missing DEFINED_FULLFILE"}"
    _SAVED_FULLFILE="${4:?"Missing SAVED_FULLFILE"}"
    readonly _CURRENT_FOLDER _CURRENT_FULLFILE _DEFINED_FULLFILE _SAVED_FULLFILE

    [ -f "${_CURRENT_FULLFILE}" ] \
        && [ "$(sha256sum "${_DEFINED_FULLFILE}" | cut -d' ' -f1)" == "$(sha256sum "${_CURRENT_FULLFILE}" | cut -d' ' -f1)" ] \
        && echo "The content of the current file already matches the definition, but it will be replaced by a symlink..."

    [ -f "${_CURRENT_FULLFILE}" ] \
        && [ "$(sha256sum "${_DEFINED_FULLFILE}" | cut -d' ' -f1)" == "$(sha256sum "${_CURRENT_FULLFILE}" | cut -d' ' -f1)" ] \
        && echo "The content of the current file already matches the definition, but it will be replaced by a symlink..."


    [ -f "${_CURRENT_FULLFILE}" ] \
        && mv "${_CURRENT_FULLFILE:?"Missing CURRENT_FULLFILE"}" "${_SAVED_FULLFILE:?"Missing SAVED_FULLFILE"}" \
        && echo "Current file has been backed up to: '${_SAVED_FULLFILE}'"

    [ -d "${_CURRENT_FOLDER}" ] \
        && ln -s -f "${_DEFINED_FULLFILE}" "${_CURRENT_FULLFILE}" \
        && return 0

    [ -f "${_SAVED_FULLFILE}" ] \
        && cp --remove-destination "${_SAVED_FULLFILE}" "${_CURRENT_FULLFILE}" \
        && echo "File restored due to a failure."

    return 1
}

function ensureUsageOfDefinitions() {
    local _ROOT _CURRENT_FILE _CURRENT_FOLDER _CURRENT_FULLFILE _DEFINITIONS _DOMAIN _DEFINED_FULLFILE _NOW _SAVED_FULLFILE
    _DEFINITIONS="$(realpath -s "${1:?"Missing first parameter DEFINITIONS: 'ROOT/definitions/DOMAIN'"}")"
    _ROOT="${_DEFINITIONS%%/definitions/*}/"   #Removes longest  matching pattern '/definitions/*' from the end
    _DOMAIN="${_DEFINITIONS##*/definitions/}"  #Removes longest  matching pattern '*/definitions/' from the begin
    _DOMAIN="${_DOMAIN%/}"                     #Removes shortest matching pattern '/'              from the end
    #Build from components for safety
    _DEFINITIONS="$(printIfEqual "${_DEFINITIONS}" "${_ROOT:?"Missing ROOT"}definitions/${_DOMAIN:?"Missing DOMAIN"}")"


    _CURRENT_FOLDER="$(dirname "${2:?"Missing second parameter CURRENT_FULLFILE"}")"
    _CURRENT_FOLDER="${_CURRENT_FOLDER%/}/"  #Removes shortest matching pattern '/' from the end
    ! [ -d "${_CURRENT_FOLDER}" ] \
        && echo "FAIL: The folder cannot be read:                   ("$(readlink -f ${0})")" \
        && echo "  - '${_CURRENT_FOLDER}'" \
        && echo "  - user '"$(whoami)"' has insufficient rights on this host '$(hostname -s)'" \
        && echo "  - or the folder does not exist." \
        && return 1

    _CURRENT_FOLDER="$(realpath -s "${_CURRENT_FOLDER:?"Missing CURRENT_FOLDER"}")"
    _CURRENT_FOLDER="${_CURRENT_FOLDER%/}/"  #Removes shortest matching pattern '/' from the end

    _CURRENT_FILE="$(basename "${2:?"Missing second parameter CURRENT_FULLFILE"}")"
    #Build from components for safety
    _CURRENT_FULLFILE="${_CURRENT_FOLDER:?"Missing CURRENT_FOLDER"}${_CURRENT_FILE:?"Missing CURRENT_FILE"}"


    _DEFINED_FULLFILE="$(printSelectedDefinition "${_DEFINITIONS}" "${_CURRENT_FULLFILE}")"
    _NOW="$(date +%Y%m%d_%H%M)"
    _SAVED_FULLFILE="${_CURRENT_FULLFILE}-backup@${_NOW:?"Missing NOW"}"
    readonly _ROOT _CURRENT_FILE _CURRENT_FOLDER _CURRENT_FULLFILE _DEFINITIONS _DOMAIN _DEFINED_FULLFILE _NOW _SAVED_FULLFILE

    ! [ -f "${_DEFINED_FULLFILE}" ] \
        && echo "FAIL: No definition available for this file:       ("$(readlink -f ${0})")" \
        && echo "  - '${_CURRENT_FULLFILE}'" \
        && return 1

    ! [ -s "${_DEFINED_FULLFILE}" ] \
        && echo "FAIL: No content available for this file:          ("$(readlink -f ${0})")" \
        && echo "  - '${_CURRENT_FULLFILE}'" \
        && return 1

    [ "${_DEFINED_FULLFILE}" == "$(readlink -f "${_CURRENT_FULLFILE}")" ] \
        && echo "SUCCESS: The definition already is in place:       ("$(readlink -f ${0})")" \
        && echo "  - '${_DEFINED_FULLFILE}'" \
        && return 0

    echo "${_ROOT:?"Missing ROOT"}" | grep "home" &> /dev/null \
        && echo "SUCCESS: Although this definition will be skipped: ("$(readlink -f ${0})")" \
        && echo "  - '${_DEFINED_FULLFILE}'" \
        && echo "  that is because the current environment is:" \
        && echo "    - ${_ROOT}" \
        && echo "  following file is in use:" \
        && echo "    - $(readlink -f "${_CURRENT_FULLFILE}")" \
        && return 0

    ! [ -w "${_CURRENT_FOLDER}" ] \
        && echo "FAIL: The current file cannot be added:            ("$(readlink -f ${0})")" \
        && echo "  - '${_CURRENT_FULLFILE}'" \
        && echo "  - user '$(whoami)' has insufficient rights on this host '$(hostname -s)'" \
        && return 1

    [ -f "${_CURRENT_FULLFILE}" ] \
        && ! [ -w "${_CURRENT_FULLFILE}" ] \
        && echo "FAIL: The current file cannot be modified:         ("$(readlink -f ${0})")" \
        && echo "  - '${_CURRENT_FULLFILE}'" \
        && echo "  - user '$(whoami)' has insufficient rights on this host '$(hostname -s)'" \
        && return 1

    createSymlinkToDefinition "${_CURRENT_FOLDER}" "${_CURRENT_FULLFILE}" "${_DEFINED_FULLFILE}" "${_SAVED_FULLFILE}" \
        && echo "SUCCESS: The definition was ensured:               ("$(readlink -f ${0})")" \
        && echo "- '${_DEFINED_FULLFILE}'" \
        && return 0

    echo "FAIL: The definition could not be ensured:         ("$(readlink -f ${0})")"
    echo "  - due to an error or insufficient rights."
    return 1
}

# sanitizes all parameters
ensureUsageOfDefinitions \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

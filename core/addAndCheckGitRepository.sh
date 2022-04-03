#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



function checkPermissions(){
    local _FOLDER _REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _RIGHTS="${2:?"Missing second parameter RIGHTS"}"
    readonly _FOLDER _REPOSITORY

    [ "${_RIGHTS}" == "readonly" ] \
        && [ -d "${_FOLDER}/.git" ] \
        && ! git -C "${_FOLDER}" push --dry-run &> /dev/null \
        && return 0

    [ "${_RIGHTS}" == "writable" ] \
        && [ -d "${_FOLDER}/.git" ] \
        && git -C "${_FOLDER}" push --dry-run &> /dev/null \
        && return 0

    echo "FAIL: The rights of the repository are incorrect:  ("$(readlink -f ${0})")"
    echo "  - '${_FOLDER}' is not '${_RIGHTS}'"
    echo "  - check the settings of gitea."
    return 1
}

function checkRemoteRepository() {
    local _FOLDER _REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _REPOSITORY="${2:?"Missing second parameter REPOSITORY"}"
    readonly _FOLDER _REPOSITORY

    #Should exist after successful clone only, therefore the remote repository exists and was accessible.
    [ -d "${_FOLDER}/.git" ] \
        && return 0

    #Checks if repository exists and is accessible.
    ! [ -d "${_FOLDER}/.git" ] \
        && git ls-remote "${_REPOSITORY}" \
        && return 0

    echo "FAIL: The remote repository is not accessible:     ("$(readlink -f ${0})")"
    echo "  - '${_REPOSITORY}'"
    echo "  - check the settings of gitea."
    return 1
}

function cloneOrPull {
    local _FOLDER _REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _REPOSITORY="${2:?"Missing second parameter REPOSITORY"}"
    readonly _FOLDER _REPOSITORY

    ! [ -d "${_FOLDER}/.git" ] \
        && git clone "${_REPOSITORY}" "${_FOLDER}" &> /dev/null \
        && return 0

    [ -d "${_FOLDER}/.git" ] \
        && git -C "${_FOLDER}" pull &> /dev/null \
        && return 0

    echo "FAIL: The local repository is not updatable:       ("$(readlink -f ${0})")"
    echo "  - '${_FOLDER}'"
    echo "  - check your network and the permissions in gitea."
    return 1
}

# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addAndCheckGitRepository() {
    local _FOLDER _REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _REPOSITORY="${2:?"Missing second parameter REPOSITORY: e.g. ssh://git@your.domain.com/iss.git "}"
    _RIGHTS="${3:?"Missing third parameter RIGHTS: (readonly, writable) "}"
    readonly _FOLDER _REPOSITORY

    checkRemoteRepository "${_FOLDER}" "${_REPOSITORY}" \
        && cloneOrPull "${_FOLDER}" "${_REPOSITORY}" \
        && checkPermissions "${_FOLDER}" "${_RIGHTS}" \
        && echo "SUCCESS: The git repository is usable.             ("$(readlink -f ${0})")" \
        && echo "  - remote repository: '${_REPOSITORY}'" \
        && echo "  - local repository:  '${_FOLDER}' (${_RIGHTS})" \
        && return 0

    echo "FAIL: The repository is not functional:            ("$(readlink -f ${0})")"
    echo "  - remote repository: '${_REPOSITORY}'"
    echo "  - local repository:  '${_FOLDER}'"
    echo "  - due to an error or insufficient rights or"
    echo "  - one check failed."
    return 1
}

# sanitizes all parameters
addAndCheckGitRepository \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${3} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



function checkPermissions(){
    local _FOLDER _RIGHTS
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _RIGHTS="${2:?"Missing second parameter RIGHTS"}"
    readonly _FOLDER _RIGHTS

    [ "${_RIGHTS}" == "readonly" ] \
        && [ -d "${_FOLDER}/.git" ] \
        && ! git -C "${_FOLDER}" push --dry-run &> /dev/null \
        && return 0

    [ "${_RIGHTS}" == "writable" ] \
        && [ -d "${_FOLDER}/.git" ] \
        && git -C "${_FOLDER}" push --dry-run &> /dev/null \
        && return 0

    echo "FAIL: The rights of the repository are incorrect:  ("$(readlink -f ${0})")" >&2
    echo "  - '${_FOLDER}' is not '${_RIGHTS}'" >&2
    echo "  - check the settings of gitea." >&2
    return 1
}

function cloneOrPull {
    local _FOLDER _REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _REPOSITORY="${2:?"Missing second parameter REPOSITORY"}"
    readonly _FOLDER _REPOSITORY

    [ -d "${_FOLDER}/.git" ] \
        && git -C "${_FOLDER}" pull &> /dev/null \
        && return 0

    ! [ -d "${_FOLDER}/.git" ] \
        && git clone "${_REPOSITORY}" "${_FOLDER}" &> /dev/null \
        && return 0

    echo "FAIL: The local repository is not updatable:       ("$(readlink -f ${0})")" >&2
    echo "  - '${_FOLDER}'" >&2
    echo "  - check your network and the permissions in gitea." >&2
    return 1
}

function printRepository(){
    local _FOLDER _CONFIGURED_REPOSITORY _SUGGESTED_REPOSITORY
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _CONFIGURED_REPOSITORY="$(git -C "${_FOLDER:?"Missing FOLDER"}" config --get remote.origin.url 2> /dev/null)"
    _SUGGESTED_REPOSITORY="${2}"
    readonly _FOLDER _CONFIGURED_REPOSITORY _SUGGESTED_REPOSITORY

    ! [ -z "${_CONFIGURED_REPOSITORY}" ] \
        && echo "${_CONFIGURED_REPOSITORY}" \
        && return 0

    while true; do
        read -e -p "Enter ssh URL to clone Repository: " -i "${_SUGGESTED_REPOSITORY}" _REPOSITORY
        echo "${_REPOSITORY}" | grep -F 'git@' &> /dev/null \
            && git ls-remote "${_REPOSITORY}" &> /dev/null \
            && echo "${_REPOSITORY:?"Missing REPOSITORY: e.g. ssh://git@your.domain.com/cis.git"}" \
            && return 0
    done

    echo "FAIL: The remote repository is not accessible:     ("$(readlink -f ${0})")" >&2
    echo "  - '${_REPOSITORY}'" >&2
    echo "  - check the settings of gitea." >&2
    return 1
}

# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addAndCheckGitRepository() {
    local _FOLDER _REPOSITORY _RIGHTS
    _FOLDER="${1:?"Missing first parameter FOLDER"}"
    _RIGHTS="${2:?"Missing second parameter RIGHTS: (readonly, writable) "}"
    _REPOSITORY="$(printRepository "${_FOLDER}" "${3}")"
    readonly _FOLDER _REPOSITORY _RIGHTS

    echo \
        && cloneOrPull "${_FOLDER}" "${_REPOSITORY:?"Missing REPOSITORY: e.g. ssh://git@your.domain.com/cis.git"}" \
        && checkPermissions "${_FOLDER}" "${_RIGHTS}" \
        && echo "SUCCESS: The git repository is usable.             ("$(readlink -f ${0})")" \
        && echo "  - remote repository: '${_REPOSITORY}'" \
        && echo "  - local repository:  '${_FOLDER}' (${_RIGHTS})" \
        && return 0

    echo "FAIL: The repository is not functional:            ("$(readlink -f ${0})")" >&2
    echo "  - remote repository: '${_REPOSITORY}'" >&2
    echo "  - local repository:  '${_FOLDER}'" >&2
    echo "  - due to an error or insufficient rights or" >&2
    echo "  - one check failed." >&2
    return 1
}

# sanitizes all parameters
addAndCheckGitRepository \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${2} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    "$(echo ${3} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0

exit 1

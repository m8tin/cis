#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Note that an unprivileged user can use this script successfully,
# if no user has to be added to the host because it already exists.
function addNormalUser() {
    local _USER
    _USER="${1:?"Missing first parameter USER"}"
    readonly _USER

    #The user already exists
    id -u "${_USER}" &> /dev/null \
        && echo "SUCCESS: The user already exists:                  ("$(readlink -f ${0})")" \
        && echo "  - '${_USER}'" \
        && return 0

    [ "$(id -u)" == "0" ] \
        && adduser --gecos 'Normal user' --disabled-password "${_USER}" \
        && chown -R "${_USER}:${_USER}" "/home/${_USER}" \
        && echo "SUCCESS: The user was created:                     ("$(readlink -f ${0})")" \
        && echo "  - '${_USER}'" \
        && echo "  - no password was set, use passwd if needed" \
        && echo "  - existing home directories were taken over" \
        && return 0

    echo "FAIL: The user could not be created:               ("$(readlink -f ${0})")"
    echo "  - '${_USER}'"
    echo "  - due to an error or insufficient rights."
    return 1
}

# sanitizes all parameters
addNormalUser \
    "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && exit 0 || exit 1

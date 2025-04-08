#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Folders always ends with an tailing '/'
_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CIS_ROOT="${_SCRIPT%%/core/*}/"               #Removes longest  matching pattern '/core/*' from the end
_OVERRIDE_DOMAIN_FILE="${_CIS_ROOT:?"Missing CIS_ROOT"}overrideOwnDomain"

# There has to be one dot at least.
_BOOT_DOMAIN="$(hostname -b | grep -F '.' | cut -d. -f2-)"

# Take OVERRIDING_DOMAIN_FILE without empty lines and comments, then take the first line without leading spaces
_OVERRIDE_DOMAIN="$(grep -vE '^[[:space:]]*$|^[[:space:]]*#' "${_OVERRIDE_DOMAIN_FILE}" 2> /dev/null | head -n 1 | xargs)"

! [ -z "${_OVERRIDE_DOMAIN}" ] \
    && [ "${_OVERRIDE_DOMAIN}" != "${_BOOT_DOMAIN}" ] \
    && echo "WARNING: Domain has been overridden by: ${_OVERRIDE_DOMAIN_FILE}" >&2 \
    && echo "${_OVERRIDE_DOMAIN}" \
    && exit 0

! [ -z "${_BOOT_DOMAIN}" ] \
    && echo "${_BOOT_DOMAIN}" \
    && exit 0

echo "It was impossible to find out the domain of this host, please prepare this host first." >&2
exit 1

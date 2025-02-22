#!/bin/bash

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!



# Folders always ends with an tailing '/'
_SCRIPT="$(readlink -f "${0}" 2> /dev/null)"
_CORE_SCRIPTS="$(dirname ${_SCRIPT:?"Missing SCRIPT"} 2> /dev/null)/"
_CIS_ROOT="$(dirname ${_CORE_SCRIPTS:?"Missing CORE_SCRIPTS"} 2> /dev/null)/"
_OVERRIDE_DOMAIN_FILE="${_CIS_ROOT:?"Missing CIS_ROOT"}overrideOwnDomain"

# Wenn OVERRIDING_DOMAIN_FILE enhält lesbare Daten
grep '[^[:space:]]' "${_OVERRIDE_DOMAIN_FILE:?"Missing OVERRIDE_DOMAIN_FILE"}" &> /dev/null \
    && echo "WARNING: Domain has been overridden by: ${_OVERRIDE_DOMAIN_FILE}" > /dev/stderr \
    && cat "${_OVERRIDE_DOMAIN_FILE}" \
    && exit 0

_BOOT_HOSTNAME="$(hostname -b)"
# There has to be one dot at least.
echo "${_BOOT_HOSTNAME}" | grep -v '\.' &> /dev/null \
    && echo "It was impossible to find out the domain of this host, please prepare this host first." > /dev/stderr \
    && exit 1

#Removes shortest matching pattern '*.' from the begin to get the domain
echo "${_BOOT_HOSTNAME#*.}" \
    && exit 0

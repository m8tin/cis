#!/bin/bash

_CURRENT_FILE='/etc/ssh/sshd_config.d/AccessRestriction.conf'

#No file is NOT ok
[ ! -e "${_CURRENT_FILE}" ] \
    && exit 1

#File has to be readable, then
#search for '/definitions/' in the path of current file, after readlink expanded a potential symlink.
[ -r "${_CURRENT_FILE}" ] \
    && readlink -f "${_CURRENT_FILE}" | grep -q "/definitions/" \
    && exit 0

#File has to be readable, then
#search for '/core/default/' in the path of current file, after readlink expanded a potential symlink.
[ -r "${_CURRENT_FILE}" ] \
    && readlink -f "${_CURRENT_FILE}" | grep -q "/core/default/" \
    && exit 0

exit 1

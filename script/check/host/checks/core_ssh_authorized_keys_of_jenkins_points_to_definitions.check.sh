#!/bin/bash

_CURRENT_FILE='/home/jenkins/.ssh/authorized_keys'

[ "$(id -u)" != "0" ] \
    && printf "(INSUFFICENT RIGHTS) " \
    && exit 1

#File has to be readable, then
#search for '/definitions/' in the path of current file, after readlink expanded a potential symlink.
[ -r "${_CURRENT_FILE}" ] \
    && readlink -f "${_CURRENT_FILE}" | grep -q "/definitions/" \
    && exit 0

exit 1

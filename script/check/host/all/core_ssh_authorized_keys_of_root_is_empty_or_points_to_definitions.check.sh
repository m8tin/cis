#!/bin/bash

_CURRENT_FILE='/root/.ssh/authorized_keys'

[ "$(id -u)" != "0" ] \
    && printf "(INSUFFICENT RIGHTS) " \
    && exit 1

#No file is ok
[ ! -e "${_CURRENT_FILE}" ] \
    && exit 0

#The file must be readable, then
#all comments and all blank lines are removed, after which the number of remaining lines must be zero.
[ -r "${_CURRENT_FILE}" ] \
    && [ "0" == "$(cat "${_CURRENT_FILE}" | sed 's/[[:blank:]]*#.*//' | sed '/^$/d' | grep -c .)" ] \
    && exit 0

#File has to be readable, then
#search for '/definitions/' in the path of current file, after readlink expanded a potential symlink.
[ -r "${_CURRENT_FILE}" ] \
    && readlink -f "${_CURRENT_FILE}" | grep -q "/definitions/" \
    && exit 0

exit 1

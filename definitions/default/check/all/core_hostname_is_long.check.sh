#!/bin/bash

_CURRENT_FILE='/etc/hostname'

#The file must be readable, then
#the number of lines containing a '.' must be zero.
[ -r "${_CURRENT_FILE}" ] \
    && [ "$(grep -cF '.' "${_CURRENT_FILE}")" -gt 0 ] \
    && exit 0
exit 1

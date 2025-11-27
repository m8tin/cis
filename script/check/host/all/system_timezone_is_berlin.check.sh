#!/bin/bash

_CURRENT_FILE='/etc/timezone'

#The file must be readable, then
#the number of lines containing "Europe/Berlin" must be one.
[ -r "${_CURRENT_FILE}" ] \
    && [ "1" == "$(cat "${_CURRENT_FILE}" | grep 'Europe/Berlin' | grep -c .)" ] \
    && exit 0
exit 1

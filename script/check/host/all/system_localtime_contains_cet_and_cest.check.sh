#!/bin/bash

_CURRENT_FILE='/etc/localtime'

#The file must be readable, then
#the number of lines containing "CET" must be greater than zero, and
#the number of lines containing "CEST" must also be greater than zero.
[ -r "${_CURRENT_FILE}" ] \
    && [ "$(zdump -v "${_CURRENT_FILE}" | head -n 10 | grep 'CET' | grep -c .)" -gt "0" ] \
    && [ "$(zdump -v "${_CURRENT_FILE}" | head -n 10 | grep 'CEST' | grep -c .)" -gt "0" ] \
    && exit 0
exit 1

#!/bin/bash

_CURRENT_POOL='zpool1/persistent'

#Check if the tool 'zfs' is available, then
#retrieve the property 'recordsize' from 'zpool1/persistent', without header and compare the result with '16K'
#because this a 'recordsize' of '16K' matches to the needs of 'mariadb'.

#Set with: 'zfs set recordsize=16K zpool1/persistent'
zfs version &> /dev/null  \
    && [ "$(zfs get recordsize -Ho value ${_CURRENT_POOL})" == "16K" ] \
    && exit 0
exit 1


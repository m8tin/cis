#!/bin/bash

_CURRENT_POOL='zpool1'

#Check if the tool 'zfs' is available, then
#retrieve the property 'atime' from 'zpool1', without header and compare the result with 'off'
#because this the feature 'atime' logs each access, there are many avoidable writes.

#Set with: 'zfs set atime=off zpool1'
zfs version &> /dev/null  \
    && [ "$(zfs get atime -Ho value ${_CURRENT_POOL} 2> /dev/null)" == "off" ] \
    && exit 0
exit 1

#!/bin/bash

_CURRENT_ZFS='zpool1'

#Check if the tool 'zfs' is available, then
#retrieve the property 'mountpoint' from 'zpool1', without header and compare the result with '/zpool1'

#Set with: 'zfs set mountpount=default'
zfs version &> /dev/null \
    && [ "$(zfs get mountpoint -Ho value ${_CURRENT_ZFS} 2> /dev/null)" == "/${_CURRENT_ZFS}" ] \
    && exit 0
exit 1

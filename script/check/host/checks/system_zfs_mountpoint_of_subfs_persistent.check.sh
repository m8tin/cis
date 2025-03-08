#!/bin/bash

_CURRENT_ZFS='zpool1/persistent'

#Check if the tool 'zfs' is available, then
#retrieve the property 'mountpoint' from 'zpool1/persistent', without header and compare the result with 'none'

#Set with: 'zfs set mountpoint=none zpool1/persistent'
zfs version &> /dev/null  \
    && [ "$(zfs get mountpoint -Ho value ${_CURRENT_ZFS})" == "none" ] \
    && exit 0
exit 1

#!/bin/bash

_CURRENT_POOL='zpool1'

#Check if the tool 'zfs' is available, then
#retrieve the property 'compression' from 'zpool1', without header and compare the result with 'lz4'

#Set with: 'zfs set compression=lz4 zpool1'
zfs version &> /dev/null  \
    && [ "$(zfs get compression -Ho value ${_CURRENT_POOL} 2> /dev/null)" == "lz4" ] \
    && exit 0
exit 1

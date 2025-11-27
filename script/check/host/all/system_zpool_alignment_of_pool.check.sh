#!/bin/bash

_CURRENT_POOL='zpool1'

#Check if the tool 'zpool' is available, then
#retrieve the property 'ashift' from 'zpool1', without header and compare the result with '12'
zpool version &> /dev/null \
    && [ "$(zpool get ashift -Ho value ${_CURRENT_POOL} 2> /dev/null)" == "12" ] \
    && exit 0
exit 1

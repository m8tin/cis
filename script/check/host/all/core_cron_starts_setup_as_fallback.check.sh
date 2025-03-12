#!/bin/bash

[ "$(id -u)" != "0" ] \
    && printf "(INSUFFICENT RIGHTS) " \
    && exit 1

crontab -l | grep -E "[0-9]{1,2}[ \*]{8}[[:blank:]]*\/cis\/setupCoreOntoThisHost.sh" > /dev/null 2>&1 \
    && exit 0
exit 1

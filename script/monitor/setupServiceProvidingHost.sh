#!/bin/bash
if [ $(id -u) -ne 0 ]; then
    sudo "${0}" && exit 0
    exit 1
fi

source /cis/core/base.module.sh



echo "Setup the user and permission to enable the monitoring this host ... " \
    && "${CIS[COREROOT]:?"Missing CIS_COREROOT"}addNormalUser.sh" monitoring \
    && echo \
    && "${CIS[COREROOT]:?"Missing CIS_COREROOT"}defineAuthorizedKeysOfUser.sh" "${CIS[DOMAINDEFINITIONS]}" monitoring \
    && exit 0

exit 1

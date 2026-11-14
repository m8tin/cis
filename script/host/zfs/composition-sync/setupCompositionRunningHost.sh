#!/bin/bash
if [ $(id -u) -ne 0 ]; then
    sudo "${0}" && exit 0
    exit 1
fi

source /cis/core/base.module.sh



echo "Setup the user and permission to enable syncing compositions of this host ... " \
    && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}addNormalUser.sh" --user composition-sync \
    && echo \
    && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}defineAuthorizedKeysOfUser.sh" --definitions "${CIS[DOMAINDEFINITIONS]}" --user composition-sync \
    && echo \
    && "${CIS[COREROOT]:?"Missing CORE_SCRIPTS"}ensureUsageOfDefinitions.sh" --definitions "${CIS[DOMAINDEFINITIONS]}" --fullfile /etc/sudoers.d/allow-composition-sync-send \
    && exit 0

exit 1

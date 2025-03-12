#!/bin/bash

_CURRENT_FILE='/root/.ssh/id_ed25519'

[ "$(id -u)" != "0" ] \
    && printf "(INSUFFICENT RIGHTS) " \
    && exit 1

#File has to be readable and no passphrase should be needed.
ssh-keygen -y -P "" -f "${_CURRENT_FILE}" &> /dev/null \
    && exit 0

exit 1

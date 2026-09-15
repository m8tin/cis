#!/bin/bash

screen -RS "apt-upgrade" bash -c \
    "apt update | tee /dev/tty | grep -qF 'apt list --upgradable' \
        && apt upgrade -y \
        && apt autoremove --purge -y \
        && needrestart -m a -r l; \
    echo; \
    read -s -p 'Press ENTER to close this screen-session ...'"

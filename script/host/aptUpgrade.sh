#!/bin/bash

screen -RS "apt-upgrade" bash -c \
    "apt update | tee /dev/tty | grep -qF 'apt list --upgradable' \
        && apt upgrade -y \
        && apt autoremove --purge -y; \
    echo ''; \
    read -s -p 'Press ENTER to close this screen-session ...'"
needrestart -m a -r l

#!/bin/bash

# Fail because of unnecessary custom config
grep "Wants=network-online.target" /lib/systemd/system/nginx.service > /dev/null 2>&1 \
    && [ -f "/etc/systemd/system/nginx.service" ] \
    && exit 1

# Success if system config is ok
grep "Wants=network-online.target" /lib/systemd/system/nginx.service > /dev/null 2>&1 \
    && exit 0

# Success if custom config fixes system config
grep "Wants=network-online.target" /etc/systemd/system/nginx.service > /dev/null 2>&1 \
    && exit 0

exit 1

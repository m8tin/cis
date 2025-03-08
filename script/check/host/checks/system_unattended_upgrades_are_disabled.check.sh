#!/bin/bash

! systemctl is-enabled unattended-upgrades.service > /dev/null 2>&1 \
    && exit 0
exit 1

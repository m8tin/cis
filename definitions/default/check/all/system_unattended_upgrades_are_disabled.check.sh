#!/bin/bash
#
# There are three components working together:
#   - systemctl status unattended-upgrades.service      (One-Shot-Service, loaded means system knows the service, it DOES NOT run in background)
#   - systemctl status apt-daily.timer                  (apt update)
#   - systemctl status apt-daily-upgrade.timer          (apt upgrade)
#
# So disable/enaable the Upgrade with:
#   - systemctl disable --now apt-daily-upgrade.timer   (--now means disable and stop)
#   - systemctl enable --now apt-daily-upgrade.timer    (--now means enable and start)
#
! systemctl is-enabled apt-daily-upgrade.timer > /dev/null 2>&1 \
    && exit 0
exit 1

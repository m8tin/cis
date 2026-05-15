#!/bin/bash
source /cis/base/base.module.sh

#WARNING: Used for core functionality in setup.sh
#         DO NOT rename the script and test changes well!

source "${CIS[COREROOT]:?"Missing global COREROOT"}addNormalUser.sh" "${1:?"Missing first parameter USER"}" && exit 0 || exit 1

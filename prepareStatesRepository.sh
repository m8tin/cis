#!/bin/bash

[ "$(id -u)" != "0" ] \
    && echo "This script prepares the user 'root' of this host and the host itself," \
    && echo "so this script is allowed to be executed if you are root only." \
    && exit 1

# There has to be one dot at least.
_BOOT_DOMAIN="$(hostname -b | grep -F '.' | cut -d. -f2-)"

[ -z "${_BOOT_DOMAIN}" ] \
    && echo "It was impossible to find out the domain of this host, please prepare this host first." \
    && exit 1

_REOPSITORY_NAME="cis-state-${_BOOT_DOMAIN}"



#Generate README.md
mkdir -p /tmp/skeleton/state
cat << EOF > /tmp/skeleton/state/README.md
This repository contains the states of the domain “$_BOOT_DOMAIN” by the Core Infrastructure System.
EOF



cat << EOF

The first content for your repository for the state of the '$_BOOT_DOMAIN' domain has been created.

Please create a states repository.
To follow the naming convention name it '$_REOPSITORY_NAME'

Please DO NOT use the SSH key of root for this.
Maybe you can use https and user password for pushing the first commit.

Then go to folder '/tmp/skeleton/state' and follow the instructions as your git server shows.
For example:

  cd /tmp/skeleton/state
  git init
  git checkout -b main
  git add .
  git commit -m "first state"
  git remote add origin https://git.example.dev/[SOME_PATH/]$_REOPSITORY_NAME.git
  git push -u origin main

EOF

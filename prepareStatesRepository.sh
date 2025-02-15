#!/bin/bash

[ "$(id -u)" == "0" ] \
    && echo "This script prepares the content of the repository for the definitions." \
    && echo "You have run it as root, please run it with a user who has write access to the Git server." \
    && echo \
    && echo "Do not use the SSH key of root for this." \
    && echo \
    && exit 1

_BOOT_HOSTNAME="$(hostname -b)"
_BOOT_DOMAIN="${_BOOT_HOSTNAME#*.}"  #Removes shortest matching pattern '*.' from the begin to get the domain

[ -z "${_BOOT_DOMAIN}" ] \
    && echo "It was impossible to find out the domain of this host, please prepare this host first." \
    && exit 1

_REOPSITORY_NAME="cis-state-${_BOOT_DOMAIN}"



#Generate README.md
mkdir -p /tmp/skeleton/state
cat << EOF > /tmp/skeleton/state/README.md
#$_REOPSITORY_NAME

Central Infrastructure System's state of domain $_BOOT_DOMAIN
EOF



cat << EOF

The first content for your repository for the state of the '$_BOOT_DOMAIN' domain has been created.

Please create a states repository.
To follow the naming convention name it '$_REOPSITORY_NAME'

Then go to folder '/tmp/skeleton/state' and follow the instructions as your git server shows.
For example:

  git init
  git checkout -b main
  git add .
  git commit -m "first state"
  git remote add origin ssh://git@git.example.dev:22448/$_REOPSITORY_NAME.git
  git push -u origin main

EOF

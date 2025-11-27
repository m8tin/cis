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

_REOPSITORY_NAME="cis-definition-${_BOOT_DOMAIN}"



#Generate file 'README.md'
mkdir -p /tmp/skeleton/definition
cat << EOF > /tmp/skeleton/definition/README.md
This repository contains the definitions of the domain “$_BOOT_DOMAIN” by the Core Infrastructure System.
EOF



#Use current file 'authorized_keys' of root as definition
mkdir -p /tmp/skeleton/definition/core/all/root/.ssh
cp /root/.ssh/authorized_keys /tmp/skeleton/definition/core/all/root/.ssh/authorized_keys



#Generate file 'authorized_keys' for user jenkins
mkdir -p /tmp/skeleton/definition/core/all/home/jenkins/.ssh
cat << EOF > /tmp/skeleton/definition/core/all/home/jenkins/.ssh/authorized_keys
#------------------------------------------------------
# Enter the public ssh key of your jenkins server here.
#------------------------------------------------------
EOF



cat << EOF

The first content for your repository for the definitions of the '$_BOOT_DOMAIN' domain has been created.

Please create a definition repository.
To follow the naming convention name it '$_REOPSITORY_NAME'

Please DO NOT use the SSH key of root for this.
Maybe you can use https and user password for pushing the first commit.

Go to folder '/tmp/skeleton/definition' and check the content of all 'authorized_keys' files,
correct them if required to prevent losing access to your hosts.

The public ssh key of your jenkins server has to be added.

Only now follow the instructions as our git server shows.
For example:

  cd /tmp/skeleton/definition
  git init
  git checkout -b main
  git add .
  git commit -m "first core definitions"
  git remote add origin https://git.example.dev/[SOME_PATH/]$_REOPSITORY_NAME.git
  git push -u origin main

EOF

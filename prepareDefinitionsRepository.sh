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

_REOPSITORY_NAME="cis-definition-${_BOOT_DOMAIN}"



#Generate file 'README.md'
mkdir -p /tmp/skeleton/definition
cat << EOF > /tmp/skeleton/definition/README.md
#$_REOPSITORY_NAME

Central Infrastructure System's definition of domain $_BOOT_DOMAIN
EOF



#Generate sudoers file 'allow-jenkins-updateRepositories'
mkdir -p /tmp/skeleton/definition/core/all/etc/sudoers.d
cat << EOF > /tmp/skeleton/definition/core/all/etc/sudoers.d/allow-jenkins-updateRepositories
Cmnd_Alias C_JENKINS = \\
  /cis/updateRepositories.sh --core, \\
  /cis/updateRepositories.sh --scripts, \\
  /cis/updateRepositories.sh --definitions, \\
  /cis/updateRepositories.sh --states
jenkins ALL = (root) NOPASSWD: C_JENKINS
EOF



#Generate file 'authorized_keys' for user jenkins
mkdir -p /tmp/skeleton/definition/core/all/home/jenkins/.ssh
cat << EOF > /tmp/skeleton/definition/core/all/home/jenkins/.ssh/authorized_keys
#------------------------------------------------------
# Enter the public ssh key of your jenkins server here.
#------------------------------------------------------
EOF



#Use current file 'authorized_keys' of root as definition
mkdir -p /tmp/skeleton/definition/core/all/root/.ssh
cp /root/.ssh/authorized_keys /tmp/skeleton/definition/core/all/root/.ssh/authorized_keys



cat << EOF

The first content for your repository for the definitions of the '$_BOOT_DOMAIN' domain has been created.

Please create a definition repository.
To follow the naming convention name it '$_REOPSITORY_NAME'

Go to folder '/tmp/skeleton/definition' and check the content of all 'authorized_keys' files,
correct them if required to prevent losing access to your hosts.

The public ssh key of your jenkins server has to be added.

Only now follow the instructions as our git server shows.
For example:

  git init
  git checkout -b main
  git add .
  git commit -m "first core definitions"
  git remote add origin ssh://git@git.example.dev:22448/$_REOPSITORY_NAME.git
  git push -u origin main

EOF

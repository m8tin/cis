Core Infrastructure System (CIS)
================================

The main idea is to use git to keep scripts, definitions and state in sync across all hosts.  
Currently an operating instance uses one repository for this core functionality and scripts,  
another to distibute the definitions and a third one to share the state.

If a script or a definition has to be changed an independent working copy is needed to push the adaptions.  
States can be changed by a host itself. Then we need a mechanism that informs all hosts to execute a `git pull`.

We use a Git server as syncronisation point and use a web hook to send the notification.  
Because the should not be an agent to be installed on each host, we use jenkins to execute an update script via ssh.

This allows us to use standard software without having to program something that may contain a security problem.



Setup the first or a new host
-----------------------------

1. Update the host and ensure git is installed
2. Set the long hostname (fqdn)
3. Create ssh keys for user root (ssh key type ed25519)

You can use this script to do so: [prepareThisHostBeforeCloning.sh](./prepareThisHostBeforeCloning.sh)



### Ensure the existence of the repositories for your definitions and the state

This should be necessary just if you set up the first host.  
You can use the following scripts to assist the process:

- [prepareDefinitionsRepository.sh](./prepareDefinitionsRepository.sh)
- [prepareStatesRepository.sh](./prepareStatesRepository.sh)



### Register the public ssh key of user root

This is an example for `example.net` as domain of the host.

1. __Scripts:__  
   The public ssh key of the root user must be registered as a deploy key for the this repository,  
   which grants __readonly access__.

   A root user of a host should only be able to update the local cloned repository (`cis`) to a new version via `git pull`.

2. __Definitions:__  
   The public ssh key of the root user must be registered as a deploy key for the definitions repository,  
   which grants __readonly access__.  

   User root should only be able to update the local cloned repository (`cis-definition-example.net`) to a new version via `git pull`.

3. __States:__  
   The public ssh key of the root user must be registered as a deploy key for the states repository,  
   which grants __write access__.  

   User root should be able to push new state to the cloned repository (`cis-state-example.net`) via `git push`.



### Clone the Infrastructure System (cis) repository and complete the setup
After you registered the printed root's public key of this host you can clone the repository and execute the setup script:
```sh
# Note the tailing '/cis', because we want to clone the repository to that folder
git clone ssh://git@git.example.dev:22448/cis.git /cis

# Execute the setup script
/cis/setupCoreOntoThisHost.sh
```

<br>
<br>
<br>



Setup a new host step by step manually
--------------------------------------

To deploy cis you have to clone this repository to the host as root user.
Therefore you have to set the correct long hostname (fqdn) create a pair of ssh keys (key type ed25519) for user root  
and register the SSH public key of root as __deploy key__ to allow readonly access to this repository:

1. First become root:
   ```sh
   sudo -i
   ```

2. Update Ubuntu:
   ```sh
   # DO NOT SKIP THIS STEP
   apt update; apt upgrade -y
   ```

3. Install git if needed:
   ```sh
   git --version > /dev/null || apt install git
   ```

4. Set the long hostname:
   ```sh
   hostnamectl set-hostname "the-new-unique-long-hostname (fqdn, eg.: host1.example.net)"
   ```

5. If not exist generate the ssh key pair and print the public key of the user root:
   ```sh
   # -t    type of the key pair
   # -f    defines the filenames (we use the standard for the selected type here)
   # -q    quiet, no output or interaction
   # -N "" means the private key will not be secured by a passphrase
   # -C    defines a comment
   cat "/root/.ssh/id_ed25519.pub" \
       || (ssh-keygen \
           -t ed25519 \
           -f "/root/.ssh/id_ed25519" -q -N "" \
           -C "$(date +%Y%m%d)-root@$(hostname -b)" \
       && cat "/root/.ssh/id_ed25519.pub")
   ```

   This key has to be registerd via gitea web ui as deploy key into this repository.



How it works
------------
We add a webhook to each gitea repository that belongs to CIS:
 - __Taget URL:__   https://YOUR.JENKINS.DOMAIN/generic-webhook-trigger/invoke?token=YOUR_TOKEN
 - __HTTP-Method:__ POST
 - __Trigger On:__  Push Events
 - __Branch filter:__ main

Then we configure a jenkins job with no SCM, but 'Generic Webhook Trigger' as build-trigger.  
Here the same token must be used as for the 'Target URL' in gitea.

Finally we add 'shell execution' as build step there with this content:
```sh
cat <<EOD
Following public-key has to be authorized for user jenkins on the corresponding host:
=====================================================================================
EOD

cat "${JENKINS_HOME}/.ssh/id_ed25519.pub" \
    || (ssh-keygen \
        -t ed25519 \
        -f "${JENKINS_HOME}/.ssh/id_ed25519" -q -N "" \
        -C "$(date +%Y%m%d)-$(whoami)@$(echo ${JENKINS_URL} | cut -d/ -f3)" \
    && cat "${JENKINS_HOME}/.ssh/id_ed25519.pub")

# add your host here, note the tailing '&' to run it in parallel
ssh -o StrictHostKeyChecking=no jenkins@192.168.X.Y /cis/updateRepositories.sh ( --scripts | --definitions | --states ) &

#wait for all background processes to complete
wait
echo "All complete"
```

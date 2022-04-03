Infrastructure System (ISS)
===========================

Setup a new host
----------------

### Preconditions
To deploy the system you have to clone this repository to the host as root user.
Therefore you have to register the SSH public key of that root user as deploy key to allow readonly access to this repository.
We use the modern ed25519 keys, so the public key of root is stored at this location:

1. First become root:
   ```sh
   sudo -i
   ```

2. Set the long hostname:
   ```sh
   hostnamectl set-hostname "the-new-unique-long-hostname (fqdn, eg.: host1.example.net)"
   ```

3. Update Ubuntu:
   ```sh
   # DO NOT SKIP THIS STEP
   apt update; apt upgrade -y
   ```

4. Install git if needed:
   ```sh
   git --version > /dev/null || apt install git
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
           -C "$(date +%Y%m%d):root@$(hostname -b)" \
       && cat "/root/.ssh/id_ed25519.pub")
   ```

   This key has to be registerd via gitea web ui as deploy key into the repositories as documented in chapter "Register public host key".



### Register public host key
This is an example for `example.net` as domain of the host owner.

1. Repository `iss`, allow __readonly__ access only.
2. Repository `iss-definition-example.net`, allow __readonly__ access only.
3. Repository `iss-state-example.net`, allow __writable__ access.



### Clone the Infrastructure System (iss) repository
After you registered the printed root's public key of this host you can clone the repository and execute the setup script:
```sh
# Note the tailing '/iss', because we want to clone the repository to that folder
git clone ssh://git@git.example.dev:22448/iss.git /iss

# Execute the setup script
/iss/setupCoreOntoThisHost.sh
```

<br>
<br>
<br>

How it works
------------
We add a webhook to each gitea repository that belongs to ISS:
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
        -C "$(date +%Y%m%d):$(whoami)@$(echo ${JENKINS_URL} | cut -d/ -f3)" \
    && cat "${JENKINS_HOME}/.ssh/id_ed25519.pub")

# add your host here, note the tailing '&' to run it in parallel
ssh -o StrictHostKeyChecking=no jenkins@192.168.X.Y /iss/update_repositories.sh ( --scripts | --definitions | --states ) &

#wait for all background processes to complete
wait
echo "All complete"
```

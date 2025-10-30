#/bin/bash

function createEnvironmentFile() {
    local _ENVIRONMENT_FILE _REPOSITORY_FOLDER
    _ENVIRONMENT_FILE="${ENVIRONMENT_FILE:?"createEnvironmentFile(): Missing global parameter ENVIRONMENT_FILE"}"
    _REPOSITORY_FOLDER="${AUTOACME_REPOSITORY_FOLDER:?"createEnvironmentFile(): Missing global parameter AUTOACME_REPOSITORY_FOLDER"}"
    readonly _ENVIRONMENT_FILE _REPOSITORY_FOLDER

    # Save environment for cronjob
    export -p | grep -v -E "(HOME|OLDPWD|PWD|SHLVL)" > "${_ENVIRONMENT_FILE}" \
        && echo "SUCCESS: there values were exported into file: '${_ENVIRONMENT_FILE}'" \
        && echo "  - AUTOACME_CONTAINER_HOSTNAME: ${AUTOACME_CONTAINER_HOSTNAME}" \
        && echo "  - AUTOACME_DNS_PROVIDER: ${AUTOACME_DNS_PROVIDER}" \
        && echo "  - AUTOACME_GIT_REPOSITORY_VIA_SSH: ${AUTOACME_GIT_REPOSITORY_VIA_SSH}" \
        && echo "  - AUTOACME_PATH_IN_GIT_REPOSITORY: ${AUTOACME_PATH_IN_GIT_REPOSITORY}"

    [ "${AUTOACME_GIT_REPOSITORY_VIA_SSH}" == "" ] \
        && echo "declare -x AUTOACME_RESULT_CERTS=\"${AUTOACME_REPOSITORY_FOLDER#/}\"" >> "${_ENVIRONMENT_FILE}" \
        && echo "SUCCESS: added AUTOACME_RESULT_CERTS (without git) into file '${_ENVIRONMENT_FILE}'." \
        && echo "  - AUTOACME_RESULT_CERTS: ${AUTOACME_REPOSITORY_FOLDER#/}" \
        && echo "        (depends on if there is a git repo and the path for the certs in it)"

    ! [ "${AUTOACME_GIT_REPOSITORY_VIA_SSH}" == "" ] \
        && echo "declare -x AUTOACME_RESULT_CERTS=\"${AUTOACME_REPOSITORY_FOLDER}${AUTOACME_PATH_IN_GIT_REPOSITORY#/}\"" >> "${_ENVIRONMENT_FILE}" \
        && echo "SUCCESS: added AUTOACME_RESULT_CERTS (with git) into file '${_ENVIRONMENT_FILE}'." \
        && echo "  - AUTOACME_RESULT_CERTS: ${AUTOACME_REPOSITORY_FOLDER}${AUTOACME_PATH_IN_GIT_REPOSITORY#/}" \
        && echo "        (depends on if there is a git repo and the path for the certs in it)"

    return 0
}

function ensureThereAreSSHKeys() {
    grep -F 'ssh' "/root/.ssh/id_ed25519.pub" &> /dev/null \
        && echo "SUCCESS: ssh-keys found, printing public key:" \
        && cat "/root/.ssh/id_ed25519.pub" \
        && return 0

    # -t    type of the key pair
    # -f    defines the filenames (we use the standard for the selected type here)
    # -q    quiet, no output or interaction
    # -N "" means the private key will not be secured by a passphrase
    # -C    defines a comment
    ssh-keygen \
        -t ed25519 \
        -f "/root/.ssh/id_ed25519" -q -N "" \
        -C "$(date +%Y%m%d)-root@$(hostname -s)_onHost_${AUTOACME_CONTAINER_HOSTNAME%%.*}"

    grep -F 'ssh' "/root/.ssh/id_ed25519.pub" &> /dev/null \
        && echo "SUCCESS: ssh-keys generated, printing public key:" \
        && cat "/root/.ssh/id_ed25519.pub" \
        && return 0

    echo
    echo "FAILED: something went wrong during the generation of the ssh keys..."
    echo "        These keys are mandantory to access the git repository."
    echo "You can try to restart this script."
    echo
    return 1
}

function ensureGitIsInstalled() {
    git --version &> /dev/null \
        && return 0

    echo \
        && echo "Installing Git in 30s (ensure the SSH-Key is trusted and has write pemissions)... " \
        && sleep 30 \
        && DEBIAN_FRONTEND=noninteractive \
        && apt-get install git -y &> /dev/null \
        && echo "SUCCESS: $(git --version) is usable now." \
        && return 0

    echo
    echo "FAILED: something went wrong during the installation of Git..."
    echo "        Git is mandantory to push the keys into the specified repository."
    echo "You can try to install git manually (apt install git)."
    echo
    return 1
}

function ensureRepositoryIsAvailableAndWritable() {
    local _REPOSITORY_FOLDER
    _REPOSITORY_FOLDER="${AUTOACME_REPOSITORY_FOLDER:?"ensureRepositoryIsAvailableAndWritable(): Missing global parameter AUTOACME_REPOSITORY_FOLDER"}"
    readonly _REPOSITORY_FOLDER

    [ -d "${_REPOSITORY_FOLDER}.git" ] \
        && echo \
        && git -C "${_REPOSITORY_FOLDER}" pull &> /dev/null \
        && git -C "${_REPOSITORY_FOLDER}" push --dry-run &> /dev/null \
        && echo "Writable repository found in folder '${_REPOSITORY_FOLDER}'." \
        && return 0

    ! [ -d "${_REPOSITORY_FOLDER}.git" ] \
        && echo \
        && echo "Cloning repository '${AUTOACME_GIT_REPOSITORY_VIA_SSH}'... " \
        && GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone "${AUTOACME_GIT_REPOSITORY_VIA_SSH}" "${_REPOSITORY_FOLDER}" &> /dev/null \
        && git -C "${_REPOSITORY_FOLDER}" config user.name "autoacme on ${AUTOACME_CONTAINER_HOSTNAME%%.*}" \
        && git -C "${_REPOSITORY_FOLDER}" config user.email "autoacme@${AUTOACME_CONTAINER_HOSTNAME%%.*}" \
        && git -C "${_REPOSITORY_FOLDER}" push --dry-run &> /dev/null \
        && echo "SUCCESS: repository cloned into folder '${_REPOSITORY_FOLDER}' and it is writable." \
        && return 0

    echo
    echo "FAILED: something went wrong during cloning the repository to '${_REPOSITORY_FOLDER}' from:"
    echo "        - ${AUTOACME_GIT_REPOSITORY_VIA_SSH}"
    echo
    echo "1.) You can try to clone it manually into:  git clone ${AUTOACME_GIT_REPOSITORY_VIA_SSH} '${_REPOSITORY_FOLDER}'"
    echo "2.) Check if the repositoty is writable:    git -C '${_REPOSITORY_FOLDER}' push --dry-run"
    return 1
}

function prepareThisRuntimeForUsingGitOrIgnore() {
    createEnvironmentFile \
        || return 1

    [ "${AUTOACME_GIT_REPOSITORY_VIA_SSH}" == "" ] \
        && echo "There is no git repository specified." \
        && echo "To distribute all keys and certificates via a git repository set environment variable:" \
        && echo "  - AUTOACME_GIT_REPOSITORY_VIA_SSH" \
        && echo \
        && echo "FIRST AND ONLY WARNING: DO NOT USE ANY PUBLIC GIT SERVICE FOR THAT!" \
        && echo \
        && return 0

    echo \
        && ensureThereAreSSHKeys \
        && ensureGitIsInstalled \
        && ensureRepositoryIsAvailableAndWritable \
        && return 0

    echo "No job will run inside this container because there is an issue."
    echo "The container keeps running for 10min, please check your setup..."
    return 1
}

AUTOACME_REPOSITORY_FOLDER="/root/acmeResults/"
ENVIRONMENT_FILE="/autoACME.env"

echo
echo '################################################################################'
echo "# Container started at $(date +%F_%T) on host ${AUTOACME_CONTAINER_HOSTNAME}"
echo '################################################################################'
echo

# Log start and truncate file: /autoACME.log
echo > /autoACME.log

# Generate SSH keys and setup Git if a repository is specified, on failure keep the container running
prepareThisRuntimeForUsingGitOrIgnore \
    || timeout --preserve-status 10m tail -f /autoACME.log

# Ensure acme.sh ist installed
/renewCerts.sh --setup >> /autoACME.log \
    && echo >> /autoACME.log

echo "Register following entry to crontab:" >> /autoACME.log
echo "------------------------------------" >> /autoACME.log
_CRON_ENTRY="$((RANDOM % 59)) $((RANDOM % 5)) * * * /renewCerts.sh --dns --own >> /autoACME.log 2>&1"
echo "${_CRON_ENTRY}" | tee -a /autoACME.log | crontab -

cron && tail -n 100 -f /autoACME.log

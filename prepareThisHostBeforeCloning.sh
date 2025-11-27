#!/bin/bash

[ "$(id -u)" != "0" ] \
    && echo "This script prepares the user 'root' of this host and the host itself," \
    && echo "so this script is allowed to be executed if you are root only." \
    && exit 1

function setNeededHostnameOrExit() {
    _FQDN="${1:?"Missing unique long hostname (fqdn, eg.: host1.example.net) for this host as first parameter."}"

    echo "${_FQDN}" | grep -F '.' &> /dev/null \
        && hostnamectl set-hostname "${_FQDN}" \
        && return 0

    echo "FAILED: setting full qualified domain name does not contain a domain,"
    echo "        given value was: ${_FQDN}"
    exit 1
}

function prepareThisHost() {
    git --version > /dev/null || (apt update; apt upgrade -y; apt install git)

    echo
    echo "Public SSH-Key for root@$(hostname -b):"
    cat "/root/.ssh/id_ed25519.pub" \
        && return 0

    # -t    type of the key pair
    # -f    defines the filenames (we use the standard for the selected type here)
    # -q    quiet, no output or interaction
    # -N "" means the private key will not be secured by a passphrase
    # -C    defines a comment
    ssh-keygen \
        -t ed25519 \
        -f "/root/.ssh/id_ed25519" -q -N "" \
        -C "$(date +%Y%m%d)-root@$(hostname -b)"

    cat "/root/.ssh/id_ed25519.pub" \
        && return 0

    echo
    echo "FAILED: somthing went wrong during the generation the ssh keys."
    echo "        These keys are mandantory. You can try to restart this script."
    echo
}

function showFurtherSteps() {}
    echo
    echo "IMPORTANT: It is assumed that repositories for definitions and states already exist"
    echo "           and comply with the naming convention."
    echo "  Otherwise, these repositories must be created first!"
    echo
    echo "To grant the correct access rights, you have to register the above-mentioned ssh key,"
    echo "as deploy key in these repositories of the Git server:"
    echo "  - scripts repository     (allow readonly access only),"
    echo "  - definitions repository (allow readonly access only),"
    echo "  - states repository      (allow writable access)."
    echo
    echo "After all access rights are granted you can clone the Core Infrastructure System:"
    echo "  e.g.: git clone ssh://git@git.example.dev:22448/cis.git /cis"
    echo
    echo "Finally call 'setupCoreOntoThisHost.sh' from the root directory:"
    echo "  e.g.: /cis/setupCoreOntoThisHost.sh"
    echo
}

# sanitizes all parameters
setNeededHostnameOrExit "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && prepareThisHost \
    && showFurtherSteps \
    && exit 0

exit 1

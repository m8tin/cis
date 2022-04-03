#!/bin/bash

[ "$(id -u)" != "0" ] \
    && echo "This script prepares the user 'root' of this host and the host itself," \
    && echo "so this script is allowed to be executed if you are root only." \
    && exit 1

function setNeededHostnameOrExit() {
    _FQDN="${1:?"Missing unique long hostname (fqdn, eg.: host1.example.net) for this host as first parameter."}"

    echo "${_FQDN}" | grep '\.' &> /dev/null \
        && hostnamectl set-hostname "${_FQDN}" \
        && return 0

    echo "FAILED: setting full qualified domain name, given value was:"
    echo "  - ${_FQDN}"
    exit 1
}

function prepare() {
    git --version > /dev/null || (apt update; apt upgrade -y; apt install git)

    echo
    echo "Public SSH-Key for root@$(hostname -b):"
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

    echo
    echo "Now you have to register the public ssh-key from above into your git-server to grant these access rights:"
    echo "  - scripts repository     (allow readonly access only),"
    echo "  - definitions repository (allow readonly access only),"
    echo "  - states repository      (allow writable access)."
    echo
    echo "After all access rights are granted you can clone the Infrastructure System:"
    echo "  e.g.: git clone ssh://git@git.example.dev:22448/iss.git /iss"
    echo
    echo "Finally call 'setupCoreOntoThisHost.sh' from the root directory of the repository:"
    echo "  e.g.: /iss/setupCoreOntoThisHost.sh"
    echo
}

# sanitizes all parameters
setNeededHostnameOrExit "$(echo ${1} | sed -E 's|[^a-zA-Z0-9/:@._-]*||g')" \
    && prepare

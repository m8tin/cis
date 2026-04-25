#!/bin/bash

[ "$(id -u)" != "0" ] \
    && echo "This script prepares the user 'root' of this host and the host itself," \
    && echo "so this script is allowed to be executed if you are root only." \
    && exit 1

function goOn() {
    local _QUESTION="${1:?"goOn(): Mising first parameter QUESTION"}"
    local _TIPP="${2}"
    local _ANSWER

    read -p "${_QUESTION}: [y]es or [n]o : " _ANSWER
    [ "${_ANSWER}" == "y" ] && return 0
    [ "${_ANSWER}" == "Y" ] && return 0
    [ "${_ANSWER}" == "yes" ] && return 0
    [ "${_ANSWER}" == "Yes" ] && return 0
    [ "${_ANSWER}" == "YES" ] && return 0

    echo
    echo "${_TIPP}"
    echo
    return 1
}

function setNeededHostnameOrExit() {
    _FQDN="${1}"

    [ -z "${_FQDN}" ] \
        && ! echo "$(hostname -b)" | grep -q -F '.' \
        && echo "This host needs a unique long hostname (fqdn, eg.: host1.example.net)" \
        && echo "Call this script with a full qualified domain name as first parameter." \
        && exit 1

    [ -z "${_FQDN}" ] \
        && echo "$(hostname -b)" | grep -q -F '.' \
        && echo "The name of this host is: $(hostname -b)" \
        && goOn "Is this correct?" "Restart this script with a full qualified domain name as first parameter." \
        && return 0

    [ "${_FQDN}" == "$(hostname -b)" ] \
        && echo "Name of this host already is: $(hostname -b)" \
        && return 0

    echo "${_FQDN}" | grep -F '.' &> /dev/null \
        && "Setting name of this host to: ${_FQDN}" \
        && hostnamectl set-hostname "${_FQDN}" \
        && return 0

    echo "FAILED: the specified fully qualified domain name does not contain a domain,"
    echo "        given value was: ${_FQDN}"
    exit 1
}

function printOrGenerateSSHKeys() {
    git --version > /dev/null || (apt update; apt upgrade -y; apt install git)

    local _FULL_USERNAME="$(whoami)@$(hostname -b)"
    local _PUBKEY_FILE=~/.ssh/id_ed25519.pub

    echo
    echo "Printing public SSH-Key of ${_FULL_USERNAME}:"
    echo "  - Content of '${_PUBKEY_FILE}':"
    cat "${_PUBKEY_FILE}" \
        && return 0

    # -t    type of the key pair
    # -f    defines the filenames (we use the standard for the selected type here)
    # -q    quiet, no output or interaction
    # -N "" means the private key will not be secured by a passphrase
    # -C    defines a comment
    ssh-keygen \
        -t ed25519 \
        -f "${_PUBKEY_FILE}" -q -N "" \
        -C "$(date +%Y%m%d)-${_FULL_USERNAME}"

    cat "${_PUBKEY_FILE}" \
        && return 0

    echo
    echo "FAILED: somthing went wrong during the generation the ssh keys for '${_FULL_USERNAME}'."
    echo "        These keys are mandantory. You can try to restart this script."
    echo
}

function showFurtherSteps() {
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
    && printOrGenerateSSHKeys \
    && showFurtherSteps \
    && exit 0

exit 1

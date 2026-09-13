#!/bin/bash



function checkPreconditions() {
    ! checkTPM \
        && echo >&2 \
        && echo "TPM 2.0 device missing." >&2 \
        && return 1

    ! checkTools \
        && echo >&2 \
        && echo 'TPM tools missing. Setup via: "apt install tpm2-tools"' >&2 \
        && return 1

    return 0
}

function checkSafe() {
    printf -- "%s" 'Checking TPM derived safe ... ' >&2 \
        && [ -f /root/tpm/aes-key-safe.priv ] \
        && [ -f /root/tpm/aes-key-safe.pub ] \
        && printf -- "%s\n" '(found)' >&2 \
        && return 0

    printf -- "%s\n" '(missing)' >&2
    return 1
}

function checkTools() {
    printf -- "%s" 'Checking TPM tools ... ' >&2 \
        && tpm2_createprimary --version > /dev/null 2>&1 \
        && tpm2_create --version > /dev/null 2>&1 \
        && tpm2_load --version > /dev/null 2>&1 \
        && tpm2_unseal --version > /dev/null 2>&1 \
        && printf -- "%s\n" '(installed)' >&2 \
        && return 0

    return 1
}

function checkTPM() {
    printf -- "%s" 'Checking TPM device ... ' >&2 \
        && [ -f /sys/class/tpm/tpm0/tpm_version_major ] \
        && [ $(cat /sys/class/tpm/tpm0/tpm_version_major) -ge 2 ] 2> /dev/null \
        && printf -- "%s\n" '(available)' >&2 \
        && return 0

    return 1
}

function checkOrCreateSafe() {
    checkSafe \
        && return 0

    [ -f /root/tpm/aes-key-safe.priv ] \
        && echo 'ABORT existing safe file found: "/root/tpm/aes-key-safe.priv"' >&2 \
        && return 1

    [ -f /root/tpm/aes-key-safe.pub ] \
        && echo 'ABORT existing safe file found: "/root/tpm/aes-key-safe.pub"' >&2 \
        && return 1

    printf -- "%s" 'Creating TPM derived safe ... ' >&2
    umask 077
    mkdir -p /root/tpm
    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    openssl rand 32 | tpm2_create -C /tmp/primary.ctx -Q -i - -r /root/tpm/aes-key-safe.priv -u /root/tpm/aes-key-safe.pub \
        && [ -f /root/tpm/aes-key-safe.priv ] \
        && [ -f /root/tpm/aes-key-safe.pub ] \
        && printf -- "%s\n" '(done)' >&2 \
        && return 0

    echo 'FAILURE: unable to provide a usable safe.' >&2
    return 1
}

function seal() {
    ! chmod -R go-rwx /dev/shm/host/secret/* \
        && return 1

    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    [ -f /tmp/safe.ctx ] || tpm2_load \
        -C /tmp/primary.ctx -Q \
        -r /root/tpm/aes-key-safe.priv \
        -u /root/tpm/aes-key-safe.pub \
        -c /tmp/safe.ctx
    umask 077
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in <(tar -czvf - /dev/shm/host/secret/*) \
        -out /root/tpm/host_secrets.tar.gz.aes \
        -pass file:<(tpm2_unseal -c /tmp/safe.ctx)
}

function unseal() {
    ! [ -f /root/tpm/host_secrets.tar.gz.aes ] \
        && return 1

    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    [ -f /tmp/safe.ctx ] || tpm2_load \
        -C /tmp/primary.ctx -Q \
        -r /root/tpm/aes-key-safe.priv \
        -u /root/tpm/aes-key-safe.pub \
        -c /tmp/safe.ctx
    openssl enc -d -aes-256-cbc -pbkdf2 \
        -in /root/tpm/host_secrets.tar.gz.aes \
        -out - \
        -pass file:<(tpm2_unseal -c /tmp/safe.ctx) | tar -xzvf - -C /
}

function usage() {
    echo
    echo 'Commands:'
    echo '  --seal          : This will save the secrets of this host in a secure way.'
    echo '                       A safe is created automatically and will not be overwritten,'
    echo '                       you have to delete both safe files to replace an existing safe,'
    echo '                       BUT you will loose access to the AES key inside, so BE CAREFUL!'
    echo '  --unseal        : This restores the secrets after a reboot.'

    return 0
}



checkPreconditions || exit 1

case "${1}" in
    --seal)
        checkOrCreateSafe \
            && seal \
            && exit 0
        ;;
    --unseal)
        checkSafe \
            && unseal \
            && exit 0
        ;;
    *)
        echo "Unknown command '${1}'"
        usage
        exit 1
        ;;
esac

exit 1

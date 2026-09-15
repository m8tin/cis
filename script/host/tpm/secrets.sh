#!/bin/bash

AES_STORE_FILE=~/tpm/aes-key-safe
SECRETS_STORE_FILE=~/tpm/secrets
SECRETS_PLAIN_PATH=/run/user/$(id -u)/secrets/



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
        && [ -f "${AES_STORE_FILE}" ] \
        && [ -f "${AES_STORE_FILE}.pub" ] \
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

    [ -f "${AES_STORE_FILE}" ] \
        && echo 'ABORT existing safe file found: "${AES_STORE_FILE}"' >&2 \
        && return 1

    [ -f "${AES_STORE_FILE}.pub" ] \
        && echo 'ABORT existing safe file found: "${AES_STORE_FILE}.pub"' >&2 \
        && return 1

    printf -- "%s" 'Creating TPM derived safe ... ' >&2
    mkdir -p "$(dirname "${AES_STORE_FILE}")"
    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    openssl rand 32 | tpm2_create -C /tmp/primary.ctx -Q -i - -r "${AES_STORE_FILE}" -u "${AES_STORE_FILE}.pub" \
        && checkSafe \
        && return 0

    echo 'FAILURE: unable to provide a usable safe.' >&2
    return 1
}

function seal() {
    # Ensure all secrets have restricte permissions before tar
    ! chmod -R go-rwx "${SECRETS_PLAIN_PATH}" \
        && return 1

    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    [ -f /tmp/safe.ctx ] || tpm2_load \
        -C /tmp/primary.ctx -Q \
        -r "${AES_STORE_FILE}" \
        -u "${AES_STORE_FILE}.pub" \
        -c /tmp/safe.ctx
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in <(tar -czvf - "${SECRETS_PLAIN_PATH%/}/"*) \
        -out "${SECRETS_STORE_FILE}.tar.gz.aes" \
        -pass file:<(tpm2_unseal -c /tmp/safe.ctx)
}

function unseal() {
    ! [ -f "${SECRETS_STORE_FILE}.tar.gz.aes" ] \
        && return 1

    ! mkdir -m 1700 -p "${SECRETS_PLAIN_PATH}" \
        && return 1

    [ -f /tmp/primary.ctx ] || tpm2_createprimary -C o -Q -c /tmp/primary.ctx
    [ -f /tmp/safe.ctx ] || tpm2_load \
        -C /tmp/primary.ctx -Q \
        -r "${AES_STORE_FILE}" \
        -u "${AES_STORE_FILE}.pub" \
        -c /tmp/safe.ctx
    openssl enc -d -aes-256-cbc -pbkdf2 \
        -in "${SECRETS_STORE_FILE}.tar.gz.aes" \
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

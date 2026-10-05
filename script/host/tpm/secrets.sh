#!/bin/bash

AES_STORE_FILE=~/tpm/aes-key-safe
SECRETS_STORE_FILE=~/tpm/secrets
SECRETS_PLAIN_PATH="/run/secrets/$(id -u)/"



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
    tpm2_createprimary -C o -Q -c "${TMPDIR%/}/primary.ctx"
    openssl rand 32 | tpm2_create -C "${TMPDIR%/}/primary.ctx" -Q -i - -r "${AES_STORE_FILE}" -u "${AES_STORE_FILE}.pub" \
        && checkSafe \
        && return 0

    echo 'FAILURE: unable to provide a usable safe.' >&2
    return 1
}

function prepareRestrictedTmpfsDirectoryFromPath() {
    # Startet mit /, endet mit /, mindestens 3 Schrägstriche
    if [[ "${1:?"prepareRestrictedTmpfsDirectoryFromPath(): Missing first parameter PATH (with tailing '/')"}" =~ ^/.*([^/]+/){2,}$ ]]; then
        local _PATH="${1%/*}"
        local _BASE="${_PATH%/*}"

        mkdir -p -m 1777 "${_BASE}"
        ! df --output=fstype "${_BASE}" | grep -qF 'tmpfs' \
            && return 1

        ! [[ "$(stat -c "%a" "${_BASE}")" == "1777" ]] \
            && return 1

        mkdir -p -m 700 "${_PATH}"
        ! [[ "$(stat -c "%a" "${_PATH}")" == "700" ]] \
            && return 1

        return 0
    fi
    return 1
}

function seal() {
    # Ensure all secrets have restricte permissions before tar
    ! chmod -R go-rwx "${SECRETS_PLAIN_PATH}" \
        && return 1

    tpm2_createprimary -C o -Q -c "${TMPDIR%/}/primary.ctx"
    tpm2_load \
        -C "${TMPDIR%/}/primary.ctx" -Q \
        -r "${AES_STORE_FILE}" \
        -u "${AES_STORE_FILE}.pub" \
        -c "${TMPDIR%/}/safe.ctx"
    openssl enc -aes-256-cbc -md sha256 -pbkdf2 -iter 600000 -salt \
        -in <(tar -czvf - -C "${SECRETS_PLAIN_PATH}" .) \
        -out "${SECRETS_STORE_FILE}.tar.gz.aes" \
        -pass file:<(tpm2_unseal -c "${TMPDIR%/}/safe.ctx")
}

function unseal() {
    ! [ -f "${SECRETS_STORE_FILE}.tar.gz.aes" ] \
        && return 1

    ! prepareRestrictedTmpfsDirectoryFromPath "${SECRETS_PLAIN_PATH}" \
        && return 1

    tpm2_createprimary -C o -Q -c "${TMPDIR%/}/primary.ctx"
    tpm2_load \
        -C "${TMPDIR%/}/primary.ctx" -Q \
        -r "${AES_STORE_FILE}" \
        -u "${AES_STORE_FILE}.pub" \
        -c "${TMPDIR%/}/safe.ctx"
    openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 600000 \
        -in "${SECRETS_STORE_FILE}.tar.gz.aes" \
        -out - \
        -pass file:<(tpm2_unseal -c "${TMPDIR%/}/safe.ctx") | tar -xzvf - --no-overwrite-dir -C "${SECRETS_PLAIN_PATH}"
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
        TMPDIR=$(mktemp -d --suffix .tpm.context)
        trap 'rm -rf "${TMPDIR:?"Missing TMPDIR"}"; echo "Sealing finished, TMPDIR removed: ${TMPDIR}"' EXIT
        checkOrCreateSafe \
            && seal \
            && exit 0
        ;;
    --unseal)
        TMPDIR=$(mktemp -d --suffix .tpm.context)
        trap 'rm -rf "${TMPDIR:?"Missing TMPDIR"}"; echo "Unsealing finished, TMPDIR removed: ${TMPDIR}"' EXIT
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

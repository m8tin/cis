#!/bin/bash

# curl http://your.domain.net/.well-known/acme-challenge/test
# curl http://85.183.145.8/.well-known/acme-challenge/test
# /var/www/letsencrypt/.well-known/acme-challenge

function checkConfigViaHttp() {
    local _DOMAIN _MODE _LOCAL_FOLDER
    _MODE="${1:?"checkConfigViaHttp(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"checkConfigViaHttp(): Missing second parameter DOMAIN"}"
    _LOCAL_FOLDER="/var/www/letsencrypt/.well-known/acme-challenge/"
    readonly _DOMAIN _MODE _LOCAL_FOLDER

    local _LOCAL_FILE _LOCAL_URL _PUBLIC_URL
    _LOCAL_FILE="${_LOCAL_FOLDER}${_DOMAIN}"
    _LOCAL_URL="http://localhost/.well-known/acme-challenge/${_DOMAIN}"
    _PUBLIC_URL="http://${_DOMAIN}/.well-known/acme-challenge/${_DOMAIN}"
    readonly _LOCAL_FILE _LOCAL_URL _PUBLIC_URL

    # Skip check if mode is not http
    [ "${_MODE}" != "http" ] \
        && return 0

    # Fail because wildcard certificate
    [ "${_MODE}" == "http" ] \
        && isWildcardCertificate "${_DOMAIN}" \
        && echo "Wildcard certificates are not supported via HTTP." \
        && return 1

    _CHECK="Available on $(hostname)@$(date)"

    echo -n "Check domain '${_DOMAIN}'..." \
        && [ -d "${_LOCAL_FOLDER}" ] \
        && echo "${_CHECK}" > "${_LOCAL_FILE}" \
        && curl -4s "${_PUBLIC_URL}" | grep -q "${_CHECK}" \
        && echo " Done" \
        && return 0

    echo
    echo "FAILED: configuration of domain '${_DOMAIN}' is INCORRECT:"
    echo -n "  ${_PUBLIC_URL} was not found."

    curl -4s "${_LOCAL_URL}" | grep -q "${_CHECK}" \
        && echo " (check DNS first)" \
        || echo " (check Webserver first)"

    return 1
}

function isActive() {
    local _DOMAIN _MODE _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"isActive(): Missing global parameter RESULT_CERTS"}"
    _MODE="${1:?"isActive(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"isActive(): Missing second parameter DOMAIN"}"
    readonly _DOMAIN _MODE _RESULT_CERTS

    # If mode is dns the domain is active always
    [ "${_MODE}" == "dns" ] \
        && return 0

    nginx -T 2> /dev/null | grep -q "${_RESULT_CERTS}${_DOMAIN}/fullchain.crt" \
        && return 0

    echo "Domain '${_DOMAIN}' is inaktiv and therefore it will be skipped."
    return 1
}

function isGitRepository() {
    local _FOLDER
    _FOLDER="${1:?"isGitRepository(): Missing first parameter FOLDER"}"
    readonly _FOLDER

    git -C "${_FOLDER}" ls-tree main &> /dev/null \
        && return 0

    return 1
}

function isWildcardCertificate() {
    local _DOMAIN
    _DOMAIN="${1:?"isWildcardCertificate(): Missing first parameter DOMAIN"}"
    readonly _DOMAIN

    echo "${_DOMAIN}" | grep -q -F "_." \
        && return 0

    echo "${_DOMAIN}" | grep -q -F "*." \
        && return 0

    return 1
}

function tryGitPush() {
    local _DOMAIN _NOW _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"tryGitPush(): Missing global parameter RESULT_CERTS"}"
    _DOMAIN="${1:?"tryGitPush(): Missing first parameter DOMAIN"}"
    _NOW="$(date +%Y%m%d_%H%M)"
    readonly _DOMAIN _NOW _RESULT_CERTS

    ! isGitRepository "${_RESULT_CERTS}" \
        && echo \
        && echo "Folder '${_RESULT_CERTS}' is not part of a git repository, therefore nothing will be pushed." \
        && return 1

    pushd "${_RESULT_CERTS}" > /dev/null
    git pull > /dev/null
    git add * > /dev/null
    git commit -m "${_NOW} - Certificate for '${_DOMAIN}' was updated." \
        && git push > /dev/null \
        && popd > /dev/null \
        && echo "SUCCESS: certificate for '${_DOMAIN}' pushed." \
        && return 0

   popd > /dev/null
   echo "FAILED: unable to push certificate for '${_DOMAIN}'."
   return 0
}

function own() {
    ! [ -d "${RESULT_CERTS:?"own(): Missing global parameter RESULT_CERTS"}" ] \
        && echo "Trying to derive domain names from subfolders of '${RESULT_CERTS}', but it is not a folder!" \
        && return 1

    local _DOMAINS _MODE
    _DOMAINS=("${RESULT_CERTS}"*)
    _MODE="${1:?"own(): Missing first parameter MODE"}"
    readonly _DOMAINS _MODE

    local _domain
    for _domain in "${_DOMAINS[@]}"; do
        # just take names of folders
        ! [ -d "${_domain}" ] && continue
        # cut pfad (like basename)
        _domain="${_domain##*/}"

        # folder default => skip
        [ "${_domain}" == "default" ] && continue

        case "${_MODE}" in
            dns)
                # dns supports all options
                ;;
            http)
                # http and wildcard certifikate => skip
                isWildcardCertificate "${_domain}" && continue
                # ssl on domain inaktiv => skip
                ! isActive "{_MODE}" "${_domain}" && continue
                ;;
            *)
                echo "Unknown mode: ${_MODE}"
                return 1
                ;;
        esac

        single "${_MODE}" "${_domain}" "${2}"
    done

    return 0
}

function continueIssuingCertificate() {
    local _CERT_FILE_FULLCHAIN _DOMAIN
    _CERT_FILE_FULLCHAIN="${1:?"continueIssuingCertificate(): Missing first parameter CERT_FILE_FULLCHAIN"}"
    _DOMAIN="${2:?"continueIssuingCertificate(): Missing second parameter DOMAIN"}"
    local _CERT_FILE_FULLCHAIN _DOMAIN

    local _PRETTY_DOMAIN
    _PRETTY_DOMAIN="$(printPrettyDomain ${_DOMAIN})"
    readonly _PRETTY_DOMAIN

    # forced => should be issued
    [ "${3:-""}" == "--force" ] \
        && echo "Certificate for domain '${_PRETTY_DOMAIN}' is forced to be issued." \
        && return 0

    # no cert => should be issued
    ! [ -f "${_CERT_FILE_FULLCHAIN}" ] \
        && echo "No certificate for domain '${_PRETTY_DOMAIN}', so it will be issued." \
        && return 0

    local _ENDDATE _NOW _REMAINING_DAYS
    _ENDDATE="$(openssl x509 -enddate -noout -in ${_CERT_FILE_FULLCHAIN} | cut -d= -f2)"
    _ENDDATE="$(date --date="${_ENDDATE}" --utc +%s)"

    _NOW="$(date --date now +%s)"
    _REMAINING_DAYS="$(( (_ENDDATE - _NOW) / 86400 ))"
    readonly _ENDDATE _NOW _REMAINING_DAYS

    # less than 30 days remaining => should be issued
    [ "${_REMAINING_DAYS}" -le "30" ] \
        && echo "Certificate for domain '${_PRETTY_DOMAIN}' (${_REMAINING_DAYS} days remaining) will be issued." \
        && return 0

    echo "Certificate for domain '${_PRETTY_DOMAIN}' (${_REMAINING_DAYS} days remaining) will be skipped."
    return 1
}

function printBaseDomain() {
    local _DOMAIN
    _DOMAIN="${1:?"printBaseDomain(): Missing first parameter DOMAIN"}"
    readonly _DOMAIN

    local _BASE_DOMAIN
    # cut front '*.' or '_.'
    _BASE_DOMAIN="${_DOMAIN#\*.}"
    _BASE_DOMAIN="${_BASE_DOMAIN#_.}"
    readonly _BASE_DOMAIN

    echo "${_BASE_DOMAIN}" \
        && return 0

    return 1
}

function printPrettyDomain() {
    local _BASE_DOMAIN _DOMAIN
    _DOMAIN="${1:?"printPrettyDomain(): Missing first parameter DOMAIN"}"
    _BASE_DOMAIN="$(printBaseDomain ${_DOMAIN})"
    readonly _BASE_DOMAIN _DOMAIN

    isWildcardCertificate "${_DOMAIN}" \
        && echo "*.${_BASE_DOMAIN}" \
        && return 0

    echo "${_DOMAIN}" \
        && return 0

    return 1
}

function printFullDomainFolder() {
    local _BASE_DOMAIN _DOMAIN _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"printFullDomainFolder(): Missing global parameter RESULT_CERTS"}"
    _DOMAIN="${1:?"printFullDomainFolder(): Missing first parameter DOMAIN"}"
    _BASE_DOMAIN="$(printBaseDomain ${_DOMAIN})"
    readonly _BASE_DOMAIN _DOMAIN _RESULT_CERTS

    isWildcardCertificate "${_DOMAIN}" \
        && echo "${_RESULT_CERTS}_.${_BASE_DOMAIN}/" \
        && return 0

    echo "${_RESULT_CERTS}${_DOMAIN}/" \
        && return 0

    return 1
}

function prepareFullDomainFolder() {
    local _DOMAIN _DOMAIN_FOLDER
    _DOMAIN="${1:?"prepareFullDomainFolder(): Missing first parameter DOMAIN"}"
    _DOMAIN_FOLDER="$(printFullDomainFolder "${_DOMAIN}")"
    readonly _DOMAIN _DOMAIN_FOLDER

    [ -d "${_DOMAIN_FOLDER}" ] \
        && return 0

    # create folder for results
    echo -n "Creating folder '${_DOMAIN_FOLDER}'... " \
        && mkdir -p "${_DOMAIN_FOLDER}" \
        && echo "Done"

    [ -d "${_DOMAIN_FOLDER}" ] \
        && return 0

    return 1
}

function prepareAndCheckAliasDomain() {
    local _ALIAS_DOMAIN _DOMAIN
    _DOMAIN="${1:?"prepareAndCheckAliasDomain(): Missing first parameter DOMAIN"}"
    _ALIAS_DOMAIN="${2:?"prepareAndCheckAliasDomain(): Missing second parameter ALIAS_DOMAIN"}"
    readonly _ALIAS_DOMAIN _DOMAIN

    local _BASE_DOMAIN _CHALLENGE_ALIAS_DOMAIN_FILE _DOMAIN_FOLDER
    _BASE_DOMAIN="$(printBaseDomain ${_DOMAIN})"
    _DOMAIN_FOLDER="$(printFullDomainFolder ${_DOMAIN})"
    _CHALLENGE_ALIAS_DOMAIN_FILE="${_DOMAIN_FOLDER}challenge-alias-domain"
    readonly _BASE_DOMAIN _CHALLENGE_ALIAS_DOMAIN_FILE _DOMAIN_FOLDER

    [ -d "${_DOMAIN_FOLDER}" ] \
        && [ "$(dig +short _acme-challenge.${_BASE_DOMAIN} CNAME)" == "_acme-challenge.${_ALIAS_DOMAIN}." ] \
        && echo "${_ALIAS_DOMAIN}" > "${_CHALLENGE_ALIAS_DOMAIN_FILE}" \
        && echo "SUCCESS: alias domain '${_ALIAS_DOMAIN}' is used when issuing certificates for '${_BASE_DOMAIN}' via DNS." \
        && return 0

    echo "FAILED: unable to use alias domain '${_ALIAS_DOMAIN}' to issue certificates for '${_BASE_DOMAIN}'."
    echo "        You have to configure your domain '${_BASE_DOMAIN}' first before you can use the alias domain as proof."
    echo "        So check if there is a CNAME entry '_acme-challenge.${_BASE_DOMAIN}' pointing to:"
    echo "          - '_acme-challenge.${_ALIAS_DOMAIN}'"
    return 1
}

function single() {
    local _ACME_FILE _DOMAIN _MODE _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"single(): Missing global parameter RESULT_CERTS"}"
    _ACME_FILE="${ACME_FILE:?"single(): Missing global parameter ACME_FILE"}"
    _MODE="${1:?"single(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"single(): Missing second parameter DOMAIN"}"
    readonly _ACME_FILE _DOMAIN _MODE _RESULT_CERTS

    local _BASE_DOMAIN _CHALLENGE_ALIAS_DOMAIN_FILE _DOMAIN_FOLDER _PRETTY_DOMAIN
    _BASE_DOMAIN="$(printBaseDomain ${_DOMAIN})"
    _DOMAIN_FOLDER="$(printFullDomainFolder ${_DOMAIN})"
    _PRETTY_DOMAIN="$(printPrettyDomain ${_DOMAIN})"
    _CHALLENGE_ALIAS_DOMAIN_FILE="${_DOMAIN_FOLDER}challenge-alias-domain"
    readonly _BASE_DOMAIN _CHALLENGE_ALIAS_DOMAIN_FILE _DOMAIN_FOLDER _PRETTY_DOMAIN

    ! [ -f "${_ACME_FILE}" ] \
        && echo "Program 'acme.sh' seams not to be installed. Try run 'renewCerts.sh --setup'." \
        && return 1

    # cancel on broken configuration
    ! checkConfigViaHttp "${_MODE}" "${_DOMAIN}" \
        && return 1

    # cancel if folder is not prepared
    ! [ -d "${_DOMAIN_FOLDER}" ] \
	    && echo "Certificate of domain '${_PRETTY_DOMAIN}' skipped because of missing folder:" \
        && echo "  - '${_DOMAIN_FOLDER}'" \
        && return 1

    # check enddate if third parameter is not --force
    ! continueIssuingCertificate "${_DOMAIN_FOLDER}fullchain.crt" "${_DOMAIN}" "${3:-""}" \
        && return 0

    # backup the keys
    [ -f "${_DOMAIN_FOLDER}fullchain.crt" ] \
        && cp "${_DOMAIN_FOLDER}fullchain.crt" "${_DOMAIN_FOLDER}fullchain.crt.bak"
    [ -f "${_DOMAIN_FOLDER}private.key" ] \
        && cp --preserve=mode,ownership "${_DOMAIN_FOLDER}private.key" "${_DOMAIN_FOLDER}private.key.bak"

    local _OPTIONS
    # always --force because we check expiring on ourself
    # _OPTIONS="--issue --force --test"
    _OPTIONS="--issue --force"
    if [ "${_MODE}" == "dns" ]; then
        _OPTIONS="${_OPTIONS} --dns ${AUTOACME_DNS_PROVIDER:?"single(): Missing global parameter AUTOACME_DNS_PROVIDER"}"
        [ -f "${_CHALLENGE_ALIAS_DOMAIN_FILE}" ] \
            && _OPTIONS="${_OPTIONS} --challenge-alias $(cat "${_CHALLENGE_ALIAS_DOMAIN_FILE}")"
        isWildcardCertificate "${_DOMAIN}" \
            && _OPTIONS="${_OPTIONS} --domain ${_PRETTY_DOMAIN}"
    elif [ "${_MODE}" == "http" ]; then
        _OPTIONS="${_OPTIONS} --webroot /var/www/letsencrypt"
    fi
    readonly _OPTIONS

    ${_ACME_FILE} ${_OPTIONS} \
        --domain "${_BASE_DOMAIN}" \
        --server "letsencrypt" \
        --keylength "ec-384" \
        --fullchain-file "${_DOMAIN_FOLDER}fullchain.crt" \
        --key-file "${_DOMAIN_FOLDER}private.key" \
        && openssl pkcs12 -export -in "${_DOMAIN_FOLDER}fullchain.crt" -inkey "${_DOMAIN_FOLDER}private.key" -out "${_DOMAIN_FOLDER}bundle.pkx" -passout pass: \
        && echo "Certificate of domain '${_PRETTY_DOMAIN}' was updated." \
        && tryGitPush "${_PRETTY_DOMAIN}" \
        && return 0

    echo "Certificate of domain '${_PRETTY_DOMAIN}' remains unchanged."
    return 0
}

function isInstalled() {
    local _ACME_FILE
    _ACME_FILE="${ACME_FILE:?"isInstalled(): Missing global parameter ACME_FILE"}"
    readonly _ACME_FILE

    [ -f "${_ACME_FILE}" ] \
        && echo "Following version of acme.sh is installed:" \
        && echo "------------------------------------------" \
        && ${_ACME_FILE} --version | tail -n 1 \
        && return 0

    return 1
}

function extractTarArchive() {
    local _ACME_SETUP_FILE _ACME_TAR_FILE
    _ACME_SETUP_FILE="${ACME_SETUP_FILE:?"extractTarArchive(): Missing global parameter ACME_SETUP_FILE"}"
    _ACME_TAR_FILE="${ACME_TAR_FILE:?"extractTarArchive(): Missing global parameter ACME_TAR_FILE"}"
    readonly _ACME_SETUP_FILE _ACME_TAR_FILE

    # extracted file already exists
    [ -f "${_ACME_SETUP_FILE}" ] \
        && return 0

    [ -f "${_ACME_TAR_FILE}" ] \
        && mkdir -p "/tmp/acme.sh-setup/" \
        && tar -xzf "${_ACME_TAR_FILE}" -C "/tmp/acme.sh-setup/" \
        && [ -f "${_ACME_SETUP_FILE}" ] \
        && return 0

    echo "Missing setup file '${_ACME_SETUP_FILE}' after trying to extract '${_ACME_TAR_FILE}'"
    return 1
}

function setup() {
    local _ACME_SETUP_FILE
    _ACME_SETUP_FILE="${ACME_SETUP_FILE:?"setup(): Missing global parameter ACME_SETUP_FILE"}"
    readonly _ACME_SETUP_FILE

    isInstalled \
        && return 0

    ! [ $(id -u) == 0 ] \
        && echo "Setup requires execution as user 'root'." \
        && exit 1

    ! [ "$(echo $HOME)" == "/root" ] \
        && echo "The setup is executed with 'root' privileges but not in the 'root' user environment." \
        && exit 1

    ! extractTarArchive \
        && exit 1

    echo "Starting install of acme.sh:"
    echo "----------------------------"
    pushd "${_ACME_SETUP_FILE%/*}" > /dev/null 2>&1    #Removes shortest matching pattern '/*' from the end
    ./acme.sh --install --no-cron --no-profile 2>&1
    popd > /dev/null 2>&1
    isInstalled \
        && echo \
        && echo 'Now this script can be added into cron-tab (crontab -e), like this e.g.:' \
        && echo \
        && echo '# Each day at 6:00am renew certificates:' \
        && echo '0 6 * * * /renewCerts.sh --http --own > /var/log/renewCerts.sh.log 2>&1' \
        && return 0

    echo "Something went wrong during setup."
    return 1
}

function usage() {
    echo
    echo 'Commands:'
    echo '  --prepare DOMAIN --usingAlias ALIAS-DOMAIN  : Prepares a domain to issue certificate using an alias domain in DNS mode.'
    echo '                                                    See: https://github.com/acmesh-official/acme.sh/wiki/DNS-alias-mode'
    echo '  --dns            --single DOMAIN [--force]  : Issues a certificate for the given domain using DNS mode.'
    echo '  --http           --single DOMAIN [--force]  : Issues a certificate for the given domain using HTTP mode.'
    echo
    echo ' (--dns|--http)    --own [--force]            : Iterates all domains found in RESULT_CERTS.'
    echo
    echo 'Current environment:'
    echo "    Full name of this script:                      OWN_FULLNAME='${OWN_FULLNAME}'"
    echo "  Configuration:"
    echo "    Version of 'acme.sh' that will be installed:   ACME_VERSION='${ACME_VERSION}'"
    echo "    Tar file containing the setup of 'acme.sh':    ACME_TAR_FILE='${ACME_TAR_FILE}'"
    echo "    Setup file of 'acme.sh' after extraction:      ACME_SETUP_FILE='${ACME_SETUP_FILE}'"
    echo "    Full name of the installed script 'acme.sh':   ACME_FILE='${ACME_FILE}'"
    echo "  Output:"
    echo "    Path were the issued certificate are saved:    RESULT_CERTS='${RESULT_CERTS}'"

    return 0
}

function main() {

    echo

    [ -f "/autoACME.env" ] \
        && source "/autoACME.env" \
        && echo "[$(date)] Environment '/autoACME.env' loaded."

    local ACME_FILE ACME_VERSION OWN_FULLNAME
    OWN_FULLNAME="$(readlink -e ${0})"
    ACME_FILE="/root/.acme.sh/acme.sh"
    ACME_VERSION="acme.sh-3.1.1"
    readonly ACME_FILE ACME_VERSION OWN_FULLNAME

    local ACME_SETUP_FILE ACME_TAR_FILE RESULT_CERTS
    ACME_SETUP_FILE="/tmp/acme.sh-setup/${ACME_VERSION}/acme.sh"
    ACME_TAR_FILE="${OWN_FULLNAME%/*}/${ACME_VERSION}.tar.gz"
    RESULT_CERTS="${AUTOACME_RESULT_CERTS%/}"    #Removes shortest matching pattern '/' from the end
    RESULT_CERTS="${RESULT_CERTS:-"/etc/nginx/ssl"}/"
    readonly ACME_SETUP_FILE ACME_TAR_FILE RESULT_CERTS

    local REPOSITORY_URL
    isGitRepository "${RESULT_CERTS}" \
        && REPOSITORY_URL="$(git -C ${RESULT_CERTS} config --get remote.origin.url)"
    readonly REPOSITORY_URL

    case "${1}" in
        --dns)
            case "${2}" in
                --single)
                    echo "[$(date)] Issue single certificate '${3}' via DNS:" \
                        && prepareFullDomainFolder "${3}" \
                        && single "dns" "${3}" "${4}" \
                        && return 0
                    ;;
                --own)
                    echo "[$(date)] Renewing own certificates via DNS:"
                    own "dns" "${3}" \
                        && echo "Finished successfully." \
                        && return 0
                    ;;
            esac
            ;;
        --http)
            case "${2}" in
                --single)
                    echo "[$(date)] Issue single certificate '${3}' via HTTP:" \
                        && prepareFullDomainFolder "${3}" \
                        && single "http" "${3}" "${4}" \
                        && echo \
                        && echo "Checking configuration of nginx and restart the webserver:" \
                        && echo "==========================================================" \
                        && nginx -t && systemctl reload nginx \
                        && return 0
                    ;;
                --own)
                    echo "[$(date)] Renewing own certificates via HTTP:" \
                        && own "http" "${3}" \
                        && echo \
                        && echo "Checking configuration of nginx and restart the webserver:" \
                        && echo "==========================================================" \
                        && nginx -t && systemctl reload nginx \
                        && return 0
                    ;;
            esac
            ;;
        --prepare)
            case "${3}" in
                --usingAlias)
                    echo "[$(date)] Prepare domain '${2}' using the alias-domain '${4}' via DNS:" \
                        && prepareFullDomainFolder "${2}" \
                        && prepareAndCheckAliasDomain "${2}" "${4}" \
                        && return 0
                    ;;
                *)
                    echo "Unknown command '${1}' '${2}' '${3}' '${4}'"
                    usage
                    return 1
                    ;;
            esac
            ;;
        --setup)
            setup \
                && return 0
            ;;
        *)
            echo "Unknown command '${1}' '${2}'"
            usage
            return 1
            ;;
    esac

    return 1
}

main "$@" && exit 0 || exit 1

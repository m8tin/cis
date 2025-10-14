#!/bin/bash

# curl http://your.domain.net/.well-known/acme-challenge/test
# curl http://85.183.145.8/.well-known/acme-challenge/test
# /var/www/letsencrypt/.well-known/acme-challenge

function checkConfigViaHttp(){
    local _DOMAIN _MODE _LOCAL_FILE _LOCAL_URL _PUBLIC_URL
    _MODE="${1:?"checkConfigViaHttp(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"checkConfigViaHttp(): Missing second parameter DOMAIN"}"
    _LOCAL_FILE="/var/www/letsencrypt/.well-known/acme-challenge/${_DOMAIN}"
    _LOCAL_URL="http://localhost/.well-known/acme-challenge/${_DOMAIN}"
    _PUBLIC_URL="http://${_DOMAIN}/.well-known/acme-challenge/${_DOMAIN}"
    readonly _DOMAIN _MODE _LOCAL_FILE _LOCAL_URL _PUBLIC_URL

    # Skip check if mode is not http
    [ "${_MODE}" != "http" ] \
        && return 0

    _CHECK="Available on $(hostname)@$(date)"

    echo -n "Check domain '${_DOMAIN}'..." \
        && echo "${_CHECK}" > "/var/www/letsencrypt/.well-known/acme-challenge/${_DOMAIN}" \
        && curl -4s "${_PUBLIC_URL}" | grep -q "${_CHECK}" \
        && echo " Fertig" \
        && return 0

    echo "The configuration of domain '${_DOMAIN}' is INCORRECT:" >> /dev/stderr
    echo -n "  ${_PUBLIC_URL} was not found." >> /dev/stderr

    curl -4s "${_LOCAL_URL}" | grep -q "${_CHECK}" \
        && echo " (check DNS first)" \
        || echo " (check Webserver first)" \

    return 1
}

function isActive(){
    local _DOMAIN _MODE _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"isActive(): Missing global parameter RESULT_CERTS"}"

    _MODE="${1:?"isActive(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"isActive(): Missing second parameter DOMAIN"}"
    readonly _DOMAIN _MODE _RESULT_CERTS

    # If mode is dns the domain is active always
    [ "${_MODE}" = "dns" ] \
        && return 0

    nginx -T 2> /dev/null | grep -q "${_RESULT_CERTS}${_DOMAIN}/fullchain.crt" \
        && return 0

    echo "Domain '${_DOMAIN}' is inaktiv and therefore it will be skipped."
    return 1
}

function isGitRepository(){
    git -C "${RESULT_CERTS:?"isGitRepository(): Missing global parameter RESULT_CERTS"}" ls-tree main &> /dev/null \
        && return 0

    return 1
}

function tryGitPush(){
    local _DOMAIN _NOW _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"tryGitPush(): Missing global parameter RESULT_CERTS"}"

    _DOMAIN="${1:?"tryGitPush(): Missing first parameter DOMAIN"}"
    _NOW="$(date +%Y%m%d_%H%M)"
    readonly _DOMAIN _NOW _RESULT_CERTS

    ! isGitRepository \
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

function own(){
    local _DOMAINS _MODE
    _DOMAINS=("${RESULT_CERTS:?"own(): Missing global parameter RESULT_CERTS"}"/*)

    _MODE="${1:?"own(): Missing first parameter MODE"}"
    readonly _DOMAINS _MODE

    ! [ -d "${RESULT_CERTS}" ] \
        && echo "Trying to derive domain names from subfolders of '${RESULT_CERTS}', but it is not a folder!" \
        && return 1

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
                # dns and wildcard certifikate => take just them
                echo "${_domain}" | grep -q -F "_." || continue
                # cut front '_.'
                _domain="${_domain#_.}"
                ;;
            http)
                # http and wildcard certifikate => skip
                echo "${_domain}" | grep -q -F "_." && continue
                # ssl on domain inaktiv => skip
                isActive "{_MODE}" "${_domain}" || continue
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

function isExpiringSoon(){
    local _DOMAIN _DOMAIN_CERT _ENDDATE _MODE _NOW _REMAINING_DAYS _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"single(): Missing global parameter RESULT_CERTS"}"

    _MODE="${1:?"isExpiringSoon(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"isExpiringSoon(): Missing second parameter DOMAIN"}"

    [ "${_MODE}" = "dns" ] \
        && _DOMAIN_CERT="${_RESULT_CERTS}_.${_DOMAIN}/fullchain.crt"
    [ "${_MODE}" = "http" ] \
        && _DOMAIN_CERT="${_RESULT_CERTS}${_DOMAIN}/fullchain.crt"
    readonly _DOMAIN _DOMAIN_CERT _MODE _RESULT_CERTS

    # forced => should be issued
    [ "${3:-""}" = "--force" ] \
        && return 0

    # no cert => should be issued
    ! [ -f "${_DOMAIN_CERT}" ] \
        && return 0

    _ENDDATE="$(openssl x509 -enddate -noout -in ${_DOMAIN_CERT} | cut -d= -f2)"
    _ENDDATE="$(date --date="${_ENDDATE}" --utc +%s)"

    _NOW="$(date --date now +%s)"
    _REMAINING_DAYS="$(( (_ENDDATE - _NOW) / 86400 ))"
    readonly _ENDDATE _NOW _REMAINING_DAYS

    echo "Certificate for domain '${_DOMAIN}' will expire in ${_REMAINING_DAYS} days."

    # less than 30 days remaining => should be issued
    [ "${_REMAINING_DAYS}" -le "30" ] \
        && return 0

    return 1
}

function single(){
    local _ACME_FILE _DOMAIN _DOMAIN_FOLDER _MODE _OPTIONS _RESULT_CERTS
    _RESULT_CERTS="${RESULT_CERTS:?"single(): Missing global parameter RESULT_CERTS"}"
    _ACME_FILE="${ACME_FILE:?"single(): Missing global parameter ACME_FILE"}"

    _MODE="${1:?"single(): Missing first parameter MODE"}"
    _DOMAIN="${2:?"single(): Missing second parameter DOMAIN"}"
    [ "${_MODE}" = "dns" ] \
        && _DOMAIN_FOLDER="${_RESULT_CERTS}_.${_DOMAIN}"
    [ "${_MODE}" = "http" ] \
        && _DOMAIN_FOLDER="${_RESULT_CERTS}${_DOMAIN}"

    # always --force because we check expiring on ourself
    # _OPTIONS="--issue --force --test"
    _OPTIONS="--issue --force"
    [ "${_MODE}" = "dns" ] \
        && _OPTIONS="${_OPTIONS} --dns ${AUTOACME_DNS_PROVIDER:?"single(): Missing global parameter AUTOACME_DNS_PROVIDER"} --domain *.${_DOMAIN}"
    [ "${_MODE}" = "http" ] \
        && _OPTIONS="${_OPTIONS} --webroot /var/www/letsencrypt"
    readonly _ACME_FILE _DOMAIN _DOMAIN_FOLDER _MODE _OPTIONS _RESULT_CERTS

    ! [ -f "${_ACME_FILE}" ] \
        && echo "Program 'acme.sh' seams not to be installed. Try run 'renewCerts.sh --setup'." \
        && return 1

    # cancel on broken configuration
    ! checkConfigViaHttp "${_MODE}" "${_DOMAIN}" \
        && return 1

    # create folder for results
    ! [ -d "${_DOMAIN_FOLDER}" ] \
	&& echo -n "Creating folder '${_DOMAIN_FOLDER}'... " \
        && mkdir -p "${_DOMAIN_FOLDER}" \
        && echo "Done"

    # check enddate if third parameter is not --force
    ! isExpiringSoon "${_MODE}" "${_DOMAIN}" "${3:-""}" \
        && return 0

    # backup the keys
    [ -f "${_DOMAIN_FOLDER}/fullchain.crt" ] \
        && cp "${_DOMAIN_FOLDER}/fullchain.crt" "${_DOMAIN_FOLDER}/fullchain.crt.bak"
    [ -f "${_DOMAIN_FOLDER}/private.key" ] \
        && cp --preserve=mode,ownership "${_DOMAIN_FOLDER}/private.key" "${_DOMAIN_FOLDER}/private.key.bak"

    ${_ACME_FILE} ${_OPTIONS} \
        --domain "${_DOMAIN}" \
        --server "letsencrypt" \
        --keylength "ec-384" \
        --fullchain-file "${_DOMAIN_FOLDER}/fullchain.crt" \
        --key-file "${_DOMAIN_FOLDER}/private.key" \
        && echo "Certificate of domain '${_DOMAIN}' was updated." \
        && tryGitPush "${_DOMAIN}" \
        && return 0

    echo "Certificate of domain '${_DOMAIN}' remains unchanged."
    return 0
}

function isInstalled(){
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

function extractTarArchive(){
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

function setup(){
    local _ACME_SETUP_FILE
    _ACME_SETUP_FILE="${ACME_SETUP_FILE:?"setup(): Missing global parameter ACME_SETUP_FILE"}"
    readonly _ACME_SETUP_FILE

    isInstalled \
        && return 0

    ! [ $(id -u) = 0 ] \
        && echo "Setup requires execution as user 'root'." \
        && exit 1

    ! [ "$(echo $HOME)" = "/root" ] \
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
        && echo 'Now this script can be added into cron-tab (crontab -e),like this e.g.:' \
        && echo \
        && echo '# Each day at 6:00am renew certificates:' \
        && echo '0 6 * * * /renewCerts.sh --http --own > /var/log/renewCerts.sh.log 2>&1' \
        && return 0

    echo "Something went wrong during setup."
    return 1
}

function usage(){
    echo
    echo 'Commands:'
    echo '  (--dns|--http) --own [--force]            : Iterates all domains found in RESULT_CERTS.'
    echo '  (--dns|--http) --single DOMAIN [--force]  : Issues a certificate for the given domain.'
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

function main(){

    echo

    [ -f "/autoACME.env" ] \
        && source "/autoACME.env" \
        && echo "Environment '/autoACME.env' loaded."

    local ACME_FILE ACME_VERSION ACME_SETUP_FILE ACME_TAR_FILE OWN_FULLNAME RESULT_CERTS
    OWN_FULLNAME="$(readlink -e ${0})"
    ACME_FILE="/root/.acme.sh/acme.sh"
    ACME_VERSION="acme.sh-3.1.1"
    ACME_SETUP_FILE="/tmp/acme.sh-setup/${ACME_VERSION}/acme.sh"
    ACME_TAR_FILE="${OWN_FULLNAME%/*}/${ACME_VERSION}.tar.gz"
    RESULT_CERTS="${AUTOACME_RESULT_CERTS%/}"    #Removes shortest matching pattern '/' from the end
    RESULT_CERTS="${RESULT_CERTS:-"/etc/nginx/ssl"}/"
    readonly ACME_FILE ACME_VERSION ACME_SETUP_FILE ACME_TAR_FILE OWN_FULLNAME RESULT_CERTS

    local REPOSITORY_URL
    isGitRepository \
        && REPOSITORY_URL="$(git -C ${RESULT_CERTS} config --get remote.origin.url)"
    readonly REPOSITORY_URL

    case "${1}${2}" in
        --dns--own)
            echo "Renewing own certificates via DNS:"
            own "dns" "${3}" \
                && echo "Finished successfully." \
                && return 0
            ;;
        --http--own)
            echo "Renewing own certificates via HTTP:"
            own "http" "${3}" \
                && echo \
                && echo "Checking configuration of nginx and restart the webserver:" \
                && echo "==========================================================" \
                && nginx -t && systemctl reload nginx \
                && return 0
            ;;
        --dns--single)
            echo "Issue single certificate '${3}' via DNS:"
            single "dns" "${3}" "${4}" \
                && return 0
            ;;
        --http--single)
            echo "Issue single certificate '${3}' via HTTP:"
            single "http" "${3}" "${4}" \
                && echo \
                && echo "Checking configuration of nginx and restart the webserver:" \
                && echo "==========================================================" \
                && nginx -t && systemctl reload nginx \
                && return 0
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

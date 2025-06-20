#!/bin/bash

function main() {
    local _SCRIPTPATH _DH_PATH _SELF_SIGNED_PATH
    _SCRIPTPATH="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
    _DH_PATH="/etc/ssl/private"
    _SELF_SIGNED_PATH="/etc/ssl/private"
    readonly _SCRIPTPATH _DH_PATH _SELF_SIGNED_PATH

    ! dpkg -s nginx > /dev/null 2>&1 \
        && apt-get --yes install nginx-full \
        && echo "Nginx erfolgreich installiert." \
        || echo "Nginx ist bereits installiert."

    ! dpkg -s openssl > /dev/null 2>&1 \
        && apt-get --yes install openssl \
        && echo "OpenSSL erfolgreich installiert." \
        || echo "OpenSSL ist bereits installiert."

    ! [ -f "${_DH_PATH}/dhparam4096.pem" ] \
        && mkdir -p "${_DH_PATH}" \
        && chmod go-rwx "${_DH_PATH}" \
        && openssl dhparam -out "${_DH_PATH}/dhparam4096.pem" 4096 \
        && echo "Diffie-Hellman-Parameters erfolgreich erstellt." \
        || echo "Diffie-Hellman-Parameters bereits vorhanden."

    ! [ -f "${_SELF_SIGNED_PATH}/selfsigned-private.key" ] \
        && mkdir -p "${_SELF_SIGNED_PATH}" \
        && chmod go-rwx "${_SELF_SIGNED_PATH}" \
        && openssl req -x509 -days 36524 -nodes -newkey rsa:4096 \
             -keyout "${_SELF_SIGNED_PATH}/selfsigned-private.key" \
             -out "${_SELF_SIGNED_PATH}/selfsigned-fullchain.crt" \
        && echo "Selbstsignierte Standardschlüssel erfolgreich erstellt." \
        || echo "Selbstsignierte Standardschlüssel bereits vorhanden."

#TODO Links erstellen
#    [ -d "/etc/nginx/" ] \
#        && cp "${_SCRIPTPATH}/etc_nginx_conf.d/"* "/etc/nginx/conf.d/" \
#        && mkdir -p /etc/nginx/ssl-trusted \
#        && cp "${_SCRIPTPATH}/etc_nginx_ssl-trusted/"* "/etc/nginx/ssl-trusted/" \
#        && mkdir -p /var/www/letsencrypt/.well-known/acme-challenge \
#        && echo "Basis-Konfiguration erfolgreich erstellt." \
#        || echo "Basis-Konfiguration bereits vorhanden."

    echo \
        && echo "Nginx neu starten:" \
        && nginx -t \
        && systemctl restart nginx.service \
        && return 0

    return 1
}

main "$@" && exit 0 || exit 1

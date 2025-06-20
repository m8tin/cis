#!/bin/bash

#grep -E '(^::1|(^fc.*|^fd.*)|^fe80::.*|^ff.*)' findet:
#  loopback: ::1/128
#  uniquelocal: fc00::/7   (fc00… bis fdff…)
#  linklocal:   fe80::/64
#  multicast:   ff00::/8   (ff…)



function all() {
    # Select just lines containing 'inet6'.
    # 1.) Remove every indenting.
    # 2.) Remove 'inet6 '.
    # 3.) Remove everything after a '/' (including the /).
    ip -6 addr \
        | grep 'inet6' \
        | sed -e 's/^[[:blank:]]*//' \
            -e 's/inet6 //' \
            -e 's/\/.*//'
}

function routed() {
    local _DEVICE
    _DEVICE="$(ip -6 route show default | xargs -n 1 | grep -A1 -i dev | tail -n 1)"
    readonly _DEVICE

    ip -6 addr show dev "${_DEVICE:?"Missing DEVICE"}" scope global \
        | grep 'inet6' \
        | xargs -n 1 \
        | grep -A1 'inet6' \
        | grep ':' \
        | cut -d/ -f1
}

function public() {
    hostname -I | xargs -n 1 \
        | grep ':' \
        | grep -vE '(^::1|(^fc.*|^fd.*)|^fe80::.*|^ff.*)'
}

# Maybe use "resolvectl status" to get DNS Server and specify 'nslookup'
function published() {
    local _BOOT_HOSTNAME
    _BOOT_HOSTNAME="$(hostname -b)"
    readonly _BOOT_HOSTNAME

    nslookup -type=AAAA "${_BOOT_HOSTNAME:?"Missing BOOT_HOSTNAME"}" | xargs -n 1 \
        | grep -A2 -i "${_BOOT_HOSTNAME}" \
        | grep -A1 -i address \
        | tail -n1
}

function verified() {
    local _PUBLISHED_IP
    _PUBLISHED_IP="$(published)"
    readonly _PUBLISHED_IP

    [ -z "${_PUBLISHED_IP}" ] \
        && return 0

    all | grep "${_PUBLISHED_IP}"
}

function usage() {
    echo "Use one of the following options:"
    echo "  --all       : prints all IPv6 addresses"
    echo "  --routed    : prints the IPv6 address used to send traffic to the default gateway"
    echo "  --public    : prints all IPv6 addresses direct accessable from the internet"
    echo "  --published : prints the IPv6 address provided by DNS using this host's name"
    echo "  --verified  : prints the IPv6 included in 'all' und respended by 'published'"
}



function main(){

    case "${1}" in
        --all)
            all
            return 0
            ;;
        --routed)
            routed
            return 0
            ;;
        --public)
            public
            return 0
            ;;
        --published)
            published
            return 0
            ;;
        --verified)
            verified
            return 0
            ;;
        *)
            usage
            return 1
            ;;
    esac

    return 1

}

 main "$@" && exit 0 || exit 1

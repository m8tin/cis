#!/bin/bash

#grep -E '(:|^(127|169\.254|10|172\.(1(6|7|8|9)|2[0-9]|30|31)|192\.168|(22(4|5|6|7|8|9)|23(0|1|2|3|4|5|6|7|8|9))).*)' findet:
#  loopback:  127.0.0.0/8
#  linklocal: 169.254.0.0/16
#  private:   10.0.0.0/8,
#             172.16.0.0/12,   (172.16… bis 172.31…)
#             192.168.0.0/16
# multicast:  224.0.0.0/4      (224… bis 239…)


function all() {
    # Select just lines containing 'inet'.
    # 1.) Remove every indenting.
    # 2.) Remove 'inet '.
    # 3.) Remove everything after a '/' (including the /).
    ip -4 addr \
        | grep 'inet' \
        | sed -e 's/^[[:blank:]]*//' \
            -e 's/inet //' \
            -e 's/\/.*//'
}

function routed() {
    local _DEVICE
    _DEVICE="$(ip -4 route show default | xargs -n 1 | grep -A1 -i dev | tail -n 1)"
    readonly _DEVICE

    ip -4 addr show dev "${_DEVICE:?"Missing DEVICE"}" scope global \
        | grep 'inet' | xargs -n 1 \
        | grep -A1 'inet' \
        | tail -n 1 \
        | cut -d/ -f1
}

function public() {
    hostname -I | xargs -n 1 \
        | grep -vE '(:|^(127|169\.254|10|172\.(1(6|7|8|9)|2[0-9]|30|31)|192\.168|(22(4|5|6|7|8|9)|23(0|1|2|3|4|5|6|7|8|9))).*)'
}

# Maybe use "resolvectl status" to get DNS Server and specify 'nslookup'
function published() {
    local _BOOT_HOSTNAME
    _BOOT_HOSTNAME="$(hostname -b)"
    readonly _BOOT_HOSTNAME

    nslookup -type=A "${_BOOT_HOSTNAME:?"Missing BOOT_HOSTNAME"}" | xargs -n 1 \
        | grep -A2 -i "${_BOOT_HOSTNAME}" \
        | grep -A1 -i 'address' \
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
    echo "  --all       : prints all IPv4 addresses"
    echo "  --routed    : prints the IPv4 address used to send traffic to the default gateway"
    echo "  --public    : prints all IPv4 addresses direct accessable from the internet"
    echo "  --published : prints the IPv4 address provided by DNS using this host's name"
    echo "  --verified  : prints the IPv4 included in 'all' und respended by 'published'"
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

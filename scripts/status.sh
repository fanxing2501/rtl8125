#!/bin/sh
set -eu

. ./config.env

ssh -o BatchMode=yes "$ROUTER_HOST" '
    printf "version: "; cat /sys/module/r8125/version
    for iface in wan lan1; do
        printf "%s driver=%s master=%s state=%s\n" \
            "$iface" \
            "$(basename "$(readlink -f "/sys/class/net/$iface/device/driver")")" \
            "$(basename "$(readlink -f "/sys/class/net/$iface/master")")" \
            "$(cat "/sys/class/net/$iface/operstate")"
        sudo ethtool -S "$iface" | grep -E "(txq[01]|rxq[0-3])_(packets|bytes)" || true
    done
'

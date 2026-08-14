#!/bin/sh
set -eu

. ./config.env
ssh -o BatchMode=yes "$ROUTER_HOST" '
    printf "service="; systemctl is-enabled groot-r8125.service 2>/dev/null || true
    printf "state="; systemctl is-active groot-r8125.service 2>/dev/null || true
    printf "version="; cat /sys/module/r8125/version
    printf "params rx="; cat /sys/module/r8125/parameters/rx_queues
    printf "params tx="; cat /sys/module/r8125/parameters/tx_queues
    for iface in wan lan1; do
        driver=$(basename "$(readlink -f "/sys/class/net/$iface/device/driver")")
        rx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name "rx-*" | wc -l)
        tx=$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name "tx-*" | wc -l)
        printf "%s driver=%s rx=%s tx=%s\n" "$iface" "$driver" "$rx" "$tx"
        sudo ethtool -S "$iface" | grep -E "(txq[01]|rxq[0-3])_(packets|bytes)" || true
    done
'

#!/bin/bash
set -euo pipefail

readonly LOG=/var/log/groot-r8125.log

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "$(date --iso-8601=seconds) persistent start"

[[ "$(cat /sys/module/r8125/version)" == "9.016.01-NAPI-RSS-PAIRED" ]]
[[ "$(cat /sys/module/r8125/parameters/rx_queues)" == 2 ]]
[[ "$(cat /sys/module/r8125/parameters/tx_queues)" == 2 ]]

for _ in $(seq 1 30); do
    [[ -e /sys/class/net/br-lan ]] && break
    sleep 1
done
[[ -e /sys/class/net/br-lan ]]

for iface in wan lan1; do
    for _ in $(seq 1 30); do
        [[ -e "/sys/class/net/$iface" ]] && break
        sleep 1
    done
    [[ -e "/sys/class/net/$iface" ]]
    ip link set "$iface" master br-lan
    ip link set "$iface" up
    networkctl reconfigure "$iface" || true
done
set_affinity() {
    local iface=$1 vector=$2 cpu=$3 irq
    irq=$(awk -v name="$iface-$vector" '$NF == name {gsub(/:/, "", $1); print $1}' /proc/interrupts)
    [[ -n "$irq" ]]
    echo "$cpu" >"/proc/irq/$irq/smp_affinity_list"
    [[ "$(cat "/proc/irq/$irq/effective_affinity_list")" == "$cpu" ]]
    echo "$iface vector=$vector irq=$irq cpu=$cpu"
}

# Keep RX/NAPI on the fast cores and offload matching TX completions to CPU0-3.
set_affinity wan 0 4
set_affinity lan1 16 0
set_affinity wan 1 5
set_affinity lan1 18 1
set_affinity lan1 0 6
set_affinity wan 16 2
set_affinity lan1 1 7
set_affinity wan 18 3

for iface in wan lan1; do
    [[ "$(basename "$(readlink -f "/sys/class/net/$iface/device/driver")")" == r8125 ]]
    [[ "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name 'rx-*' | wc -l)" == 2 ]]
    [[ "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name 'tx-*' | wc -l)" == 2 ]]
    [[ "$(basename "$(readlink -f "/sys/class/net/$iface/master")")" == br-lan ]]
done

echo "$(date --iso-8601=seconds) persistent start confirmed"

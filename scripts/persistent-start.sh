#!/bin/bash
set -euo pipefail

readonly MODULE=/usr/local/lib/groot-r8125-paired/r8125.ko
readonly CONFIRMED=/run/groot-r8125-paired-confirmed
readonly LOG=/var/log/groot-r8125-paired.log
readonly PCIS=(0003:31:00.0 0004:41:00.0)

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "$(date --iso-8601=seconds) persistent start"

rollback() {
    echo "$(date --iso-8601=seconds) persistent start failed"
    /usr/local/sbin/groot-r8125-paired-rollback force
}
trap rollback ERR

rm -f "$CONFIRMED"
systemctl stop groot-r8125-paired-rollback.timer 2>/dev/null || true
systemctl start groot-r8125-paired-rollback.timer

module_ready=false
if [[ -e /sys/module/r8125/version ]] &&
   [[ "$(cat /sys/module/r8125/version)" == "9.016.01-NAPI-RSS-PAIRED" ]] &&
   [[ "$(cat /sys/module/r8125/parameters/rx_queues)" == 2 ]] &&
   [[ "$(cat /sys/module/r8125/parameters/tx_queues)" == 2 ]]; then
    module_ready=true
    for pci in "${PCIS[@]}"; do
        if [[ "$(basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")")" != r8125 ]]; then
            module_ready=false
        fi
    done
fi

if [[ "$module_ready" != true ]]; then
    for pci in "${PCIS[@]}"; do
        device="/sys/bus/pci/devices/$pci"
        if [[ -L "$device/driver" ]]; then
            echo "$pci" >"$(readlink -f "$device/driver")/unbind"
        fi
    done
    modprobe -r r8125 || true
    insmod "$MODULE" rx_queues=2 tx_queues=2
    for pci in "${PCIS[@]}"; do
        echo r8125 >"/sys/bus/pci/devices/$pci/driver_override"
        echo "$pci" >/sys/bus/pci/drivers_probe
    done
fi

udevadm settle || true
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
systemctl restart groot-router-qos.service

set_affinity() {
    local iface=$1 vector=$2 cpu=$3 irq
    irq=$(awk -v name="$iface-$vector" '$NF == name {gsub(/:/, "", $1); print $1}' /proc/interrupts)
    [[ -n "$irq" ]]
    echo "$cpu" >"/proc/irq/$irq/smp_affinity_list"
    [[ "$(cat "/proc/irq/$irq/effective_affinity_list")" == "$cpu" ]]
    echo "$iface vector=$vector irq=$irq cpu=$cpu"
}

# Keep each ingress RX queue with the opposite port's matching TX completion.
set_affinity wan 0 4
set_affinity lan1 16 4
set_affinity wan 1 5
set_affinity lan1 18 5
set_affinity lan1 0 6
set_affinity wan 16 6
set_affinity lan1 1 7
set_affinity wan 18 7

for iface in wan lan1; do
    [[ "$(basename "$(readlink -f "/sys/class/net/$iface/device/driver")")" == r8125 ]]
    [[ "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name 'rx-*' | wc -l)" == 2 ]]
    [[ "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name 'tx-*' | wc -l)" == 2 ]]
    [[ "$(basename "$(readlink -f "/sys/class/net/$iface/master")")" == br-lan ]]
done

touch "$CONFIRMED"
systemctl stop groot-r8125-paired-rollback.timer
trap - ERR
systemctl --no-block try-restart mihomo.service || true
echo "$(date --iso-8601=seconds) persistent start confirmed"

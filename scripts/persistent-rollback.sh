#!/bin/bash
set -euo pipefail

readonly CONFIRMED=/run/groot-r8125-paired-confirmed
readonly LOG=/var/log/groot-r8125-paired.log
readonly PCIS=(0003:31:00.0 0004:41:00.0)

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
if [[ "${1:-}" != force && -e "$CONFIRMED" ]]; then
    echo "$(date --iso-8601=seconds) rollback skipped: startup confirmed"
    exit 0
fi

echo "$(date --iso-8601=seconds) persistent rollback starting"
rm -f "$CONFIRMED"
systemctl stop groot-r8125-paired-rollback.timer 2>/dev/null || true
for pci in "${PCIS[@]}"; do
    device="/sys/bus/pci/devices/$pci"
    if [[ -L "$device/driver" ]]; then
        echo "$pci" >"$(readlink -f "$device/driver")/unbind"
    fi
done
modprobe -r r8125 || true
modprobe r8169
for pci in "${PCIS[@]}"; do
    echo r8169 >"/sys/bus/pci/devices/$pci/driver_override"
    echo "$pci" >/sys/bus/pci/drivers_probe
done

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
echo "$(date --iso-8601=seconds) persistent rollback complete"

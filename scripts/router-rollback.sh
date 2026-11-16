#!/bin/bash
set -euo pipefail

readonly LOG=/var/log/r8125-test/research.log
readonly PCIS=(0003:31:00.0 0004:41:00.0)

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

if [[ "${1:-}" != force && -e /run/r8125-test-confirmed ]]; then
    echo "$(date --iso-8601=seconds) rollback skipped: test confirmed"
    exit 0
fi

echo "$(date --iso-8601=seconds) rollback starting"
for pci in "${PCIS[@]}"; do
    device="/sys/bus/pci/devices/$pci"
    if [[ -L "$device/driver" ]]; then
        echo "$pci" >"$(readlink -f "$device/driver")/unbind"
    fi
done

modprobe -r r8125 || true
modprobe r8125

for pci in "${PCIS[@]}"; do
    echo r8125 >"/sys/bus/pci/devices/$pci/driver_override"
    echo "$pci" >/sys/bus/pci/drivers_probe
done

udevadm settle || true
for iface in wan lan1; do
    for _ in $(seq 1 30); do
        [[ -e "/sys/class/net/$iface" ]] && break
        sleep 1
    done
    ip link set "$iface" master br-lan
    ip link set "$iface" up
    networkctl reconfigure "$iface" || true
done

echo "$(date --iso-8601=seconds) rollback complete version=$(cat /sys/module/r8125/version)"

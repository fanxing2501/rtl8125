#!/bin/bash
set -euo pipefail

readonly MODULE=/usr/local/lib/r8125-test/current.ko
readonly LOG=/var/log/r8125-test/research.log
readonly PCIS=(0003:31:00.0 0004:41:00.0)

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "$(date --iso-8601=seconds) switch starting"

restore_links() {
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
}

rollback() {
    echo "$(date --iso-8601=seconds) switch failed, rolling back"
    /usr/local/sbin/r8125-test-rollback force
}
trap rollback ERR

for pci in "${PCIS[@]}"; do
    device="/sys/bus/pci/devices/$pci"
    if [[ -L "$device/driver" ]]; then
        echo "$pci" >"$(readlink -f "$device/driver")/unbind"
    fi
done

modprobe -r r8125
insmod "$MODULE"

for pci in "${PCIS[@]}"; do
    echo r8125 >"/sys/bus/pci/devices/$pci/driver_override"
    echo "$pci" >/sys/bus/pci/drivers_probe
done

restore_links

for pci in "${PCIS[@]}"; do
    [[ "$(basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")")" == r8125 ]]
done

trap - ERR
echo "$(date --iso-8601=seconds) switch complete version=$(cat /sys/module/r8125/version)"

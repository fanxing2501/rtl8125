#!/bin/sh
set -eu

. ./config.env
source_name="r8125-${ARTIFACT_VERSION}-source.tar.gz"
module_name="r8125-${ARTIFACT_VERSION}.ko"

ssh -o BatchMode=yes "$ROUTER_HOST" sh -s -- \
    "$ARTIFACT_BASE_URL/$source_name" \
    "$ARTIFACT_BASE_URL/$source_name.sha256" \
    "$ARTIFACT_BASE_URL/$module_name" \
    "$ARTIFACT_BASE_URL/$module_name.sha256" \
    "$source_name" \
    "$module_name" <<'REMOTE'
set -eu
work=$(mktemp -d /tmp/r8125-install.XXXXXX)
trap 'rm -rf "$work"' EXIT
curl --fail --retry 3 -o "$work/$5" "$1"
curl --fail --retry 3 -o "$work/$5.sha256" "$2"
curl --fail --retry 3 -o "$work/$6" "$3"
curl --fail --retry 3 -o "$work/$6.sha256" "$4"
(cd "$work" && sha256sum -c "$5.sha256" && sha256sum -c "$6.sha256")
tar -xzf "$work/$5" -C "$work" ./scripts/router-switch.sh ./scripts/router-rollback.sh
sudo install -d /usr/local/lib/r8125-test
sudo install -m 0644 "$work/$6" /usr/local/lib/r8125-test/current.ko
sudo install -m 0755 "$work/scripts/router-switch.sh" /usr/local/sbin/r8125-test-switch
sudo install -m 0755 "$work/scripts/router-rollback.sh" /usr/local/sbin/r8125-test-rollback
sudo rm -f /run/r8125-test-confirmed
sudo systemctl stop r8125-test-rollback.timer r8125-test-rollback.service 2>/dev/null || true
sudo systemd-run --unit=r8125-test-rollback --on-active=120 /usr/local/sbin/r8125-test-rollback
sudo systemd-run --unit=r8125-test-switch --collect /usr/local/sbin/r8125-test-switch
REMOTE

connected=false
for _ in $(seq 1 50); do
    sleep 3
    if ssh -o BatchMode=yes -o ConnectTimeout=3 "$ROUTER_HOST" true 2>/dev/null; then
        connected=true
        break
    fi
done
if [ "$connected" != true ]; then
    echo "Router did not reconnect; automatic rollback remains armed." >&2
    exit 1
fi

sleep 10
if ! ssh -o BatchMode=yes "$ROUTER_HOST" '
    set -eu
    test "$(cat /sys/module/r8125/version)" = "9.016.01-NAPI-RSS-PAIRED"
    test "$(cat /sys/module/r8125/parameters/rx_queues)" = 2
    test "$(cat /sys/module/r8125/parameters/tx_queues)" = 2
    for pci in 0003:31:00.0 0004:41:00.0; do
        test "$(basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")")" = r8125
    done
    for iface in wan lan1; do
        test "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name "rx-*" | wc -l)" = 2
        test "$(find "/sys/class/net/$iface/queues" -maxdepth 1 -name "tx-*" | wc -l)" = 2
        test "$(basename "$(readlink -f "/sys/class/net/$iface/master")")" = br-lan
        test "$(cat "/sys/class/net/$iface/operstate")" = up
    done
'; then
    ssh -o BatchMode=yes "$ROUTER_HOST" 'sudo /usr/local/sbin/r8125-test-rollback force' || true
    exit 1
fi

ssh -o BatchMode=yes "$ROUTER_HOST" '
    sudo touch /run/r8125-test-confirmed
    sudo systemctl stop r8125-test-rollback.timer r8125-test-rollback.service 2>/dev/null || true
'

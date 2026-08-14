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
work=$(mktemp -d /tmp/r8125-persistent.XXXXXX)
trap 'rm -rf "$work"' EXIT
curl --fail --retry 3 -o "$work/$5" "$1"
curl --fail --retry 3 -o "$work/$5.sha256" "$2"
curl --fail --retry 3 -o "$work/$6" "$3"
curl --fail --retry 3 -o "$work/$6.sha256" "$4"
(cd "$work" && sha256sum -c "$5.sha256" && sha256sum -c "$6.sha256")
tar -xzf "$work/$5" -C "$work" \
    ./scripts/persistent-start.sh \
    ./systemd/groot-r8125.service

kernel=$(uname -r)
test "$(sudo /usr/sbin/modinfo -F version "$work/$6")" = 9.016.01-NAPI-RSS-PAIRED
sudo /usr/sbin/modinfo -F vermagic "$work/$6" | grep -q "^$kernel "
sudo install -d "/lib/modules/$kernel/updates/dkms"
sudo install -m 0644 "$work/$6" "/lib/modules/$kernel/updates/dkms/r8125.ko"
sudo install -m 0755 "$work/scripts/persistent-start.sh" /usr/local/sbin/groot-r8125-start
sudo install -m 0644 "$work/systemd/groot-r8125.service" /etc/systemd/system/groot-r8125.service

printf '%s\n' \
    'blacklist r8169' \
    'install r8169 /bin/false' \
    'options r8125 rx_queues=2 tx_queues=2' | \
    sudo tee /etc/modprobe.d/groot-r8125.conf >/dev/null

modules=$(mktemp)
trap 'rm -rf "$work" "$modules"' EXIT
sudo sed '/^[[:space:]]*r8125\([[:space:]].*\)\?$/d' /etc/initramfs-tools/modules >"$modules"
printf '%s\n' 'r8125 rx_queues=2 tx_queues=2' >>"$modules"
sudo install -m 0644 "$modules" /etc/initramfs-tools/modules

sudo systemctl disable --now groot-r8125-paired-rollback.timer 2>/dev/null || true
sudo systemctl disable --now groot-r8125-paired.service 2>/dev/null || true
sudo rm -f \
    /etc/systemd/system/groot-r8125-paired.service \
    /etc/systemd/system/groot-r8125-paired-rollback.service \
    /etc/systemd/system/groot-r8125-paired-rollback.timer \
    /etc/systemd/system/groot-r8125-watchdog.service \
    /usr/local/sbin/groot-r8125-paired-rollback \
    /usr/local/sbin/groot-r8125-paired-start \
    /usr/local/sbin/groot-r8125-rollback \
    /usr/local/sbin/groot-r8125-watchdog \
    /usr/local/sbin/r8125-iommu-rollback \
    /usr/local/sbin/r8125-test-rollback \
    /usr/local/sbin/r8125-test-switch
sudo rm -rf /usr/local/lib/groot-r8125-paired
sudo rm -f /var/log/groot-r8125-paired.log

sudo depmod -a "$kernel"
sudo update-initramfs -u -k "$kernel"
sudo systemd-analyze verify /etc/systemd/system/groot-r8125.service
sudo systemctl daemon-reload
sudo systemctl enable groot-r8125.service
sudo systemctl restart groot-r8125.service
REMOTE

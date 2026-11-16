#!/bin/sh
set -eu

. ./config.env

source_name="r8125-${ARTIFACT_VERSION}-source.tar.gz"

ssh -o BatchMode=yes "$ROUTER_HOST" sh -s -- \
    "$ARTIFACT_BASE_URL/$source_name" \
    "$ARTIFACT_BASE_URL/$source_name.sha256" \
    "$source_name" <<'REMOTE'
set -eu

work=$(mktemp -d /tmp/r8125-iommu.XXXXXX)
trap 'rm -rf "$work"' EXIT

curl --fail --retry 3 -o "$work/$3" "$1"
curl --fail --retry 3 -o "$work/$3.sha256" "$2"
(cd "$work" && sha256sum -c "$3.sha256")
tar -xzf "$work/$3" -C "$work" \
    ./scripts/router-iommu-rollback.sh \
    ./systemd/r8125-iommu-rollback.service \
    ./systemd/r8125-iommu-rollback.timer

sudo install -d /root/r8125-test-baseline
sudo cp /boot/armbianEnv.txt /root/r8125-test-baseline/armbianEnv.pre-iommu-lazy
sudo install -m 0755 "$work/scripts/router-iommu-rollback.sh" /usr/local/sbin/r8125-iommu-rollback
sudo install -m 0644 "$work/systemd/r8125-iommu-rollback.service" /etc/systemd/system/r8125-iommu-rollback.service
sudo install -m 0644 "$work/systemd/r8125-iommu-rollback.timer" /etc/systemd/system/r8125-iommu-rollback.timer

if ! grep -qE '(^|[[:space:]])iommu\.strict=0([[:space:]]|$)' /boot/armbianEnv.txt; then
    sudo sed -i '/^extraargs=/ s/$/ iommu.strict=0/' /boot/armbianEnv.txt
fi

sudo rm -f /run/r8125-iommu-confirmed
sudo systemctl daemon-reload
sudo systemctl enable r8125-iommu-rollback.timer
sync
sudo systemd-run --unit=r8125-iommu-test-reboot --on-active=2 /usr/bin/systemctl reboot
REMOTE

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
    ./scripts/persistent-rollback.sh \
    ./systemd/groot-r8125-paired.service \
    ./systemd/groot-r8125-paired-rollback.service \
    ./systemd/groot-r8125-paired-rollback.timer

sudo install -d /usr/local/lib/groot-r8125-paired
sudo install -m 0644 "$work/$6" /usr/local/lib/groot-r8125-paired/r8125.ko
sudo install -m 0755 "$work/scripts/persistent-start.sh" /usr/local/sbin/groot-r8125-paired-start
sudo install -m 0755 "$work/scripts/persistent-rollback.sh" /usr/local/sbin/groot-r8125-paired-rollback
for unit in groot-r8125-paired.service groot-r8125-paired-rollback.service groot-r8125-paired-rollback.timer; do
    sudo install -m 0644 "$work/systemd/$unit" "/etc/systemd/system/$unit"
done
sudo systemd-analyze verify /etc/systemd/system/groot-r8125-paired.service \
    /etc/systemd/system/groot-r8125-paired-rollback.service \
    /etc/systemd/system/groot-r8125-paired-rollback.timer
sudo systemctl daemon-reload
sudo systemctl enable groot-r8125-paired.service
sudo systemctl restart groot-r8125-paired.service
REMOTE

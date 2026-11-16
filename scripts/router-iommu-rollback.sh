#!/bin/bash
set -euo pipefail

readonly BACKUP=/root/r8125-test-baseline/armbianEnv.pre-iommu-lazy
readonly LOG=/var/log/r8125-test/iommu.log

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

if [[ "${1:-}" != force && -e /run/r8125-iommu-confirmed ]]; then
    echo "$(date --iso-8601=seconds) rollback skipped: test confirmed"
    exit 0
fi

echo "$(date --iso-8601=seconds) restoring strict IOMMU configuration"
test -f "$BACKUP"
cp "$BACKUP" /boot/armbianEnv.txt
systemctl disable r8125-iommu-rollback.timer || true
sync
systemctl reboot

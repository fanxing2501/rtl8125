#!/bin/sh
set -eu

. ./config.env

mkdir -p artifacts
archive="artifacts/r8125-${ARTIFACT_VERSION}-source.tar.gz"
tar \
    --exclude=.git \
    --exclude=artifacts \
    --sort=name \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "$archive" .
(cd artifacts && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")

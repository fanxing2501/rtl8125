#!/bin/sh
set -eu

. ./config.env

mkdir -p artifacts
name="r8125-${ARTIFACT_VERSION}.ko"
curl --fail --retry 3 -o "artifacts/$name" "$ARTIFACT_BASE_URL/$name"
curl --fail --retry 3 -o "artifacts/$name.sha256" "$ARTIFACT_BASE_URL/$name.sha256"
(cd artifacts && sha256sum -c "$name.sha256")

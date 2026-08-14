#!/bin/sh
set -eu

. ./config.env
name="r8125-${ARTIFACT_VERSION}-source.tar.gz"
for file in "artifacts/$name" "artifacts/$name.sha256"; do
    curl --fail --retry 3 --upload-file "$file" "$ARTIFACT_BASE_URL/$(basename "$file")"
done

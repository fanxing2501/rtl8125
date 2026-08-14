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
source_url=$1
checksum_url=$2
module_url=$3
module_checksum_url=$4
source_name=$5
module_name=$6
build_dir=$(mktemp -d /tmp/r8125-build.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT

curl --fail --retry 3 -o "$build_dir/$source_name" "$source_url"
curl --fail --retry 3 -o "$build_dir/$source_name.sha256" "$checksum_url"
(cd "$build_dir" && sha256sum -c "$source_name.sha256")
mkdir "$build_dir/source"
tar -xzf "$build_dir/$source_name" -C "$build_dir/source"
make -C "/lib/modules/$(uname -r)/build" \
    M="$build_dir/source" \
    ENABLE_MULTIPLE_TX_QUEUE=y \
    ENABLE_RSS_SUPPORT=y \
    CONFIG_ASPM=n \
    ENABLE_PTP_SUPPORT=n \
    modules
cp "$build_dir/source/r8125.ko" "$build_dir/$module_name"
(cd "$build_dir" && sha256sum "$module_name" > "$module_name.sha256")
curl --fail --retry 3 --upload-file "$build_dir/$module_name" "$module_url"
curl --fail --retry 3 --upload-file "$build_dir/$module_name.sha256" "$module_checksum_url"
REMOTE

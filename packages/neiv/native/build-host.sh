#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
objects="$repo/build/host-objects"
mkdir -p "$objects"
for name in app_host asset_policy bridge_policy command_validation slot_host; do
  clang -fobjc-arc -I "$repo/native" -c "$repo/native/$name.m" -o "$objects/$name.o"
done
library="$repo/build/libneiv_mac_host.a"
libtool -static -o "$library" "$objects/app_host.o" "$objects/asset_policy.o" \
  "$objects/bridge_policy.o" "$objects/command_validation.o" "$objects/slot_host.o"
echo "$library"

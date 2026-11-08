#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/neiv-m1.XXXXXX)
if [ "${KEEP_M1_OUTPUT:-0}" != 1 ]; then trap 'rm -rf "$scratch"' EXIT; fi
sdk="$repo/packages/neiv"
source_root="$repo"
mkdir -p "$scratch/src"
cp "$source_root/cyna.toml" "$scratch/cyna.toml"
cp "$source_root/src/"*.cy "$scratch/src/"
for app in proof hello; do
  target="$scratch/examples/$app"
  mkdir -p "$target/src" "$target/web" "$target/assets"
  source="$source_root/examples/$app"
  cp "$source/app.json" "$source/cyna.toml" "$target/"
  sed -i '' 's|neiv = { version = "0.1.3" }|neiv = { path = "../..", version = "0.1.3" }|' "$target/cyna.toml"
  cp "$source/src/lib.cy" "$target/src/lib.cy"
  cp "$source/web/App.weiv" "$target/web/App.weiv"
  if [ "$app" = proof ]; then cp "$source/assets/sample.mp4" "$target/assets/sample.mp4"; fi
  sh "$sdk/app-build.sh" "$target"
  node "$sdk/scripts/generate-commands.mjs" --check "$target"
done
node "$repo/tests/bridge-test.mjs" "$scratch/examples/hello/build/web/generated/commands.js"
node "$repo/tests/discovery-test.mjs"
node "$sdk/bin/neiv.mjs" new "$scratch/scaffold" --id dev.local.neiv-scaffold
node "$sdk/bin/neiv.mjs" check "$scratch/scaffold"
node "$sdk/bin/neiv.mjs" build "$scratch/scaffold"
cp "$source_root/examples/proof/native/dispatch_test.m" "$scratch/examples/proof/native/dispatch_test.m"
clang -fobjc-arc -framework Foundation -I "$sdk/native" \
  "$scratch/examples/proof/native/dispatch_test.m" "$sdk/native/command_validation.m" \
  "$scratch/examples/proof/build/libcyna_app_core.a" -o "$scratch/proof-dispatch-test"
"$scratch/proof-dispatch-test"
cp "$source_root/examples/hello/native/dispatch_test.m" "$scratch/examples/hello/native/dispatch_test.m"
clang -fobjc-arc -framework Foundation -I "$sdk/native" \
  "$scratch/examples/hello/native/dispatch_test.m" "$sdk/native/command_validation.m" \
  "$scratch/examples/hello/build/libneiv_hello.a" -o "$scratch/hello-dispatch-test"
"$scratch/hello-dispatch-test"
clang -fobjc-arc -framework Foundation -I "$sdk/native" \
  "$repo/tests/native/asset_policy_test.m" "$sdk/native/asset_policy.m" -o "$scratch/asset-policy-test"
"$scratch/asset-policy-test"
clang -fobjc-arc -framework AppKit -framework WebKit -I "$sdk/native" \
  "$repo/tests/native/bridge_policy_test.m" "$sdk/native/bridge_policy.m" -o "$scratch/bridge-policy-test"
"$scratch/bridge-policy-test"
clang -fobjc-arc -framework AppKit -I "$sdk/native" \
  "$repo/tests/native/slot_host_test.m" "$sdk/native/slot_host.m" -o "$scratch/slot-host-test"
"$scratch/slot-host-test"
if otool -L "$scratch/examples/hello/build/NeivApp.app/Contents/MacOS/NeivApp" | rg -q 'AVFoundation|Metal|QuartzCore|CoreMedia'; then
  echo "ordinary app linked a media or rendering framework" >&2; exit 1
fi
echo "M1 clean builds and focused checks passed: $scratch"

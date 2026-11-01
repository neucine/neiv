#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/ceiv-m1.XXXXXX)
if [ "${KEEP_M1_OUTPUT:-0}" != 1 ]; then trap 'rm -rf "$scratch"' EXIT; fi
mkdir -p "$scratch/packages/ceiv/src"
cp "$repo/packages/ceiv/cyna.toml" "$scratch/packages/ceiv/cyna.toml"
cp "$repo/packages/ceiv/src/lib.cy" "$scratch/packages/ceiv/src/lib.cy"
cp "$repo/packages/ceiv/src/app.cy" "$scratch/packages/ceiv/src/app.cy"
cp "$repo/packages/ceiv/src/window.cy" "$scratch/packages/ceiv/src/window.cy"
cp "$repo/packages/ceiv/src/events.cy" "$scratch/packages/ceiv/src/events.cy"
cp "$repo/packages/ceiv/src/menu.cy" "$scratch/packages/ceiv/src/menu.cy"
cp "$repo/packages/ceiv/src/dialog.cy" "$scratch/packages/ceiv/src/dialog.cy"
cp "$repo/packages/ceiv/src/slot.cy" "$scratch/packages/ceiv/src/slot.cy"
cp "$repo/packages/ceiv/src/shell.cy" "$scratch/packages/ceiv/src/shell.cy"
cp "$repo/packages/ceiv/src/clipboard.cy" "$scratch/packages/ceiv/src/clipboard.cy"
cp "$repo/packages/ceiv/src/surface.cy" "$scratch/packages/ceiv/src/surface.cy"
cp "$repo/packages/ceiv/src/tray.cy" "$scratch/packages/ceiv/src/tray.cy"
cp "$repo/packages/ceiv/src/notification.cy" "$scratch/packages/ceiv/src/notification.cy"
cp "$repo/packages/ceiv/src/buffer.cy" "$scratch/packages/ceiv/src/buffer.cy"
for app in proof hello; do
  target="$scratch/examples/$app"
  mkdir -p "$target/src" "$target/web" "$target/assets"
  source="$repo/examples/$app"
  cp "$source/app.json" "$source/cyna.toml" "$target/"
  sed -i '' 's|ceiv = { version = "0.1.0" }|ceiv = { path = "../../packages/ceiv", version = "0.1.0" }|' "$target/cyna.toml"
  cp "$source/src/lib.cy" "$target/src/lib.cy"
  cp "$source/web/App.weiv" "$target/web/App.weiv"
  if [ "$app" = proof ]; then cp "$source/assets/sample.mp4" "$target/assets/sample.mp4"; fi
  sh "$repo/app-build.sh" "$target"
  node "$repo/scripts/generate-commands.mjs" --check "$target"
done
node "$repo/scripts/bridge-test.mjs" "$scratch/examples/hello/build/web/generated/commands.js"
node "$repo/scripts/discovery-test.mjs"
node "$repo/bin/ceiv.mjs" new "$scratch/scaffold" --id dev.local.ceiv-scaffold
node "$repo/bin/ceiv.mjs" check "$scratch/scaffold"
node "$repo/bin/ceiv.mjs" build "$scratch/scaffold"
cp "$repo/examples/proof/native/dispatch_test.m" "$scratch/examples/proof/native/dispatch_test.m"
clang -fobjc-arc -framework Foundation -I "$repo/native" \
  "$scratch/examples/proof/native/dispatch_test.m" "$repo/native/command_validation.m" \
  "$scratch/examples/proof/build/libcyna_app_core.a" -o "$scratch/proof-dispatch-test"
"$scratch/proof-dispatch-test"
cp "$repo/examples/hello/native/dispatch_test.m" "$scratch/examples/hello/native/dispatch_test.m"
clang -fobjc-arc -framework Foundation -I "$repo/native" \
  "$scratch/examples/hello/native/dispatch_test.m" "$repo/native/command_validation.m" \
  "$scratch/examples/hello/build/libceiv_hello.a" -o "$scratch/hello-dispatch-test"
"$scratch/hello-dispatch-test"
clang -fobjc-arc -framework Foundation -I "$repo/native" \
  "$repo/native/asset_policy_test.m" "$repo/native/asset_policy.m" -o "$scratch/asset-policy-test"
"$scratch/asset-policy-test"
clang -fobjc-arc -framework AppKit -framework WebKit -I "$repo/native" \
  "$repo/native/bridge_policy_test.m" "$repo/native/bridge_policy.m" -o "$scratch/bridge-policy-test"
"$scratch/bridge-policy-test"
clang -fobjc-arc -framework AppKit -I "$repo/native" \
  "$repo/native/slot_host_test.m" "$repo/native/slot_host.m" -o "$scratch/slot-host-test"
"$scratch/slot-host-test"
if otool -L "$scratch/examples/hello/build/CeivApp.app/Contents/MacOS/CeivApp" | rg -q 'AVFoundation|Metal|QuartzCore|CoreMedia'; then
  echo "ordinary app linked a media or rendering framework" >&2; exit 1
fi
echo "M1 clean builds and focused checks passed: $scratch"

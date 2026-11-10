#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app=${1:-"$repo/../../examples/hello"}
case "$app" in /*) ;; *) app="$PWD/$app" ;; esac
app=$(CDPATH= cd -- "$app" && pwd)
out="$app/build"
mkdir -p "$out" "$app/native/generated" "$app/web/generated"
SDKROOT=$(xcrun --show-sdk-path); export SDKROOT
sh "$repo/scripts/ensure-cyna-package.sh"
node "$repo/scripts/build-frontend.mjs"
node "$repo/scripts/validate-app.mjs" "$app"
node "$repo/scripts/generate-commands.mjs" "$app"
node "$repo/scripts/generate-callbacks.mjs" "$app"
node "$repo/scripts/prepare-cyna.mjs" "$app"
library_name=$(node - "$app/cyna.toml" <<'EOF'
const fs = require('fs');
const match = fs.readFileSync(process.argv[2], 'utf8').match(/^name\s*=\s*"([A-Za-z_][A-Za-z_0-9]*)"/m);
if (!match) process.exit(2);
process.stdout.write(match[1]);
EOF
)
(cd "$app" && cyna install build/cyna.toml && cyna check build/cyna.toml && cyna build build/cyna.toml --output "$out/lib$library_name.a")
weiv_cli="$repo/node_modules/weivjs/bin/weiv.mjs"
if [ ! -f "$weiv_cli" ]; then weiv_cli="$repo/../weivjs/bin/weiv.mjs"; fi
if [ ! -f "$weiv_cli" ]; then weiv_cli="$repo/../weiv/packages/weiv/bin/weiv.mjs"; fi
if [ ! -f "$weiv_cli" ]; then echo "Install Neiv dependencies to provide the Weiv compiler" >&2; exit 2; fi
node "$weiv_cli" compile emit app "$app/web/App.weiv" "$out/web"
cp "$app/web/generated/"*.d.ts "$out/web/generated/"
node "$repo/scripts/install-frontend.mjs" "$out/web"
entry=$(node -e 'process.stdout.write(require(process.argv[1]).entry)' "$app/app.json")
test -f "$out/web/$entry"
node - "$out/web/index.html" <<'EOF'
const fs = require('fs');
const path = process.argv[2];
const html = fs.readFileSync(path, 'utf8');
const policy = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'";
fs.writeFileSync(path, html.replace('</head>', `    <meta http-equiv="Content-Security-Policy" content="${policy}">\n  </head>`));
EOF
cat > "$out/main.m" <<EOF
#import "$repo/native/app_host.h"
#include "$app/native/generated/dispatch.inc"
extern void neiv_app_configure(void);
int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    return cyna_run_app(dispatch_command, neiv_app_configure);
}
EOF
library="$out/lib$library_name.a"
test -f "$library"
host_library=$(sh "$repo/native/build-host.sh" | tail -1)
plugin=$(node -e 'const m=require(process.argv[1]); process.stdout.write(m.localHttp ? "NeivHttpPlugin" : m.nativePlugin || "")' "$app/app.json")
if [ "$plugin" = CynaVideoPlugin ]; then
  clang -fobjc-arc -framework AppKit -framework WebKit -framework CoreGraphics -framework UserNotifications -framework UniformTypeIdentifiers \
    -framework QuartzCore -framework CoreMedia -framework AVFoundation \
    -I "$repo/native" "$repo/native/video_plugin.m" "$repo/native/video.m" \
    "$out/main.m" "$host_library" "$library" -o "$out/NeivApp"
elif [ "$plugin" = CynaColorPlugin ]; then
  clang -fobjc-arc -framework AppKit -framework WebKit -framework CoreGraphics -framework UserNotifications -framework UniformTypeIdentifiers \
    -framework Metal -framework MetalKit -framework QuartzCore \
    -I "$repo/native" "$repo/native/color_plugin.m" "$repo/native/surface.m" \
    "$out/main.m" "$host_library" "$library" -o "$out/NeivApp"
elif [ "$plugin" = NeivHttpPlugin ]; then
  clang -fobjc-arc -framework AppKit -framework WebKit -framework CoreGraphics -framework UserNotifications -framework UniformTypeIdentifiers \
    -I "$repo/native" "$repo/native/http_plugin.m" \
    "$out/main.m" "$host_library" "$library" -o "$out/NeivApp"
elif [ -z "$plugin" ]; then
  clang -fobjc-arc -framework AppKit -framework WebKit -framework CoreGraphics -framework UserNotifications -framework UniformTypeIdentifiers \
    -I "$repo/native" "$out/main.m" "$host_library" "$library" -o "$out/NeivApp"
else
  set --
  for source in $(node -e 'const m=require(process.argv[1]); for(const path of m.nativeSources) console.log(path)' "$app/app.json"); do
    set -- "$@" "$app/$source"
  done
  for framework in $(node -e 'const m=require(process.argv[1]); for(const name of m.nativeFrameworks || []) console.log(name)' "$app/app.json"); do
    set -- "$@" -framework "$framework"
  done
  clang -fobjc-arc -framework AppKit -framework WebKit -framework CoreGraphics -framework UserNotifications -framework UniformTypeIdentifiers \
    -I "$repo/native" "$@" "$out/main.m" "$host_library" "$library" -o "$out/NeivApp"
fi
bundle="$out/NeivApp.app/Contents"
rm -rf "$bundle"
mkdir -p "$bundle/MacOS" "$bundle/Resources/web"
cp "$out/NeivApp" "$bundle/MacOS/NeivApp"
cp "$app/app.json" "$bundle/Resources/app.json"
node - "$app" "$bundle/Resources" <<'EOF'
const fs = require('fs');
const path = require('path');
const manifest = JSON.parse(fs.readFileSync(path.join(process.argv[2], 'app.json'), 'utf8'));
if (manifest.icon) fs.copyFileSync(path.join(process.argv[2], manifest.icon), path.join(process.argv[3], 'icon.icns'));
EOF
cp "$app/native/generated/events.json" "$bundle/Resources/events.json"
node - "$app" "$bundle/Resources" <<'EOF'
const fs = require('fs');
const path = require('path');
const app = process.argv[2], resources = process.argv[3];
const manifest = JSON.parse(fs.readFileSync(path.join(app, 'app.json'), 'utf8'));
for (const item of manifest.resources || []) {
  const target = path.join(resources, item.target);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(path.join(app, item.source), target);
}
if (manifest.localHttp && typeof manifest.localHttp === 'object') {
  const source = path.join(app, manifest.localHttp.server.source);
  const target = path.join(resources, 'local-http-server');
  fs.cpSync(source, target, { recursive: true });
}
EOF
rm -rf "$bundle/Resources/web"
cp -R "$out/web" "$bundle/Resources/web"
node - "$app/app.json" "$bundle/Info.plist" <<'EOF'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
fs.writeFileSync(process.argv[3], `<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>\n<key>CFBundleIdentifier</key><string>${escape(manifest.id)}</string>\n<key>CFBundleName</key><string>${escape(manifest.name)}</string>\n<key>CFBundleShortVersionString</key><string>${escape(manifest.version || "0.1.0")}</string>\n<key>CFBundleVersion</key><string>${escape(manifest.version || "0.1.0")}</string>\n${manifest.icon ? "<key>CFBundleIconFile</key><string>icon.icns</string>\n" : ""}<key>CFBundleExecutable</key><string>NeivApp</string>\n<key>CFBundlePackageType</key><string>APPL</string>\n<key>NSHighResolutionCapable</key><true/>\n${manifest.localHttp ? "<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>\n" : ""}</dict></plist>\n`);
EOF
echo "$out/NeivApp.app"

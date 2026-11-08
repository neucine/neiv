#!/bin/sh
set -eu
sdk=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_root=$(CDPATH= cd -- "$sdk/../.." && pwd)
artifact="$sdk/cyna-dist/packages/neiv/0.1.3"
if [ -f "$source_root/cyna.toml" ] && [ -f "$source_root/src/lib.cy" ] &&
   [ "$(sed -n '1p' "$source_root/cyna.toml")" = 'name = "neiv"' ]; then
  cyna package pack "$source_root"
  mkdir -p "$sdk/cyna-dist/packages/neiv"
  cp -R "$source_root/dist/packages/neiv/0.1.3" "$sdk/cyna-dist/packages/neiv/"
fi
if [ ! -f "$artifact/manifest.toml" ]; then
  echo "Neiv Cyna package artifact is missing" >&2
  exit 2
fi
scratch=$(mktemp -d /tmp/neiv-package.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/src"
cat > "$scratch/cyna.toml" <<'EOF'
name = "neiv_bootstrap"
version = "0.1.3"
src = "src"
type = "staticlib"
entry = "src/lib.cy"

[dependencies]
neiv = { version = "0.1.3" }
EOF
printf '%s\n' '// Package installation manifest.' > "$scratch/src/lib.cy"
CYNA_PACKAGE_ARTIFACT_ROOT="$sdk/cyna-dist/packages" cyna install "$scratch"

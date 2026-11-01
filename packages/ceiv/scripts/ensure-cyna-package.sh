#!/bin/sh
set -eu
sdk=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_root=$(CDPATH= cd -- "$sdk/../.." && pwd)
artifact="$sdk/cyna-dist/packages/ceiv/0.1.0"
if [ -f "$source_root/cyna.toml" ] && [ -f "$source_root/src/lib.cy" ] &&
   [ "$(sed -n '1p' "$source_root/cyna.toml")" = 'name = "ceiv"' ]; then
  cyna package pack "$source_root"
  mkdir -p "$sdk/cyna-dist/packages/ceiv"
  cp -R "$source_root/dist/packages/ceiv/0.1.0" "$sdk/cyna-dist/packages/ceiv/"
fi
if [ ! -f "$artifact/manifest.toml" ]; then
  echo "Ceiv Cyna package artifact is missing" >&2
  exit 2
fi
scratch=$(mktemp -d /tmp/ceiv-package.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/src"
cat > "$scratch/cyna.toml" <<'EOF'
name = "ceiv_bootstrap"
version = "0.1.0"
src = "src"
type = "staticlib"
entry = "src/lib.cy"

[dependencies]
ceiv = { version = "0.1.0" }
EOF
printf '%s\n' '// Package installation manifest.' > "$scratch/src/lib.cy"
CYNA_PACKAGE_ARTIFACT_ROOT="$sdk/cyna-dist/packages" cyna install "$scratch"

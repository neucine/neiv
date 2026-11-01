#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -f "$repo/packages/ceiv/dist/packages/ceiv/0.1.0/manifest.toml" ]; then
  cyna package pack "$repo/packages/ceiv"
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
CYNA_PACKAGE_ARTIFACT_ROOT="$repo/packages/ceiv/dist/packages" cyna install "$scratch"

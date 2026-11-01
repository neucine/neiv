#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source_bundle=$1
fixture_bundle=$2
rm -rf "$fixture_bundle"
cp -R "$source_bundle" "$fixture_bundle"
web="$fixture_bundle/Contents/Resources/web"
cp "$repo/tests/host-fixture/"*.mjs "$repo/tests/host-fixture/"*.html "$web/"
cp "$repo/tests/host-fixture/index.html" "$web/index.html"
echo "$fixture_bundle"

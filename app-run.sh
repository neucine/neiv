#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bundle=$(sh "$repo/packages/ceiv/app-build.sh" "${1:-examples/hello}" | tail -1)
open -n "$bundle"

#!/bin/sh
set -eu
cd "$(dirname "$0")"
sh packages/neiv/app-build.sh examples/proof
clang -fobjc-arc -framework Foundation -I packages/neiv/native examples/proof/native/dispatch_test.m packages/neiv/native/command_validation.m \
  examples/proof/build/libcyna_app_core.a -o examples/proof/build/dispatch-test
./examples/proof/build/dispatch-test

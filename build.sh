#!/bin/sh
set -eu
cd "$(dirname "$0")"
sh packages/ceiv/app-build.sh examples/proof
clang -fobjc-arc -framework Foundation -I packages/ceiv/native examples/proof/native/dispatch_test.m packages/ceiv/native/command_validation.m \
  examples/proof/build/libcyna_app_core.a -o examples/proof/build/dispatch-test
./examples/proof/build/dispatch-test

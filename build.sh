#!/bin/sh
set -eu
cd "$(dirname "$0")"
sh app-build.sh examples/proof
clang -fobjc-arc -framework Foundation -I native examples/proof/native/dispatch_test.m native/command_validation.m \
  examples/proof/build/libcyna_app_core.a -o examples/proof/build/dispatch-test
./examples/proof/build/dispatch-test

#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
clang $(gnustep-config --objc-flags) -I. Tests/SubtitleControls.m AppController.m \
  -o "$test_dir/subtitle-controls" $(gnustep-config --gui-libs)
xvfb-run -a "$test_dir/subtitle-controls"

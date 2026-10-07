#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
# Audio is essential: the original crash is in audio device teardown.
ffmpeg -nostdin -v error -f lavfi -i 'color=c=blue:s=160x90:r=24' \
  -f lavfi -i 'sine=frequency=440:sample_rate=44100' -t 3 \
  -c:v mpeg4 -c:a aac "$test_dir/audio.mp4"
ffmpeg -nostdin -v error -f lavfi -i 'color=c=red:s=128x96:r=24' \
  -t 3 -c:v mpeg4 "$test_dir/silent.mp4"
clang $(gnustep-config --objc-flags) -I. Tests/SwitchVideos.m AppController.m \
  -o "$test_dir/video-switching" $(gnustep-config --gui-libs)
xvfb-run -a "$test_dir/video-switching" "$test_dir/audio.mp4" "$test_dir/silent.mp4"

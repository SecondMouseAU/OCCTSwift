#!/bin/bash
#
# #3479: libmalloc's free() segfaults under MallocScribble with several threads and large blocks.
# No OCCT and no Swift. Prints one line per case; "EXIT 139" is the crash.
#
# On the macos-15 runner (15.7.9) the first three cases crash and the two workaround cases pass.
# On macos-26 (26.6.2) every case passes. See README.md for the measured runs.
#
# Usage: Scripts/repro/3479-libmalloc-scribble-medium-zone/run.sh

set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$(mktemp -d)/probe"
clang -O1 -g -o "$bin" "$here/malloc_scribble_probe.c" -lpthread

run() {
  echo "--- $1"
  shift
  env "$@" || echo "EXIT $?"
}

run "8 threads, blocks to 4 MB, MallocScribble" MallocScribble=1 "$bin" 8 30 4000000 1
run "3 threads, blocks to 4 MB, malloc/free only" MallocScribble=1 "$bin" 3 30 4000000 0
run "3 threads, blocks to 4 MB, mixed" MallocScribble=1 "$bin" 3 30 4000000 1
run "control, no malloc environment" "$bin" 8 30 4000000 1
run "workaround MallocMediumZone=0" MallocScribble=1 MallocMediumZone=0 "$bin" 8 30 4000000 1
run "workaround MallocSpaceEfficient=1" MallocScribble=1 MallocSpaceEfficient=1 "$bin" 8 30 4000000 1

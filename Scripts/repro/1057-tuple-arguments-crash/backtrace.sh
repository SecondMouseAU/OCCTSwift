#!/bin/bash
# #1057: run one grid cell with the Swift backtracer on, so the crash frame is visible rather than
# only SwiftPM's "exited with unexpected signal code 6".
#
#   ./backtrace.sh A1StringSIMD3

set -u
cd "$(dirname "$0")/standalone" || exit 2
CELL="${1:-A1StringSIMD3}"

export SWIFT_BACKTRACE=enable=yes,threads=crashed,limit=60,interactive=no,swift-backtrace=on
swift test --filter "$CELL"

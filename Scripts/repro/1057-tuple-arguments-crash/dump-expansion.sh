#!/bin/bash
# #1057: dump the `@Test` macro expansions for the grid, so the shape the compiler is handed is on
# record next to the crash it produces. Writes macro-expansions.txt beside this script.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/standalone" || exit 2

touch Tests/TupleGridTests/TupleGridTests.swift
swift build --build-tests -Xswiftc -Xfrontend -Xswiftc -dump-macro-expansions \
  > "$HERE/macro-expansions.txt" 2>&1
echo "wrote $HERE/macro-expansions.txt"

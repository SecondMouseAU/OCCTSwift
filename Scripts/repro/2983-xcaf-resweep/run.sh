#!/usr/bin/env bash
# The #2983 XCAF re-sweep, start to finish. Run from the repo root, with the OCCTXCAFTests files in
# the state you want to measure (the rewritten ones for LABEL=after; `git checkout origin/main --
# Tests/OCCTXCAFTests` first for LABEL=before, after committing the rewrites, never before).
#
#   Scripts/repro/2983-xcaf-resweep/run.sh after
#
# One build serves every switch. Swift Testing and XCTest are symlinked into PackageFrameworks
# because SIP strips DYLD_* from the signed helper (okf/references/injection-sweep-mechanics.md).
set -euo pipefail
label="${1:?usage: run.sh before|after}"
dir=Scripts/repro/2983-xcaf-resweep
fw=.build/out/Products/Debug/PackageFrameworks
xc=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks

cp "$dir/SweepXcafShadow.swift.txt" Sources/OCCTSwift/SweepXcafShadow.swift
python3 "$dir/inject.py" apply

env -u BRIDGE_PREBUILT -u OCCTSWIFT_BRIDGE_PREBUILT swift build --build-tests
mkdir -p "$fw"
ln -sf "$xc/XCTest.framework" "$fw/"
ln -sf "$xc/Testing.framework" "$fw/"
ln -sf /Applications/Xcode.app/Contents/SharedFrameworks/libXCTestSwiftSupport.dylib "$fw/"

python3 "$dir/run-injection-matrix.py" "$label"

# Restore with git, never by reverse replacement, and prove it: rebuild until the bundle holds no
# injection marker, then run it once with a switch set (a clean bundle must ignore it).
git checkout -- Sources/OCCTSwift/BRepGraph+Attributes.swift Sources/OCCTSwift/GDTWrite.swift
rm -f Sources/OCCTSwift/SweepXcafShadow.swift
env -u BRIDGE_PREBUILT -u OCCTSWIFT_BRIDGE_PREBUILT swift build --build-tests
bundle=.build/out/Products/Debug/OCCTXCAFTests.xctest/Contents/MacOS/OCCTXCAFTests
echo "markers left in the bundle: $(strings "$bundle" | grep -c SWEEP_XCAF_SWITCH || true) (must be 0)"

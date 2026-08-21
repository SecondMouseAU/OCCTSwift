#!/usr/bin/env bash
#
# #967: what a CONSUMER of this package inherits, and the one shape that does not compile.
#
# Builds a throwaway consumer package with an Objective-C target that includes an OCCT header,
# three ways, and prints what each does. Row 1 is the reporter's failure. Rows 2 and 3 are the
# wall behind it.
#
# Usage:  bash Scripts/repro/967-consumer-compile/run.sh [workdir]
# Needs:  a resolvable kernel. A checkout with Libraries/OCCT.xcframework uses it; without one
#         SwiftPM downloads the pinned release asset on the first row.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/occtswift-967-consumer}"
PKG="$(basename "$REPO")"

rm -rf "$WORK"
# SwiftPM requires a public headers directory for a C-family target, so give it an empty one.
mkdir -p "$WORK/Sources/ConsumerObjC/include"
cat > "$WORK/Sources/ConsumerObjC/include/ConsumerObjC.h" <<'EOF'
// Deliberately empty: the target's public surface plays no part in #967.
EOF

write_manifest() {  # $1 = "" or a trailing cxxLanguageStandard clause
  cat > "$WORK/Package.swift" <<EOF
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Consumer967",
    platforms: [.macOS(.v12)],
    products: [.library(name: "ConsumerObjC", targets: ["ConsumerObjC"])],
    dependencies: [.package(path: "$REPO")],
    targets: [
        .target(name: "ConsumerObjC",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ConsumerObjC")
    ]$1
)
EOF
}

write_source() {  # $1 = .m or .mm
  rm -f "$WORK/Sources/ConsumerObjC/Repro967.m" "$WORK/Sources/ConsumerObjC/Repro967.mm"
  cat > "$WORK/Sources/ConsumerObjC/Repro967$1" <<'EOF'
// A consumer's own translation unit reaching for OCCT's C++ API directly, the shape #967 reported.
#import <Foundation/Foundation.h>
#include <STEPControl_Reader.hxx>

@interface Repro967 : NSObject
@end
@implementation Repro967
@end
EOF
}

row() {  # $1 = label, $2 = extension, $3 = manifest suffix
  echo
  echo "########## $1 ##########"
  write_source "$2"
  write_manifest "$3"
  ( cd "$WORK" && swift build --target ConsumerObjC 2>&1 ) \
    | grep -E "error:|Build of target|Compiling ConsumerObjC" | head -6
}

row "row 1: Objective-C (.m), the reported failure" ".m" ""
row "row 2: Objective-C++ (.mm), consumer manifest declares no C++ standard" ".mm" ""
row "row 3: Objective-C++ (.mm), consumer manifest declares cxxLanguageStandard: .cxx17" ".mm" ",
    cxxLanguageStandard: .cxx17"
echo
echo "Workdir kept at $WORK"

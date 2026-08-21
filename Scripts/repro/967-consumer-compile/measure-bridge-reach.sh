#!/usr/bin/env bash
#
# #967: how far into this package can a CONSUMER actually reach?
#
# `OCCTBridge` is a target and not a product, which is easy to read as "unreachable". It is not.
# Both of these work, and this script is the evidence:
#
#   a Swift target in a consumer package writing `import OCCTBridge`
#   an Objective-C .m in a consumer package writing `#import "OCCTBridge.h"`
#
# because `publicHeadersPath: "include"` and the hand-written module.modulemap in it travel with the
# target along the transitive include path. Nothing here recommends the route: the C surface carries
# no compatibility promise (docs/architecture/overview.md section 6). It exists so that no document
# in this repo claims impossibility again.
#
# Usage:  bash Scripts/repro/967-consumer-compile/measure-bridge-reach.sh [workdir]
# Exit:   0 if both reach the bridge, 1 otherwise.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/occtswift-967-bridge-reach}"
PKG="$(basename "$REPO")"
FAILURES=0

case "$WORK" in
  /*) ;;
  *) echo "workdir must be an absolute path, got '$WORK'" >&2; exit 2 ;;
esac
if [ -e "$WORK" ] && [ ! -f "$WORK/.occtswift-967-workdir" ]; then
  echo "refusing to delete '$WORK': it exists and this script did not create it" >&2
  exit 2
fi
rm -rf "$WORK"
mkdir -p "$WORK/Sources/SwiftReach" "$WORK/Sources/ObjCReach/include"
: > "$WORK/.occtswift-967-workdir"

cat > "$WORK/Package.swift" <<EOF
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BridgeReach",
    platforms: [.macOS(.v12)],
    dependencies: [.package(path: "$REPO")],
    targets: [
        .executableTarget(name: "SwiftReach",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/SwiftReach"),
        .executableTarget(name: "ObjCReach",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ObjCReach"),
    ]
)
EOF

cat > "$WORK/Sources/SwiftReach/main.swift" <<'EOF'
import OCCTSwift
import OCCTBridge   // OCCTBridge is not a product; this still resolves.

var v = 0.0
let box = OCCTShapeCreateBox(2.0, 3.0, 4.0)
_ = OCCTShapeGetVolume(box, &v)
OCCTShapeRelease(box)
print("swift import OCCTBridge volume:", v)
EOF

cat > "$WORK/Sources/ObjCReach/include/ObjCReach.h" <<'EOF'
// Deliberately empty.
EOF
cat > "$WORK/Sources/ObjCReach/main.m" <<'EOF'
#import <Foundation/Foundation.h>
#import "OCCTBridge.h"   // a plain .m, no .mm and no C++17 anywhere.

int main(void) {
  double v = 0.0;
  OCCTShapeRef box = OCCTShapeCreateBox(2.0, 3.0, 4.0);
  OCCTShapeGetVolume(box, &v);
  OCCTShapeRelease(box);
  printf("objc #import OCCTBridge.h volume: %.17g\n", v);
  return 0;
}
EOF

for t in SwiftReach ObjCReach; do
  echo
  echo "########## $t ##########"
  out="$( cd "$WORK" && swift run "$t" 2>&1 )"
  echo "$out" | grep -E "error:|volume:" | head -4
  if echo "$out" | grep -q "volume: 23.999999999999996"; then
    echo "  -> reached the bridge: OK"
  else
    echo "  -> did not reach the bridge: MISMATCH"
    FAILURES=$((FAILURES + 1))
  fi
done

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "both routes reach the C bridge from a consumer package"
else
  echo "$FAILURES route(s) did not. The packaging has changed, or the bridge has."
fi
echo "Workdir kept at $WORK"
exit $([ "$FAILURES" -eq 0 ] && echo 0 || echo 1)

#!/usr/bin/env bash
#
# #967: what a CONSUMER of this package inherits, and the shapes that do not compile.
#
# Builds a throwaway consumer package against this checkout and checks each row against the outcome
# it is supposed to have. Rows 1 to 5 are Swift-only consumers, four library targets and an
# executable, which are the shapes the guide's headline claim ("a Swift target needs nothing")
# rests on. Rows 6 to 10 put an OCCT include in the consumer's own C-family file: row 6 is the
# reporter's failure and rows 7 to 10 are the wall behind it and the two ways through.
#
# Usage:  bash Scripts/repro/967-consumer-compile/run.sh [workdir]
# Exit:   0 if every row matched its expected outcome, 1 otherwise.
# Needs:  a resolvable kernel. A checkout with Libraries/OCCT.xcframework uses it; without one
#         SwiftPM downloads the pinned release asset on the first row. No network otherwise: this
#         resolves the package by PATH. The by-URL row of README.md's grid is not scripted here for
#         that reason, and its captured output is committed as url-consumer.txt instead.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/occtswift-967-consumer}"
PKG="$(basename "$REPO")"
FAILURES=0
ROW=0

# Only ever delete a directory this script made, or one that does not exist yet. $WORK is taken
# verbatim from $1, and an `rm -rf` on a mistyped path is not a mistake worth being able to make.
case "$WORK" in
  /*) ;;
  *) echo "workdir must be an absolute path, got '$WORK'" >&2; exit 2 ;;
esac
if [ -e "$WORK" ] && [ ! -f "$WORK/.occtswift-967-workdir" ]; then
  echo "refusing to delete '$WORK': it exists and this script did not create it" >&2
  exit 2
fi
rm -rf "$WORK"
# SwiftPM requires a public headers directory for a C-family target, so give it an empty one.
mkdir -p "$WORK/Sources/ConsumerLang/include" "$WORK/Sources/ConsumerSwift" "$WORK/Sources/ConsumerExe"
: > "$WORK/.occtswift-967-workdir"
cat > "$WORK/Sources/ConsumerLang/include/ConsumerLang.h" <<'EOF'
// Deliberately empty: the target's public surface plays no part in #967.
EOF
cat > "$WORK/Sources/ConsumerExe/main.swift" <<'EOF'
import OCCTSwift

print(Shape.box(width: 10, height: 10, depth: 10) != nil)
EOF

# $1 = "" or a trailing cxxLanguageStandard clause, $2 = the ConsumerSwift target's swiftSettings.
write_manifest() {
  cat > "$WORK/Package.swift" <<EOF
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Consumer967",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "ConsumerLang", targets: ["ConsumerLang"]),
        .library(name: "ConsumerSwift", targets: ["ConsumerSwift"]),
    ],
    dependencies: [.package(path: "$REPO")],
    targets: [
        .target(name: "ConsumerLang",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ConsumerLang"),
        .target(name: "ConsumerSwift",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ConsumerSwift"$2),
        .executableTarget(name: "ConsumerExe",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ConsumerExe"),
    ]$1
)
EOF
}

# $1 = file extension. Each row gets its own basename so its compile line is always emitted on a
# real run: two rows sharing a name would let a cached object hide a row that was never compiled.
write_lang_source() {
  rm -f "$WORK"/Sources/ConsumerLang/Repro967_*
  local f="$WORK/Sources/ConsumerLang/Repro967_row$ROW$1"
  # A consumer's own translation unit reaching for OCCT's C++ API directly, the shape #967 reported.
  # Foundation only where the language has Objective-C, so each row tests the include chain alone.
  case "$1" in
    .m|.mm) printf '#import <Foundation/Foundation.h>\n' > "$f" ;;
    *)      : > "$f" ;;
  esac
  printf '#include <STEPControl_Reader.hxx>\nint occtRepro967_row%s(void) { return 0; }\n' "$ROW" >> "$f"
}

# $1 = the body of a function that touches the Swift API.
write_swift_source() {
  rm -f "$WORK"/Sources/ConsumerSwift/*.swift
  cat > "$WORK/Sources/ConsumerSwift/Consumer_row$ROW.swift" <<EOF
import OCCTSwift

public func consumerRow$ROW() -> Bool {
$1
}
EOF
}

classify() {  # $1 = build output, $2 = the compile line that must be present
  if ! echo "$1" | grep -q "$2"; then
    # SwiftPM reports "Build of target ... complete" for a target whose sources it never handled,
    # so a green build alone is not evidence that the file under test was compiled at all.
    echo "not_compiled"
  elif echo "$1" | grep -q "'type_traits' file not found"; then
    echo "type_traits"
  elif echo "$1" | grep -qE "is_trivially_copyable_v|is_trivially_destructible_v|in_place_t"; then
    echo "cxx17"
  elif echo "$1" | grep -q "Build of target"; then
    echo "pass"
  else
    echo "other"
  fi
}

verdict() {  # $1 = expected, $2 = actual
  if [ "$2" = "$1" ]; then
    echo "  -> expected $1, got $2: OK"
  else
    echo "  -> expected $1, got $2: MISMATCH"
    FAILURES=$((FAILURES + 1))
  fi
}

# $1 = label, $2 = swift body, $3 = ConsumerSwift swiftSettings clause, $4 = expected
swift_row() {
  ROW=$((ROW + 1))
  echo
  echo "########## row $ROW: $1 ##########"
  write_swift_source "$2"
  write_manifest "" "$3"
  local out
  out="$( cd "$WORK" && swift build --target ConsumerSwift 2>&1 )"
  echo "$out" | grep -E "error:|Build of target" | head -4
  verdict "$4" "$(classify "$out" "Compiling ConsumerSwift Consumer_row$ROW.swift")"
}

# $1 = label, $2 = expected. The executable's source is fixed, so this row differs from the
# library rows only in the product kind, which is the thing it is here to cover.
exe_row() {
  ROW=$((ROW + 1))
  echo
  echo "########## row $ROW: $1 ##########"
  write_manifest "" ""
  local out
  out="$( cd "$WORK" && swift build --target ConsumerExe 2>&1 )"
  echo "$out" | grep -E "error:|Build of target" | head -4
  verdict "$2" "$(classify "$out" "Compiling ConsumerExe main.swift")"
}

# $1 = label, $2 = extension, $3 = manifest cxxLanguageStandard clause, $4 = expected
lang_row() {
  ROW=$((ROW + 1))
  echo
  echo "########## row $ROW: $1 ##########"
  write_lang_source "$2"
  write_manifest "$3" ""
  local out
  out="$( cd "$WORK" && swift build --target ConsumerLang 2>&1 )"
  echo "$out" | grep -E "error:|Build of target" | head -4
  verdict "$4" "$(classify "$out" "Compiling ConsumerLang Repro967_row$ROW$2")"
}

CXX17=",
    cxxLanguageStandard: .cxx17"
INTEROP=",
                swiftSettings: [.interoperabilityMode(.Cxx)]"

BOX='    return Shape.box(width: 10, height: 10, depth: 10) != nil'
TYPES='    guard let s = Shape.box(width: 10, height: 10, depth: 10) else { return false }
    let mesh = s.mesh(linearDeflection: 0.1)
    let surf = Surface.plane(origin: SIMD3<Double>(0, 0, 0), normal: SIMD3<Double>(0, 0, 1))
    let curve = Curve3D.line(through: SIMD3<Double>(0, 0, 0), direction: SIMD3<Double>(1, 0, 0))
    let doc = Document.create()
    return mesh != nil && surf != nil && curve != nil && doc != nil'

swift_row "Swift target, import only, no settings"                      "    return true"  ""         pass
swift_row "Swift target calling the API"                                "$BOX"             ""         pass
swift_row "Swift target with .interoperabilityMode(.Cxx)"               "$BOX"             "$INTEROP" pass
swift_row "Swift target touching Mesh, Surface, Curve3D and Document"   "$TYPES"           ""         pass
exe_row  "Swift executable target"                                                                pass

lang_row "Objective-C (.m), the reported failure"                       ".m"   ""       type_traits
lang_row "C (.c), the same missing C++ standard library"                ".c"   ""       type_traits
lang_row "Objective-C++ (.mm), manifest declares no C++ standard"       ".mm"  ""       cxx17
lang_row "Objective-C++ (.mm), manifest declares cxxLanguageStandard"   ".mm"  "$CXX17" pass
lang_row "C++ (.cpp), manifest declares cxxLanguageStandard"            ".cpp" "$CXX17" pass

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "all $ROW rows matched their expected outcome"
else
  echo "$FAILURES of $ROW row(s) did not match. The finding has changed, or the diagnostics have."
fi
echo "Workdir kept at $WORK"
exit $([ "$FAILURES" -eq 0 ] && echo 0 || echo 1)

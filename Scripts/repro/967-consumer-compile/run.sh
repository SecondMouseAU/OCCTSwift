#!/usr/bin/env bash
#
# #967: what a CONSUMER of this package inherits, and the shapes that do not compile.
#
# Builds a throwaway consumer package whose own target includes an OCCT header, five ways, and
# checks each against the outcome it is supposed to have. Row 1 is the reporter's failure. Rows 2
# to 5 are the wall behind it and the two ways through.
#
# Usage:  bash Scripts/repro/967-consumer-compile/run.sh [workdir]
# Exit:   0 if every row matched its expected outcome, 1 otherwise.
# Needs:  a resolvable kernel. A checkout with Libraries/OCCT.xcframework uses it; without one
#         SwiftPM downloads the pinned release asset on the first row.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/occtswift-967-consumer}"
PKG="$(basename "$REPO")"
FAILURES=0

rm -rf "$WORK"
# SwiftPM requires a public headers directory for a C-family target, so give it an empty one.
mkdir -p "$WORK/Sources/ConsumerLang/include"
cat > "$WORK/Sources/ConsumerLang/include/ConsumerLang.h" <<'EOF'
// Deliberately empty: the target's public surface plays no part in #967.
EOF

write_manifest() {  # $1 = "" or a trailing cxxLanguageStandard clause
  cat > "$WORK/Package.swift" <<EOF
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Consumer967",
    platforms: [.macOS(.v12)],
    products: [.library(name: "ConsumerLang", targets: ["ConsumerLang"])],
    dependencies: [.package(path: "$REPO")],
    targets: [
        .target(name: "ConsumerLang",
                dependencies: [.product(name: "OCCTSwift", package: "$PKG")],
                path: "Sources/ConsumerLang")
    ]$1
)
EOF
}

write_source() {  # $1 = .m / .c / .mm / .cpp
  rm -f "$WORK"/Sources/ConsumerLang/Repro967.*
  # A consumer's own translation unit reaching for OCCT's C++ API directly, the shape #967 reported.
  # Foundation only where the language has Objective-C, so each row tests the include chain and
  # nothing else.
  case "$1" in
    .m|.mm) printf '#import <Foundation/Foundation.h>\n' > "$WORK/Sources/ConsumerLang/Repro967$1" ;;
    *)      : > "$WORK/Sources/ConsumerLang/Repro967$1" ;;
  esac
  printf '#include <STEPControl_Reader.hxx>\nint occtRepro967(void) { return 0; }\n' \
    >> "$WORK/Sources/ConsumerLang/Repro967$1"
}

# $1 = label, $2 = extension, $3 = manifest suffix, $4 = expected: type_traits | cxx17 | pass
row() {
  echo
  echo "########## $1 ##########"
  write_source "$2"
  write_manifest "$3"
  local out
  out="$( cd "$WORK" && swift build --target ConsumerLang 2>&1 )"
  echo "$out" | grep -E "error:|Build of target" | head -4

  local actual="other"
  if echo "$out" | grep -q "'type_traits' file not found"; then
    actual="type_traits"
  elif echo "$out" | grep -qE "is_trivially_copyable_v|is_trivially_destructible_v|in_place_t"; then
    actual="cxx17"
  elif echo "$out" | grep -q "Build of target"; then
    actual="pass"
  fi

  if [ "$actual" = "$4" ]; then
    echo "  -> expected $4, got $actual: OK"
  else
    echo "  -> expected $4, got $actual: MISMATCH"
    FAILURES=$((FAILURES + 1))
  fi
}

CXX17=",
    cxxLanguageStandard: .cxx17"

row "row 1: Objective-C (.m), the reported failure"                        ".m"   ""       type_traits
row "row 2: C (.c), the same missing C++ standard library"                 ".c"   ""       type_traits
row "row 3: Objective-C++ (.mm), manifest declares no C++ standard"        ".mm"  ""       cxx17
row "row 4: Objective-C++ (.mm), manifest declares cxxLanguageStandard"    ".mm"  "$CXX17" pass
row "row 5: C++ (.cpp), manifest declares cxxLanguageStandard"             ".cpp" "$CXX17" pass

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "all 5 rows matched their expected outcome"
else
  echo "$FAILURES row(s) did not match. The finding has changed, or the diagnostics have."
fi
echo "Workdir kept at $WORK"
exit $([ "$FAILURES" -eq 0 ] && echo 0 || echo 1)

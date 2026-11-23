#!/bin/bash
# #3506: IntCurve_IntConicConic::Perform never returns for a circle or ellipse with no radius, or a
# domain with an infinite parameter, and so BRepCheck_Analyzer never returns on a BREP that carries
# a pcurve circle of radius 0.
#
# Usage, from the repository root:
#   Scripts/repro/3506/run.sh <OCCT.xcframework> [patched-object.o ...]
#
# With only the xcframework it measures that kernel. To measure the fix without a kernel rebuild,
# pass the patched translation unit compiled with the kernel's own flags, which links ahead of the
# archive (the override-link technique of okf/policies/upstream-occt-patch-process.md):
#   clang++ -std=c++17 -w -O3 -DNDEBUG -DNo_Exception -arch arm64 -I <xcf>/macos-arm64/Headers \
#     -c <patched tree>/src/ModelingAlgorithms/TKGeomAlgo/IntCurve/IntCurve_IntConicConic_1.cxx \
#     -o IntCurve_IntConicConic_1.cxx.o
#
# Part 1 runs probe.cxx: 23 direct calls of the three overloads, each in its own process with a
# 3 second alarm. Part 2 builds the shape of the issue: Scripts/repro/3487's fused.brep with the
# radius of its first circle pcurve edited, read and checked in its own process with that probe's
# 20 second watchdog. Neither part installs OSD::SetSignal.
set -u

XCF="${1:?usage: run.sh <OCCT.xcframework> [patched-object.o ...]}"
shift
K="$XCF/macos-arm64"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
WORK="$(mktemp -d)"
LINK=(-L "$K" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)

echo "== part 1: direct probe, 23 cases"
clang++ -std=c++17 -w -g -I "$K/Headers" "$HERE/probe.cxx" "$@" "${LINK[@]}" -o "$WORK/probe" || exit 1
"$WORK/probe"

echo
echo "== part 2: fused.brep with the first circle pcurve's radius edited"
clang++ -std=c++17 -ObjC++ -w -g -I "$K/Headers" "$ROOT/Scripts/repro/3487/probe.mm" "$@" "${LINK[@]}" \
  -o "$WORK/p3487" || exit 1
mkdir -p "$WORK/corpus"
"$WORK/p3487" gen "$WORK/corpus" > /dev/null
python3 - "$WORK" <<'PY'
import re, subprocess, sys
work = sys.argv[1]
base = open(work + "/corpus/fused.brep").read()
table = base.index("Curve2ds")
end = base.index("Curves ", table)
block = base[table:end]
match = re.search(r"(?m)^(2 (?:\S+ ){6})(\S+)$", block)
assert match and match.group(2) == "5", "the first circle record is not where this script expects it"
for token in ["5", "0", "1e-300", "1e-20", "1e-12", "nan", "inf"]:
    text = base[:table] + block[:match.start()] + match.group(1) + token + block[match.end():] + base[end:]
    path = "%s/radius-%s.brep" % (work, token)
    open(path, "w").write(text)
    try:
        r = subprocess.run([work + "/p3487", "read", "bridge", path], capture_output=True, text=True,
                           timeout=60)
        result = [l for l in r.stdout.splitlines() if l.startswith("RESULT")]
        verdict = result[0].replace("RESULT shape ret=1 ", "") if result else "does not return (rc %s)" % r.returncode
    except subprocess.TimeoutExpired:
        verdict = "does not return"
    print("  radius %-7s -> %s" % (token, verdict))
PY
echo
echo "work files in $WORK"

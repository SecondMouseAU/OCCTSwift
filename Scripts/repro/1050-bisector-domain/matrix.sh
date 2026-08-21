#!/bin/bash
# Measure the #1050 removal matrix mechanically: every injection against every one of the ten tests
# in Issue1050BisectorDomainTests + BisectorIntersectionTests, capturing the failing test NAMES
# rather than a count, restoring the bridge file after each row and verifying the restore is
# byte-identical at the end.
#
# The README's matrix is generated from this rather than maintained by hand, because it was
# maintained by hand once: the table was carried from a six-test suite to a nine-test one by editing
# the denominator, and two of its rows were then wrong.
#
# Run it from the repo root. It needs a source-built bridge and a local kernel, which it arranges
# itself rather than depending on an ambient environment: OCCTSWIFT_BRIDGE_PREBUILT is exported to 1
# by some shell profiles in this project, and with it set the .mm edits below are not compiled at
# all and every row comes back green for the wrong reason.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MM="$W/Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm"
TMP="$(mktemp -d)"
GOOD="$TMP/Geom2d-baseline.mm"
OUT="${MATRIX_OUT:-$W/Scripts/repro/1050-bisector-domain/probe-output-matrix.txt}"

unset OCCTSWIFT_BRIDGE_PREBUILT BRIDGE_PREBUILT REIFY_FORCE_URL_DEPS
export OCCTSWIFT_LOCAL=1
cd "$W" || exit 1

if [ ! -d "$W/Libraries/OCCT.xcframework" ]; then
  echo "no Libraries/OCCT.xcframework: symlink or build one first, see CLAUDE.md" >&2
  exit 2
fi

cp "$MM" "$GOOD"
: > "$OUT"
trap 'cp "$GOOD" "$MM"; rm -rf "$TMP"' EXIT

row () {
  local label="$1"; local script="$2"
  cp "$GOOD" "$MM"
  python3 - "$MM" <<PYEOF
import sys
p = sys.argv[1]
s = open(p).read()
$script
open(p, 'w').write(s)
PYEOF
  echo "=== $label ===" >> "$OUT"
  swift test --filter "BisectorIntersectionTests|Issue1050BisectorDomainTests" 2>&1 \
    | grep -E '^✘ Test "' | sed 's/ recorded an issue.*//; s/ failed after.*//' | sort -u >> "$OUT"
  echo "" >> "$OUT"
  cp "$GOOD" "$MM"
}

row "A  shipped [-100, 100]" '
old = """    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    const double                       f1 = c1->FirstParameter();
    const double                       l1 = c1->LastParameter();
    const double                       f2 = c2->FirstParameter();
    const double                       l2 = c2->LastParameter();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);"""
new = """    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(-100)), -100.0, 1e-6, gp_Pnt2d(c1->Value(100)), 100.0, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(-100)), -100.0, 1e-6, gp_Pnt2d(c2->Value(100)), 100.0, 1e-6);"""
assert s.count(old) == 1
s = s.replace(old, new)
'

row "B  2 * input span + 1" '
old = """    const double                       f1 = c1->FirstParameter();
    const double                       l1 = c1->LastParameter();
    const double                       f2 = c2->FirstParameter();
    const double                       l2 = c2->LastParameter();"""
new = """    double sp = 0;
    { const double xs[4] = {ax,bx,cx,dx}; const double ys[4] = {ay,by,cy,dy};
      for (int i=0;i<4;++i) for (int j=i+1;j<4;++j)
        sp = std::max(sp, std::hypot(xs[i]-xs[j], ys[i]-ys[j])); }
    const double f1 = -(2*sp+1); const double l1 = 2*sp+1;
    const double f2 = -(2*sp+1); const double l2 = 2*sp+1;"""
assert s.count(old) == 1
s = s.replace(old, new)
'

row "C  unbounded IntRes2d_Domain()" '
old = """    const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
    const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
    const double                       f1 = c1->FirstParameter();
    const double                       l1 = c1->LastParameter();
    const double                       f2 = c2->FirstParameter();
    const double                       l2 = c2->LastParameter();
    IntRes2d_Domain d1(gp_Pnt2d(c1->Value(f1)), f1, 1e-6, gp_Pnt2d(c1->Value(l1)), l1, 1e-6);
    IntRes2d_Domain d2(gp_Pnt2d(c2->Value(f2)), f2, 1e-6, gp_Pnt2d(c2->Value(l2)), l2, 1e-6);"""
new = """    IntRes2d_Domain d1;
    IntRes2d_Domain d2;"""
assert s.count(old) == 1
s = s.replace(old, new)
'

row "D  swap pC/pD into b2.Perform" '
old = "    b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);"
new = "    b2.Perform(pD, pC, midCD, v3, v4, 1.0, 1e-6);"
assert s.count(old) == 1
s = s.replace(old, new)
'

row "E  Sense flipped to -1.0" '
old = "    b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);"
new = "    b2.Perform(pC, pD, midCD, v3, v4, -1.0, 1e-6);"
assert s.count(old) == 1
s = s.replace(old, new)
'

row "F  perpCD negated" '
old = """    gp_Vec2d                      vCD(dx - cx, dy - cy);"""
new = """    gp_Vec2d                      vCD(cx - dx, cy - dy);"""
assert s.count(old) == 1
s = s.replace(old, new)
'

echo "=== control: no injection ===" >> "$OUT"
swift test --filter "BisectorIntersectionTests|Issue1050BisectorDomainTests" 2>&1 \
  | grep -E '^✘ Test "' | sed 's/ recorded an issue.*//; s/ failed after.*//' | sort -u >> "$OUT"
echo "" >> "$OUT"

if diff -q "$GOOD" "$MM" >/dev/null; then
  echo "RESTORE VERIFIED: the bridge file is byte-identical to the pre-matrix state" >> "$OUT"
else
  echo "RESTORE FAILED" >> "$OUT"
fi
cat "$OUT"

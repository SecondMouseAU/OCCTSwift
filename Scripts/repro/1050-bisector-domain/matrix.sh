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
# Needs a source-built bridge, so it unsets OCCTSWIFT_BRIDGE_PREBUILT via run.sh and sets
# OCCTSWIFT_LOCAL=1. Paths are absolute to the worktree it was written in; edit W and S to re-run
# elsewhere.
set -u
W=/Users/elb/Projects/OCCTSwift/.claude/worktrees/agent-adb2ada8e9c638ce3
MM="$W/Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm"
S=/private/tmp/claude-501/-Users-elb-Projects-OCCTSwift/78bd6be9-ea7e-4eb6-915d-15d59201c18e/scratchpad
GOOD="$S/Geom2d-matrix-baseline-adb2ada8.mm"
RUN="$S/run-adb2ada8.sh"
OUT="$S/matrix-result-adb2ada8.txt"

cp "$MM" "$GOOD"
: > "$OUT"

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
  "$RUN" swift test --filter "BisectorIntersectionTests|Issue1050BisectorDomainTests" 2>&1 \
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

row "E  Sense flipped to -1.0 (reported inert)" '
old = "    b2.Perform(pC, pD, midCD, v3, v4, 1.0, 1e-6);"
new = "    b2.Perform(pC, pD, midCD, v3, v4, -1.0, 1e-6);"
assert s.count(old) == 1
s = s.replace(old, new)
'

row "F  perpCD negated (reported inert)" '
old = """    gp_Vec2d                      vCD(dx - cx, dy - cy);"""
new = """    gp_Vec2d                      vCD(cx - dx, cy - dy);"""
assert s.count(old) == 1
s = s.replace(old, new)
'

echo "=== control: no injection ===" >> "$OUT"
"$RUN" swift test --filter "BisectorIntersectionTests|Issue1050BisectorDomainTests" 2>&1 \
  | grep -E '^✘ Test "' | sed 's/ recorded an issue.*//' | sort -u >> "$OUT"
echo "" >> "$OUT"

if diff -q "$GOOD" "$MM" >/dev/null; then
  echo "RESTORE VERIFIED: the bridge file is byte-identical to the pre-matrix state" >> "$OUT"
else
  echo "RESTORE FAILED" >> "$OUT"
fi
cat "$OUT"

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
# OCCTBridge_Geom2d.mm no longer exists post-#1380 (chore(#819) retirement pass): split into 7
# files. All six injections below target Bisector_BisecAna calls, which landed in one of them.
MM="$W/Sources/OCCTBridge/src/OCCTBridge_Geom2d_Bisector.mm"
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
FAILED_ROWS=0
trap 'cp "$GOOD" "$MM"; rm -rf "$TMP"' EXIT

# EXPECTED_TESTS is how many tests must actually run. A row that fails to build, or whose python
# anchor does not match, or that runs zero tests because the filter stopped matching, would
# otherwise write an EMPTY row, and an empty row is byte-identical to the control row's "nothing
# failed". That is the silent-pass shape this file exists to replace, and its first version had
# exactly that defect: no exit status checked, swift test's status swallowed by a pipe, and nothing
# asserted about how many tests ran.
EXPECTED_TESTS=10

row () {
  local label="$1"; local script="$2"
  cp "$GOOD" "$MM"

  if ! python3 - "$MM" <<PYEOF
import sys
p = sys.argv[1]
s = open(p).read()
$script
open(p, 'w').write(s)
PYEOF
  then
    echo "=== $label ===" >> "$OUT"
    echo "ROW FAILED: the injection did not apply (anchor missed, or python error)" >> "$OUT"
    echo "" >> "$OUT"
    cp "$GOOD" "$MM"
    FAILED_ROWS=$((FAILED_ROWS + 1))
    return
  fi

  local log="$TMP/row.log"
  swift test --filter "BisectorIntersectionTests|Issue1050BisectorDomainTests" > "$log" 2>&1
  local status=$?

  echo "=== $label ===" >> "$OUT"

  # "Test run with N tests" is swift-testing's own tally. Absent, the run never reached the tests,
  # which is a build failure however green the (empty) failure list looks.
  local ran
  ran=$(sed -n 's/.*Test run with \([0-9][0-9]*\) tests.*/\1/p' "$log" | tail -1)
  if [ -z "$ran" ]; then
    echo "ROW FAILED: no test run happened (exit $status), almost certainly a build error:" >> "$OUT"
    grep -E "error:" "$log" | head -3 >> "$OUT"
    echo "" >> "$OUT"
    cp "$GOOD" "$MM"
    FAILED_ROWS=$((FAILED_ROWS + 1))
    return
  fi
  if [ "$ran" -ne "$EXPECTED_TESTS" ]; then
    echo "ROW FAILED: $ran tests ran, expected $EXPECTED_TESTS (the filter drifted, or a test was" >> "$OUT"
    echo "            added or removed without updating EXPECTED_TESTS in this script)" >> "$OUT"
    echo "" >> "$OUT"
    cp "$GOOD" "$MM"
    FAILED_ROWS=$((FAILED_ROWS + 1))
    return
  fi

  grep -E '^✘ Test "' "$log" | sed 's/ recorded an issue.*//; s/ failed after.*//' | sort -u >> "$OUT"
  echo "  ($ran tests ran)" >> "$OUT"
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

# The control goes through the same row(), with an injection that asserts rather than substitutes,
# so it is held to the same "did ten tests actually run" check as every other row. Run through a
# separate path it would be the one row that could pass while proving nothing.
row "control: no injection" '
assert s.count("IntRes2d_Domain d1(") == 1
'

if diff -q "$GOOD" "$MM" >/dev/null; then
  echo "RESTORE VERIFIED: the bridge file is byte-identical to the pre-matrix state" >> "$OUT"
else
  echo "RESTORE FAILED" >> "$OUT"
  FAILED_ROWS=$((FAILED_ROWS + 1))
fi

if [ "$FAILED_ROWS" -ne 0 ]; then
  echo "" >> "$OUT"
  echo "$FAILED_ROWS ROW(S) DID NOT PRODUCE A RESULT. The table above is incomplete." >> "$OUT"
fi
cat "$OUT"
if [ "$FAILED_ROWS" -ne 0 ]; then exit 1; fi

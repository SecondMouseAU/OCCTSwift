#!/bin/bash
# Inject the defect: make occtShapeIsPresent test only the pointer, i.e. exactly the pre-#1026
# state, with every call site left as this PR writes it. Then run each test of the suite in its
# OWN process, because the failure mode is a crash and one crash would otherwise hide the rest.
set -e
cd "$(git rev-parse --show-toplevel)"
BAK=$(mktemp)
unset OCCTSWIFT_BRIDGE_PREBUILT
export OCCTSWIFT_LOCAL=1

H=Sources/OCCTBridge/src/OCCTBridge_Internal.h
cp "$H" "$BAK"
python3 - "$H" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text()
old = "  return shape && !shape->shape.IsNull();"
new = "  return shape != nullptr; // INJECTED #1026 DEFECT: pointer only, no shape test"
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new))
print("injected")
PY

swift build 2>&1 | tail -2

TESTS=(
  shapeTypeOfANullifiedShapeIsUnknown
  isValidSolidOfANullifiedShapeIsFalse
  theFiveTypePredicatesAreFalseForANullifiedShape
  shapeTypeStringOfANullifiedShapeReadsNull
  typeNameOfANullifiedShapeIsNil
  intersectLineWithANullifiedShapeFindsNothing
  theFlagAccessorsRefuseANullifiedShape
  theFlagAccessorsStillAnswerForARealShape
  theGateFoundSitesRefuseANullifiedShape
  isEmptyShapeSeparatesANullifiedShapeFromARealOne
  edgeAndFaceRefuseANullifiedShape
  everyGuardedQueryStillAnswersForARealShape
  kernelSideDereferencesAreRefused
)
for t in "${TESTS[@]}"; do
  out=$(swift test --filter "Issue1026NullShapeTypeGuard/$t" 2>&1 || true)
  if echo "$out" | grep -q "signal code"; then
    verdict="CRASH $(echo "$out" | grep -o 'signal code [0-9]*' | head -1)"
  elif echo "$out" | grep -q "Test run with .* passed"; then
    verdict="pass"
  elif echo "$out" | grep -q "recorded an issue"; then
    verdict="FAIL (assertion)"
  else
    verdict="OTHER: $(echo "$out" | tail -2 | tr '\n' ' ')"
  fi
  printf '%-52s %s\n' "$t" "$verdict"
done

cp "$BAK" "$H"
echo "--- restored ---"
grep -c "INJECTED" "$H" || true

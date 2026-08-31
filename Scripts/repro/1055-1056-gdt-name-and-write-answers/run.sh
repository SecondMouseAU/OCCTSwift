#!/bin/bash
# #1055 / #1056: the injection matrix behind the two suites, re-runnable.
#
# Each injection restores one of the three defects in the tree as it stood before the fix, rebuilds,
# runs the two suites, and reports which cases go red. That is the measurement the PR reports, and
# a suite that stays green under its own injection is a suite proving nothing, which is the whole
# reason this script exists rather than a paragraph claiming the same.
#
#   ./run.sh          every injection in turn
#   ./run.sh A1       one injection
#
# Injections:
#   A1   OCCTDocumentGetDatumName reports the copied length, not the whole one (#1055's contract)
#   A2a  drop the negative-maxLen half of the argument guard
#   A2b  drop the null-outName half of the argument guard (SIGSEGVs, see the README)
#   A3   Document.datumName drops its resize-and-retry, keeping the first call's answer
#   B    occtDocumentCreateDimensionImpl applies the tolerance and ignores the refusal (#1056 site 1)
#   C    SetValueOfZoneModifier stops clearing under _None (#1056 site 2)
#
# Requires a local Libraries/OCCT.xcframework. The tree must be clean in the files it edits, so
# it can never clobber uncommitted work; it restores from its own copies on exit either way.
#
# Repointed post-#1380/PR #1388 (chore(#819) retirement pass): OCCTBridge_Document.mm no longer
# exists, split into 6 files. OCCTDocumentGetDatumName and the SetValueOfZoneModifier call (#1056
# site 2) both landed in OCCTBridge_Document_GDT.mm. occtDocumentCreateDimensionImpl is a `static`
# helper the split duplicated verbatim into all 6 (the #396/#1380 shared-helper pattern
# check-null-handle-guards.py's is_allowed() docstring also describes), but only ONE copy is ever
# actually called: OCCTDocumentCreateDimensionWithTolerance's own local copy in
# OCCTBridge_Document_DocumentLifecycle.mm (#1056 site 1). Injection B has to land there, not in
# GDT.mm, or it edits a copy nothing calls and the row silently proves nothing -- exactly the
# stale-anchor failure mode the comment on A3 below already warns about, just one level up (a
# dead FILE instead of a dead anchor).
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GDT="$REPO/Sources/OCCTBridge/src/OCCTBridge_Document_GDT.mm"
LIFECYCLE="$REPO/Sources/OCCTBridge/src/OCCTBridge_Document_DocumentLifecycle.mm"
SWIFT="$REPO/Sources/OCCTSwift/GDTRead.swift"
FILTER='Issue1055DatumNameLengthTests|Issue1056GDTWriteAnswerTests'

dirty=$(cd "$REPO" && git status --porcelain -- \
  Sources/OCCTBridge/src/OCCTBridge_Document_GDT.mm \
  Sources/OCCTBridge/src/OCCTBridge_Document_DocumentLifecycle.mm \
  Sources/OCCTSwift/GDTRead.swift)
if [ -n "$dirty" ]; then
  echo "refusing to run: the files this edits have uncommitted changes" >&2
  echo "$dirty" >&2
  exit 2
fi

# After the refusal above, so a refused run leaves nothing behind to clean up.
STASH="$(mktemp -d)"
cp "$GDT" "$STASH/OCCTBridge_Document_GDT.mm"
cp "$LIFECYCLE" "$STASH/OCCTBridge_Document_DocumentLifecycle.mm"
cp "$SWIFT" "$STASH/GDTRead.swift"
restore() {
  cp "$STASH/OCCTBridge_Document_GDT.mm" "$GDT"
  cp "$STASH/OCCTBridge_Document_DocumentLifecycle.mm" "$LIFECYCLE"
  cp "$STASH/GDTRead.swift" "$SWIFT"
  rm -rf "$STASH"
}
trap restore EXIT

inject() {
  python3 - "$1" "$GDT" "$LIFECYCLE" "$SWIFT" <<'PY'
import sys

which, gdt_path, lifecycle_path, swift_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
EDITS = {
    "A1": (
        "gdt",
        "    return length;",
        "    return (maxLen > 0) ? std::min(length, maxLen - 1) : length;",
    ),
    "A2a": (
        "gdt",
        "  if (maxLen < 0 || (maxLen > 0 && !outName))\n    return -1;",
        "  if (maxLen > 0 && !outName)\n    return -1;",
    ),
    "A2b": (
        "gdt",
        "  if (maxLen < 0 || (maxLen > 0 && !outName))\n    return -1;",
        "  if (maxLen < 0)\n    return -1;",
    ),
    # One line, deliberately. An anchor spanning the whole resize block went stale the moment a
    # review added a comment inside it, and the row silently stopped running; `length >= 0` always
    # holds by the guard above, so the retry is never reached and the wrapper keeps the first
    # call's answer, which is the defect this row is for.
    "A3": (
        "swift",
        "        if Int(length) < short.count { return Self.string(fromCString: short) }",
        "        if Int(length) >= 0 { return Self.string(fromCString: short) }",
    ),
    "B": (
        "lifecycle",
        "    if (withTolerance && !occtDimensionApplyTolerance(dimObj, lowerTol, upperTol))\n      return -1;",
        "    if (withTolerance)\n      occtDimensionApplyTolerance(dimObj, lowerTol, upperTol);",
    ),
    "C": (
        "gdt",
        "    tolObj->SetValueOfZoneModifier((!none && value > 0.0) ? value : 0.0);",
        "    tolObj->SetValueOfZoneModifier(value > 0.0 ? value : 0.0);",
    ),
}
target, old, new = EDITS[which]
path = {"gdt": gdt_path, "lifecycle": lifecycle_path, "swift": swift_path}[target]
text = open(path).read()
if old not in text:
    sys.exit(f"injection {which}: anchor not found in {path}")
open(path, "w").write(text.replace(old, new, 1))
PY
}

run_one() {
  local which="$1"
  echo
  echo "=== injection $which"
  # A stale anchor is fatal, not a skipped row. An anchor that no longer matches means the row is
  # measuring nothing, and a row measuring nothing that keeps going looks exactly like a row that
  # passed. That happened once already, to A3, when a review added a comment inside its anchor.
  if ! inject "$which"; then
    echo "aborting: injection $which could not be applied" >&2
    exit 1
  fi
  ( cd "$REPO" && unset OCCTSWIFT_BRIDGE_PREBUILT \
      && OCCTSWIFT_LOCAL=1 swift test --filter "$FILTER" 2>&1 \
      | grep -E '✘ Test "|Test run with|unexpected signal' )
  cp "$STASH/OCCTBridge_Document_GDT.mm" "$GDT"
  cp "$STASH/OCCTBridge_Document_DocumentLifecycle.mm" "$LIFECYCLE"
  cp "$STASH/GDTRead.swift" "$SWIFT"
}

echo "=== baseline, no injection"
( cd "$REPO" && unset OCCTSWIFT_BRIDGE_PREBUILT \
    && OCCTSWIFT_LOCAL=1 swift test --filter "$FILTER" 2>&1 | grep -E 'Test run with' )

if [ "$#" -gt 0 ]; then
  run_one "$1"
else
  for which in A1 A2a A2b A3 B C; do run_one "$which"; done
fi

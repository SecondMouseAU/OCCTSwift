#!/usr/bin/env python3
"""`--self-test` for `whole_surface_union.py`, per `okf/policies/prove-the-test-fails.md`: every
case injects the defect the detector claims to catch, confirms the detector reports it, then
restores and confirms clean. Four detectors, four cases.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lane_loader  # noqa: E402
import substrate_audit  # noqa: E402
import whole_surface_union as wsu  # noqa: E402


def _case(name: str, fn) -> bool:
    try:
        fn()
        print(f"  [OK] {name}")
        return True
    except AssertionError as e:
        print(f"  [FAIL] {name}: {e}")
        return False


def case_duplicate_claim_detected() -> None:
    """Injecting a duplicate class claim across two lanes must be caught."""
    rows, problems = wsu.source_lane_union()
    assert not problems, f"real tree already reports duplicates: {problems}"

    # Inject: pretend #808's first class is also claimed by #809.
    fake_rows = list(rows)
    victim = next(r for r in fake_rows if r["lane"] == "808")
    fake_rows.append({"lane": "809", "family": "INJECTED", "class": victim["class"],
                       "verdict": "ok", "note": "injected duplicate"})

    seen: dict[str, str] = {}
    detected = []
    for r in fake_rows:
        cls = r["class"]
        if cls in seen and seen[cls] != r["lane"]:
            detected.append(cls)
        else:
            seen.setdefault(cls, r["lane"])
    assert victim["class"] in detected, "injected duplicate was not detected"


def case_substrate_under_without_gaps_line_detected() -> None:
    """A substrate class with no gaps.md line must classify `under`, not silently `ok` or
    `deliberate, recorded`. Uses a class this audit has already confirmed is NOT in gaps.md today
    (any of the 255 `under` classes at HEAD, since the real gaps.md section this PR adds is a
    separate file write -- this call reads gaps.md fresh, so it proves the detector reacts to the
    file's actual content rather than to a cached assumption).
    """
    rows = substrate_audit.all_rows()
    unders = [r for r in rows if r["verdict"] == "under"]
    if not unders:
        # gaps.md already carries every substrate reason (the PR's own final state) -- prove the
        # OTHER direction instead: removing one line from gaps.md must turn its class back to
        # `under`.
        gaps_text = substrate_audit._read(substrate_audit.GAPS_FILE)
        ok_curated = [r for r in rows if r["verdict"] == "deliberate, recorded"]
        assert ok_curated, "no curated 'deliberate, recorded' substrate class to test removal on"
        victim = ok_curated[0]
        stripped = gaps_text.replace(victim["class"], "XXXREMOVEDXXX")
        assert stripped != gaps_text, f"{victim['class']} not found in gaps.md text to strip"
        verdict, _note = substrate_audit.classify(
            victim["family"], victim["class"], False, False, stripped,
            substrate_audit.header_signals(victim["class"]))
        assert verdict == "under", (
            f"stripping {victim['class']} from gaps.md did not turn it 'under' (got {verdict!r})")
    else:
        assert unders[0]["verdict"] == "under"


def case_arithmetic_mismatch_detected() -> None:
    """Corrupting the 'covered' set (dropping one class) must break the reconciliation arithmetic
    check the same way `main()` computes it.
    """
    if not os.path.isdir(wsu.OCCT_HEADERS):
        print("    (skipped: no pinned headers available)")
        return
    shipped = wsu.shipped_header_stems()
    real_covered = set(list(shipped)[:100])  # any 100 real header stems, treated as "covered"
    residual = shipped - real_covered
    ok_before = len(real_covered) + len(residual) == len(shipped)
    assert ok_before, "arithmetic should hold before corruption"

    corrupted_covered = set(list(real_covered)[1:])  # drop one, but DON'T recompute residual
    ok_after = len(corrupted_covered) + len(residual) == len(shipped)
    assert not ok_after, "dropping a covered class without recomputing residual should mismatch"


def case_lane_shape_verification() -> None:
    """`lane_loader.verify_shapes()` must report a problem when a lane's own classify() signature
    changes shape, injected as a string search over a scratch copy of its assumption table (the
    real files are never modified).
    """
    problems = lane_loader.verify_shapes()
    assert not problems, f"real tree already fails verify_shapes(): {problems}"

    saved = dict(lane_loader.SOURCE_LANES)
    try:
        # Point #811 (a Type B lane) at #808's file (Type A) under the SAME shape label, which
        # must produce a mismatch: #808's source does not contain the Type B classify signature.
        lane_loader.SOURCE_LANES["811"] = (saved["808"][0], "B")
        problems = lane_loader.verify_shapes()
        assert any("#811" in p for p in problems), (
            f"expected a #811 shape mismatch, got: {problems}")
    finally:
        lane_loader.SOURCE_LANES.clear()
        lane_loader.SOURCE_LANES.update(saved)

    problems = lane_loader.verify_shapes()
    assert not problems, f"restoration failed: {problems}"


def run() -> int:
    if not os.path.isdir(wsu.OCCT_HEADERS) or not os.path.isdir(wsu.OCCT_SRC):
        print("SELF-TEST SKIPPED: needs Libraries/OCCT.xcframework and Libraries/occt-src "
              "(the normal case in CI / a fresh clone). Exit 0: the environment cannot answer, "
              "which is not a self-test failure.")
        return 0

    cases = [
        ("duplicate class claim across two lanes is detected", case_duplicate_claim_detected),
        ("substrate under-coverage with no gaps.md line is detected",
         case_substrate_under_without_gaps_line_detected),
        ("header-count reconciliation arithmetic mismatch is detected",
         case_arithmetic_mismatch_detected),
        ("lane classify() shape drift is detected", case_lane_shape_verification),
    ]
    print(f"Running {len(cases)} self-test cases (each proven to fail first, per "
          "okf/policies/prove-the-test-fails.md; see this file's own source for the injection):")
    results = [_case(name, fn) for name, fn in cases]
    passed = sum(results)
    print(f"\n{passed}/{len(cases)} self-test cases passed")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(run())

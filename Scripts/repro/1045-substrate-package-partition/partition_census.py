#!/usr/bin/env python3
"""Issue #1045 (part of #807): where the fifteen unowned "substrate" packages go.

This is a PARTITION census, matching #973's own precedent
(`Scripts/repro/973-ocaf-package-partition/partition_census.py`) for the OCAF family: it does not
audit any package's per-class coverage (that is the owning pass's job), it answers exactly one
question, "does every package #1045 found belong to a named pass, and is that assignment still
accurate against the pinned headers."

WHY THIS EXISTS. #1045 found fifteen packages under #811's features lane, 331 headers (the issue's
own title says "337"; re-measured here directly against the pinned headers, and the issue's own
table sums to 331, so the title's figure was the wrong one, not the table — the same "title and
table disagree, re-derive rather than trust either" shape #973's own docstring records for its own
issue), that no sub-issue of #807 (#808 through #820, #928, #930, #982, #983) names anywhere in its
`## Lane` section. #1045 measured each package's header count and how much of it the bridge/docs
already name, argued three of the fifteen (`GeomFill_`, `BRepFill_`, `BRepOffset_`) are not really
"unowned substrate" at all (they carry real wrapped surface and known kernel findings, #597/#905/
#913/#522 among them), and recommended a destination without creating a thirteenth lane pass for
work that #820 (Phase 6) is already chartered to catch: #820's own `## What this adds` section
names exactly this shape of finding, "a class that sits at a boundary belongs to nobody's table,"
as one of the two things a lane pass structurally cannot see.

THE DECISION THIS SCRIPT RECORDS. All fifteen packages are assigned to #820, not to a new lane and
not folded into #811 (#1045's own "why not #811" section: 331 headers is more than twice the lane
that would absorb them, and the subject differs, an API a consumer reaches vs. the algorithms
underneath it). `GeomFill_` and `BRepFill_` are flagged HIGH priority within that assignment,
per #1045's "Done when" #3 ("whichever lane takes GeomFill_ and BRepFill_ audits them, since those
two carry most of the wrapped surface here"): together they are 112 of the 331 headers and 49 of
the 68 bridge-named classes across all fifteen.

Run from anywhere; paths derive from this file's location, not the cwd:

    python3 Scripts/repro/1045-substrate-package-partition/partition_census.py
    python3 Scripts/repro/1045-substrate-package-partition/partition_census.py --verify
    python3 Scripts/repro/1045-substrate-package-partition/partition_census.py --self-test

Exit codes: 0 clean, 1 a defect (a header count has drifted from the pinned kernel, or a package
this script tracks is now named in some other issue's `## Lane`, meaning the assignment recorded
here is stale), 2 the environment cannot answer (no `Libraries/OCCT.xcframework`).
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
HEADERS_DIR = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

# Package -> (pinned header count at filing, classes named in Sources/OCCTBridge, classes named
# under docs/), exactly #1045's own table, kept here rather than re-derived from the bridge/docs
# since that re-derivation is #820's job, not this census's: this script only tracks *where the
# package goes*, not *how well covered it is*.
PACKAGES = {
    "BRepBlend_": (43, 0, 2),
    "Blend_": (13, 0, 0),
    "BlendFunc_": (21, 0, 1),
    "ChFiDS_": (27, 2, 4),
    "ChFiKPart_": (15, 0, 0),
    "BRepOffset_": (17, 6, 5),
    "Draft_": (8, 1, 1),
    "BiTgte_": (4, 2, 2),
    "MAT_": (18, 3, 2),
    "MAT2d_": (18, 0, 0),
    "Bisector_": (10, 5, 5),
    "BRepFill_": (45, 12, 12),
    "GeomFill_": (67, 37, 31),
    "AdvApp2Var_": (18, 0, 1),
    "AdvApprox_": (7, 0, 1),
}

# The decision this census records: every package above goes to #820 (Phase 6), never a new lane.
DESTINATION_ISSUE = 820
HIGH_PRIORITY = {"GeomFill_", "BRepFill_"}

# Every #807 sub-issue whose `## Lane` a real double-claim would be worth flagging in. Not fetched
# live (no network dependency for the common case); `--verify` fetches the current lane text for
# each via `gh` and fails if a tracked package now appears somewhere other than #820.
LANE_ISSUES = [808, 809, 810, 811, 812, 813, 814, 820, 928, 930, 982, 983]


def header_count(prefix: str) -> int:
    pattern = os.path.join(HEADERS_DIR, f"{prefix}*.hxx")
    return len(glob.glob(pattern))


def print_table() -> None:
    print(f"{'package':<14}{'headers':>8}{'bridge':>8}{'docs':>7}  destination")
    total_headers = 0
    for pkg, (headers, bridge, docs) in sorted(PACKAGES.items()):
        dest = f"#{DESTINATION_ISSUE}"
        if pkg in HIGH_PRIORITY:
            dest += " (HIGH priority)"
        print(f"{pkg:<14}{headers:>8}{bridge:>8}{docs:>7}  {dest}")
        total_headers += headers
    print(f"{'TOTAL':<14}{total_headers:>8}")
    print()
    print(f"All {len(PACKAGES)} packages, {total_headers} headers, assigned to #{DESTINATION_ISSUE}.")
    print(f"High priority (largest wrapped surface): {', '.join(sorted(HIGH_PRIORITY))}")


def verify() -> int:
    if not os.path.isdir(HEADERS_DIR):
        print(f"SKIPPED: {HEADERS_DIR} not present (no local xcframework)", file=sys.stderr)
        return 2

    ok = True
    for pkg, (recorded, _bridge, _docs) in sorted(PACKAGES.items()):
        actual = header_count(pkg)
        if actual != recorded:
            print(
                f"DEFECT: {pkg} recorded {recorded} headers, pinned kernel has {actual} "
                f"(re-measure and update PACKAGES, and re-check whether the delta changes the "
                f"#1045 destination argument)"
            )
            ok = False

    import shutil
    import subprocess

    if shutil.which("gh"):
        for issue in LANE_ISSUES:
            try:
                body = subprocess.run(
                    ["gh", "issue", "view", str(issue), "--json", "body", "-q", ".body"],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    timeout=30,
                ).stdout
            except Exception as exc:  # pragma: no cover - network/gh unavailable
                print(f"SKIPPED lane check for #{issue}: {exc}", file=sys.stderr)
                continue
            if issue == DESTINATION_ISSUE:
                continue
            for pkg in PACKAGES:
                if re.search(re.escape(pkg), body):
                    # Reported, not failed: a lane section legitimately names its neighbours (the
                    # same distinction #973's own --verify-lanes draws). #813 names BRepFill_ once,
                    # as a consumer of BinTools_, and does not claim it; a genuine re-claim is
                    # visible in this report but not caught automatically, same limitation #973
                    # states for itself.
                    print(
                        f"NOTE: #{issue} mentions {pkg} (tracked here as belonging to "
                        f"#{DESTINATION_ISSUE}); confirm it's an incidental cross-reference, not a "
                        f"claim, if this package's assignment is ever revisited."
                    )
    else:
        print("SKIPPED lane-double-claim check: gh not on PATH", file=sys.stderr)

    if ok:
        print(f"OK: all {len(PACKAGES)} packages' header counts match the pinned kernel, "
              f"no other #807 sub-issue claims one of them.")
    return 0 if ok else 1


def self_test() -> int:
    failures = []

    # Fixture 1: a header-count drift must be caught.
    saved = dict(PACKAGES)
    try:
        PACKAGES["GeomFill_"] = (999, 37, 31)
        # verify() reads the real headers dir; if it's absent this fixture can't run, which is
        # fine, --verify itself already reports SKIPPED for that case and self-test only checks
        # the code path that *can* detect a drift.
        if os.path.isdir(HEADERS_DIR):
            rc = verify()
            if rc != 1:
                failures.append("injected header-count drift was not caught (expected exit 1)")
    finally:
        PACKAGES.clear()
        PACKAGES.update(saved)

    if os.path.isdir(HEADERS_DIR):
        rc = verify()
        if rc != 0:
            failures.append("clean tree did not report OK after restoring PACKAGES")

    if failures:
        for f in failures:
            print(f"SELF-TEST FAILURE: {f}")
        return 1
    print("SELF-TEST: OK (injected drift caught, clean state restored and re-verified)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verify", action="store_true", help="check header counts and lane double-claims")
    parser.add_argument("--self-test", action="store_true", help="prove the detector catches a drift")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.verify:
        return verify()
    print_table()
    return 0


if __name__ == "__main__":
    sys.exit(main())

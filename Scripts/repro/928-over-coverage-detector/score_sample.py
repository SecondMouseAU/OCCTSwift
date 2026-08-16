#!/usr/bin/env python3
r"""Score `Scripts/census-doc-occt-attribution.py` against the sixty hand-adjudicated findings in
`adjudicated-sample.tsv`, and print the false-positive rate.

Three batches, scored separately and never pooled. `uniform-40` is a uniform random sample of every
finding, and its FALSE share is the false-positive rate quoted for #928. `retro-808` and `retro-809`
are lane-restricted, drawn with each lane's own known findings excluded, and their TRUE share
answers a different question entirely: how complete was that lane's hand read-through.

The rates were measured on `origin/main` with #808's twenty-six findings still unfixed. Re-run this
after any change to the detector: a change that quietens the corpus is only an improvement if it
removes FALSE rows faster than TRUE ones, and the total finding count alone cannot tell those apart.

Rows are matched on `(path, line, class)`. A row the detector no longer reports is counted as
DROPPED, split by verdict, since dropping a TRUE row is a recall loss and dropping a FALSE row is
the intended effect. Line numbers are those of the tree the sample was drawn from, so score against
that same state (plain `origin/main`, no patches applied) or the matching will be nonsense; the
script says so rather than reporting a small number quietly.

    python3 Scripts/repro/928-over-coverage-detector/score_sample.py
"""

from __future__ import annotations

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SAMPLE = os.path.join(HERE, "adjudicated-sample.tsv")


BATCH = "# [batch: "


def load_sample():
    rows, batch = [], "uniform-40"
    for line in open(SAMPLE, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith(BATCH):
            batch = line[len(BATCH):].rstrip("]")
            continue
        if not line or line.startswith("#"):
            continue
        loc, cls, verdict, reason = line.split("\t", 3)
        path, _, lineno = loc.rpartition(":")
        rows.append((path, int(lineno), cls, verdict, reason, batch))
    return rows


def main() -> int:
    spec = importlib.util.spec_from_file_location(
        "_detector", os.path.join(ROOT, "Scripts", "census-doc-occt-attribution.py")
    )
    det = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(det)

    prefixes, bare = det.load_packages()
    _p, _b, header_names = det.derive_packages()
    reach = det.bridge_reach()
    member_syms = det.swift_member_symbols()
    claims = det.doc_claims(det.in_scope_docs()) + det.bridge_header_claims()
    findings, _u, _c = det.run(claims, reach, member_syms, prefixes, bare, header_names or None)

    # The sample records the class exactly as `--sample` prints it, `Class::Member` included, so
    # the key has to be rebuilt the same way. Keying on `f.cls` alone silently missed every row
    # with a scoped member and reported six adjudicated-TRUE rows as recall lost.
    def key(f):
        return (f.claim.path, f.claim.line, f.cls + ("::" + f.member if f.member else ""))

    reported = {key(f): f for f in findings}
    sample = load_sample()

    kept = {"TRUE": [], "FALSE": []}
    dropped = {"TRUE": [], "FALSE": []}
    batches: dict[str, dict[str, int]] = {}
    for path, lineno, cls, verdict, reason, batch in sample:
        still = (path, lineno, cls) in reported
        (kept if still else dropped)[verdict].append((path, lineno, cls, reason))
        if still:
            batches.setdefault(batch, {"TRUE": 0, "FALSE": 0})[verdict] += 1

    n_kept = len(kept["TRUE"]) + len(kept["FALSE"])
    print(f"sample rows                : {len(sample)}")
    print(f"still reported             : {n_kept}  "
          f"(TRUE {len(kept['TRUE'])}, FALSE {len(kept['FALSE'])})")
    print(f"no longer reported         : {len(sample) - n_kept}  "
          f"(TRUE {len(dropped['TRUE'])}, FALSE {len(dropped['FALSE'])})")
    print(f"total findings on this tree: {len(findings)}")
    print()
    # Per batch, never pooled. `uniform-40` is a uniform random sample of every finding and is the
    # only one whose FALSE share is a false-positive RATE; the two retro batches are lane-restricted
    # and known-excluded, so their TRUE share answers "how complete was that lane's read-through"
    # and nothing about the detector's precision overall.
    for batch, counts in batches.items():
        n = counts["TRUE"] + counts["FALSE"]
        label = ("false-positive rate" if batch == "uniform-40"
                 else "new findings in this lane")
        share = counts["FALSE"] if batch == "uniform-40" else counts["TRUE"]
        print(f"  {batch:12}: {n:2} rows reported, TRUE {counts['TRUE']:2}, "
              f"FALSE {counts['FALSE']:2}  -> {label} {share}/{n} = {100 * share / n:.1f}%")

    # Per confidence tier. `explicit` means the claim named its own bridge symbol; `heading` means
    # the symbol came from the enclosing heading's Swift member, which is a guess the pages'
    # own two heading conventions make unavoidable (see `check-docs-existence.py`, which measured
    # the same thing and had to relax the same way). Anyone proposing to promote this to a gate
    # needs these two numbers separately, not the pooled one.
    # Over the uniform batch only, for the same reason the rates above are not pooled: a rate is
    # only a rate over a uniform sample.
    tiers: dict[str, dict[str, int]] = {}
    for path, lineno, cls, verdict, _reason, batch in sample:
        if batch != "uniform-40":
            continue
        f = reported.get((path, lineno, cls))
        if f is None:
            continue
        tiers.setdefault(f.how, {"TRUE": 0, "FALSE": 0})[verdict] += 1
    print()
    for tier, counts in sorted(tiers.items()):
        n = counts["TRUE"] + counts["FALSE"]
        print(f"  uniform-40, tier {tier:9}: {n:2} rows, TRUE {counts['TRUE']:2}, "
              f"FALSE {counts['FALSE']:2}  -> {100 * counts['FALSE'] / n:.1f}% false")

    if dropped["TRUE"]:
        print("\nRECALL LOST: adjudicated-TRUE rows this version no longer reports:")
        for path, lineno, cls, reason in dropped["TRUE"]:
            print(f"  {path}:{lineno}  {cls}")
    if dropped["FALSE"]:
        print("\nFALSE POSITIVES REMOVED since the sample was adjudicated:")
        for path, lineno, cls, reason in dropped["FALSE"]:
            print(f"  {path}:{lineno}  {cls}")
    if len(sample) - n_kept == len(sample):
        print("\nNOTE: nothing matched at all. The sample's line numbers are those of plain "
              "origin/main; score against that state, not a patched tree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

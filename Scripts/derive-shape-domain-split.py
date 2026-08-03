#!/usr/bin/env python3
"""Suggest a domain for each member of `extension Shape`, from what tests cover it (#660).

#395's header split was a lookup: every declaration mapped to exactly one `.mm`. This one is not.
The domain of a `Shape` method is a judgement, and the point of this script is to shrink how much
judgement is left rather than pretend there is none.

The signal is test coverage. `Tests/OCCT<Domain>Tests` is an established taxonomy in this repo, and
a member exercised by exactly one of those targets has a defensible home: put the source where the
tests already are, so `Shape+Modeling.swift` and `OCCTModelingTests` line up without a lookup table.

    python3 Scripts/derive-shape-domain-split.py             # counts per domain
    python3 Scripts/derive-shape-domain-split.py --list       # every member and its suggestion
    python3 Scripts/derive-shape-domain-split.py --unmapped   # only the ones needing a decision

Roughly two thirds map cleanly. The rest split two ways and both matter:

  AMBIGUOUS  exercised by several targets. Decide by what the method does, not by which test
             happens to touch it first; a test in OCCTStressTests calling a modelling method says
             nothing about the method's domain.
  UNTESTED   exercised by nothing. Place by behaviour, and treat the absence as worth reporting:
             an untested public method on the primary type is a finding in its own right.

Exits 2 if run from anywhere but the repo root, matching the other scripts (#625).
"""

import argparse
import collections
import glob
import os
import re
import sys

SHAPE = "Sources/OCCTSwift/Shape.swift"
TESTS = "Tests"

MEMBER = re.compile(r"^\s+(?:public |internal |)?(?:static |)?(?:func|var) ([a-zA-Z_]\w*)")
# Targets that say nothing about a method's domain: they exercise everything by design.
DOMAIN_FREE = {"Stress", "Integration", "Thread", "Misc", "Foundation"}


def shape_members():
    """Member names declared inside a top-level `extension Shape` block in Shape.swift."""
    names, depth, inside = set(), 0, False
    for line in open(SHAPE, errors="ignore"):
        if line.startswith("extension Shape"):
            inside, depth = True, 0
        if inside:
            m = MEMBER.match(line)
            if m:
                names.add(m.group(1))
            depth += line.count("{") - line.count("}")
            if depth <= 0 and line.startswith("}"):
                inside = False
    return sorted(names)


def test_corpus():
    corpus = {}
    for d in sorted(glob.glob(os.path.join(TESTS, "OCCT*Tests"))):
        name = os.path.basename(d)[len("OCCT"):-len("Tests")]
        blob = []
        for f in glob.glob(os.path.join(d, "**", "*.swift"), recursive=True):
            blob.append(open(f, errors="ignore").read())
        corpus[name] = "\n".join(blob)
    return corpus


def classify(members, corpus):
    out = {}
    for name in members:
        pat = re.compile(r"\." + re.escape(name) + r"\b")
        hit = {t for t, blob in corpus.items() if pat.search(blob)}
        informative = hit - DOMAIN_FREE
        if len(informative) == 1:
            out[name] = (informative.pop(), "mapped")
        elif informative:
            out[name] = ("/".join(sorted(informative)), "AMBIGUOUS")
        else:
            out[name] = ("", "UNTESTED")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="every member with its suggestion")
    ap.add_argument("--unmapped", action="store_true", help="only members needing a decision")
    args = ap.parse_args()

    if not os.path.isfile(SHAPE) or not os.path.isdir(TESTS):
        print(f"error: run from the repo root (expected {SHAPE} and {TESTS}/)", file=sys.stderr)
        return 2

    members = shape_members()
    result = classify(members, test_corpus())

    if args.list or args.unmapped:
        for name in members:
            domain, state = result[name]
            if args.unmapped and state == "mapped":
                continue
            print(f"{state:10s}\t{domain or '-':28s}\t{name}")
        return 0

    counts = collections.Counter()
    for domain, state in result.values():
        counts[domain if state == "mapped" else state] += 1
    print(f"members of extension Shape: {len(members)}")
    for key, n in counts.most_common():
        print(f"  {n:4d}  {key}")
    mapped = sum(n for k, n in counts.items() if k not in ("AMBIGUOUS", "UNTESTED"))
    print(f"\n  {mapped} of {len(members)} have a single-target suggestion; the rest need a decision.")
    print("  Run --unmapped for those. Report how many end up in Shape+Misc.swift: a large Misc")
    print("  means the test-target vocabulary does not fit, which #663 needs to know before it")
    print("  applies the same rule to Document.swift.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

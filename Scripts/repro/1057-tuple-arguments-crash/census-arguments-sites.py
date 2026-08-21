#!/usr/bin/env python3
"""#1057: enumerate every `@Test(..., arguments:)` site under Tests/ and flag the ones whose
element type could hit the toolchain defect.

A `@Test(arguments:)` crashes when its element type is one aggregate (tuple or struct) holding
both a reference-counted member and a builtin vector of 32 bytes or more. Measured grid and
narrowing: Scripts/repro/1057-tuple-arguments-crash/README.md.

This is a CENSUS, not a gate. It exits 0 whether or not it finds anything, because deciding
whether a named type is reference-counted or carries a wide vector needs a human to open the type,
which is exactly what the one interesting row here needed (`ThreadProfile` stores an `[Vertex]`
and nothing wider than a word, so it is clean). Its job is to make the site list re-derivable
instead of re-grepped.

    python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py
    python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py --self-test

Run from the repo root.
"""
import argparse
import os
import re
import sys

# A 32-byte-or-wider builtin vector. SIMD2<Double>, SIMD4<Float> and everything narrower are
# measured clean (grid cells J and L, variants V31 and V42), so they are deliberately not here.
WIDE_VECTOR = re.compile(
    r"\bSIMD(?:3|4)\s*<\s*Double\s*>|\bSIMD(?:8|16|32|64)\s*<\s*Float\s*>"
    r"|\bSIMD(?:4|8|16|32|64)\s*<\s*Double\s*>|\bsimd_double(?:3|4)\b"
)

# Spellings of a reference-counted member that appear in argument literals in this tree. A named
# type is not decidable from the literal, which is why this reports rather than gates.
#
# The array clause is `[` immediately after `(` or `,`, not a bare `[`: the outer `arguments: [`
# would match a bare one on every site. The self-test's `([1], SIMD3<Double>(1, 0, 0))` case is
# what caught that, having been written against an earlier clause that only matched an empty `[]`.
REFCOUNTED = re.compile(r"\bString\b|\"|[(,]\s*\[|\bArray\s*<")


def sites(root):
    """Every `arguments:` occurrence under `root`, as (path, line number, the literal's text).

    The literal's text is the argument list from `arguments:` to the balanced close of the `@Test`
    call, which is what carries the element type when it is written out.
    """
    out = []
    for dirpath, _dirs, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith(".swift"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
            for i, line in enumerate(lines):
                if "arguments:" not in line:
                    continue
                # A doc comment or a `//` comment mentioning `arguments:` is prose, not a site.
                # Issue990ThreadAxisBasisTests' own explanation is exactly this case, and counting
                # it was the difference between 33 and 35.
                stripped = line.lstrip()
                if stripped.startswith("///") or stripped.startswith("//"):
                    continue
                text, depth, started = [], 0, False
                for j in range(i, min(i + 40, len(lines))):
                    text.append(lines[j])
                    for ch in lines[j]:
                        if ch == "(":
                            depth += 1
                            started = True
                        elif ch == ")":
                            depth -= 1
                    if started and depth <= 0:
                        break
                # Slice from `arguments:` so the `@Test("display name", ...)` string on the same
                # line is not read as a reference-counted member. The verdict never changed, but
                # the printed reason did, and a reason that says "a reference-counted member" for
                # a site whose only string is its own title is worse than no reason.
                joined = "".join(text)
                out.append((path, i + 1, joined[joined.index("arguments:"):]))
    return out


def classify(text):
    """('at risk' | 'clean', reason) for one site's literal text."""
    wide = WIDE_VECTOR.search(text)
    ref = REFCOUNTED.search(text)
    if wide and ref:
        return "AT RISK", "a wide vector and a reference-counted member in the same literal"
    if wide:
        return "clean", "a wide vector, no reference-counted member"
    if ref:
        return "clean", "a reference-counted member, no wide vector"
    return "clean", "neither"


def self_test():
    """Each case proves the detector catches one failure mode, and each control proves it does not
    fire on the shape next door. Removing any one line below must drop the count."""
    cases = [
        ("AT RISK", 'arguments: [("+X", SIMD3<Double>(1, 0, 0))])'),
        ("AT RISK", 'arguments: [("+X", SIMD4<Double>(1, 0, 0, 0))])'),
        ("AT RISK", 'arguments: [("+X", SIMD8<Float>(repeating: 1))])'),
        ("AT RISK", 'arguments: [(SIMD3<Double>(1, 0, 0), "+X")])'),
        ("AT RISK", 'arguments: [([1], SIMD3<Double>(1, 0, 0))])'),
        ("clean", 'arguments: [(SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0))])'),
        ("clean", 'arguments: [("+X", 1)])'),
        ("clean", 'arguments: [("+X", SIMD2<Double>(1, 0))])'),
        ("clean", 'arguments: [("+X", SIMD4<Float>(1, 0, 0, 0))])'),
        ("clean", "arguments: [1.0, 2.0])"),
        ("clean", "arguments: 0...2)"),
    ]
    failures = 0
    for expected, text in cases:
        got, why = classify(text)
        if got != expected:
            print(f"self-test FAIL: expected {expected}, got {got} ({why}) for {text}")
            failures += 1
    # The comment-line skip is the other half of the detector and needs its own case, since a
    # miscount there changes the total without changing any verdict.
    doc = "    /// The six axes are one test walking a list rather than six `arguments:` cases.\n"
    if not (doc.lstrip().startswith("///")):
        print("self-test FAIL: doc-comment skip is not exercised")
        failures += 1
    print(f"self-test: {len(cases) + 1} cases, {failures} failures")
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", default="Tests")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if not os.path.isdir(args.root):
        print(f"no {args.root}/ here; run from the repo root", file=sys.stderr)
        return 2

    found = sites(args.root)
    at_risk = 0
    for path, line, text in found:
        verdict, why = classify(text)
        if verdict == "AT RISK":
            at_risk += 1
        print(f"{verdict:8} {path}:{line}  ({why})")
    print(f"\n{len(found)} `arguments:` sites under {args.root}/, {at_risk} at risk")
    return 0


if __name__ == "__main__":
    sys.exit(main())

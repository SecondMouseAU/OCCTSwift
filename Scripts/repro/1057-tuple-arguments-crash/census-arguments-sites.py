#!/usr/bin/env python3
"""#1057: enumerate every `@Test(..., arguments:)` site under Tests/ and flag the ones whose
element type could hit the toolchain defect.

A `@Test(arguments:)` can crash when its element type is one aggregate (tuple or struct) holding
both a reference-counted member and a builtin vector of 32 bytes or more. Both are necessary:
removing either gives a clean run, measured 3/3 per case. Neither pair is *sufficient*, and this
script deliberately does not pretend otherwise: `(String, Vec3)` (three `SIMD3<Double>`, 112 bytes)
and `(String, One80)` (one `SIMD3<Double>` plus four `Double`s, 80 bytes) both satisfy the pair and
both run clean. Where exactly the cut falls is not characterised. See
Scripts/repro/1057-tuple-arguments-crash/README.md for the measured table.

So AT RISK here means "worth opening", not "will crash", and the over-prediction is the direction a
census should err in.

This is a CENSUS, not a gate. It exits 0 whether or not it finds anything, because deciding whether
a *named* type is reference-counted or carries a wide vector needs somebody to open the type, which
is what the one interesting row in this tree needed (`ThreadProfile` stores an `[Vertex]` and
nothing wider than a word, so it is clean). Its job is to make the site list re-derivable instead of
re-grepped.

    python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py
    python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py --self-test

Run from the repo root.
"""
import argparse
import os
import re
import sys

# Bytes per SIMD element type. A `SIMDn<T>` occupies `roundUpToPowerOfTwo(n) * width(T)`, which is
# why `SIMD3<Double>` is 32 bytes and not 24.
ELEMENT_WIDTH = {
    "Int8": 1, "UInt8": 1,
    "Int16": 2, "UInt16": 2, "Float16": 2,
    "Int32": 4, "UInt32": 4, "Float": 4,
    "Int64": 8, "UInt64": 8, "Double": 8, "Int": 8, "UInt": 8,
}

# The `simd_*` typealias spellings, which name the element type in the identifier itself.
SIMD_ALIAS_WIDTH = {
    "char": 1, "uchar": 1,
    "short": 2, "ushort": 2, "half": 2,
    "int": 4, "uint": 4, "float": 4,
    "long": 8, "ulong": 8, "double": 8,
}

GENERIC_SIMD = re.compile(r"\bSIMD(\d+)\s*<\s*([A-Za-z0-9_]+)\s*>")
ALIAS_SIMD = re.compile(r"\bsimd_([a-z]+)(\d+)\b")

# Spellings of a reference-counted member that appear in argument literals in this tree. A named
# type is not decidable from the literal, which is why this reports rather than gates.
#
# The array clause is `[` immediately after `(` or `,`, not a bare `[`: the outer `arguments: [`
# would match a bare one on every site. The self-test's `([1], SIMD3<Double>(1, 0, 0))` case is
# what caught that, having been written against an earlier clause that only matched an empty `[]`.
REFCOUNTED = re.compile(r"\bString\b|\"|[(,]\s*\[|\bArray\s*<")

# An `arguments:` whose value is a bare identifier carries no type at all, so no verdict can be
# read off the source. Reporting those as "clean (neither)" alongside sites that were actually
# inspected is what a pre-PR review caught: `arguments: ThreadFormsTests.smoothForms` had the right
# answer for a reason this script could not see.
BARE_IDENTIFIER = re.compile(r"arguments:\s*[A-Za-z_][A-Za-z0-9_.]*\s*\)?\s*$")


def round_up_pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def widest_vector(text):
    """Bytes in the widest builtin SIMD vector named in `text`, or 0 if none is."""
    widest = 0
    for count, element in GENERIC_SIMD.findall(text):
        width = ELEMENT_WIDTH.get(element)
        if width:
            widest = max(widest, round_up_pow2(int(count)) * width)
    for element, count in ALIAS_SIMD.findall(text):
        width = SIMD_ALIAS_WIDTH.get(element)
        if width:
            widest = max(widest, round_up_pow2(int(count)) * width)
    return widest


def strip_string_literals(line):
    """`line` with the contents of every double-quoted run replaced by spaces.

    A `@Test("... arguments: ...")` display name is prose, not a call. A pre-PR review demonstrated
    a synthetic suite whose display name contained `arguments:` producing two census rows.
    """
    out, in_string, escaped = [], False, False
    for ch in line:
        if escaped:
            out.append(" " if in_string else ch)
            escaped = False
            continue
        if ch == "\\":
            out.append(" " if in_string else ch)
            escaped = True
            continue
        if ch == '"':
            in_string = not in_string
            out.append('"')
            continue
        out.append(" " if in_string else ch)
    return "".join(out)


def sites(root):
    """Every `arguments:` call site under `root`, as (path, line number, the argument text).

    The argument text runs from `arguments:` to the close of the enclosing `@Test(` call. The scan
    starts at depth 1 rather than 0, because reaching `arguments:` means already being inside that
    call. Measured against a depth-0 copy over this tree: 32 of the 33 sites put `arguments:` on a
    line with no open paren of its own, depth-0 captures a different text on 9 of them, and on all
    9 it truncates to that single line rather than running to the 40-line cap. **No verdict changes
    today**, so this is correctness for the multi-line array literal whose element types sit on a
    later line, and the `arguments: on its own line still reaches the element type` self-test case
    is what holds it: that one flips AT RISK to clean under depth 0.

    An earlier version of this paragraph said "five real sites" and "ran to its 40-line cap on
    every one of them". Both numbers were invented rather than measured, in a directory whose own
    README cites `measure-dont-assume`, and a pre-PR review caught it.
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
                # A doc comment or a `//` comment mentioning `arguments:` is prose, not a site.
                # Issue990ThreadAxisBasisTests' own explanation is exactly this case, and counting
                # it was the difference between 33 and 38.
                stripped = line.lstrip()
                if stripped.startswith("///") or stripped.startswith("//"):
                    continue
                masked = strip_string_literals(line)
                if "arguments:" not in masked:
                    continue
                start = masked.index("arguments:")
                text, depth = [line[start:]], 1
                for ch in masked[start:]:
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                j = i
                while depth > 0 and j + 1 < len(lines) and j - i < 40:
                    j += 1
                    text.append(lines[j])
                    for ch in strip_string_literals(lines[j]):
                        if ch == "(":
                            depth += 1
                        elif ch == ")":
                            depth -= 1
                out.append((path, i + 1, "".join(text)))
    return out


def classify(text):
    """('AT RISK' | 'clean' | 'unknown', reason) for one site's argument text."""
    if BARE_IDENTIFIER.search(text.strip().splitlines()[0] if text.strip() else ""):
        return "unknown", "the arguments are a named collection, so no type is written here"
    wide = widest_vector(text)
    ref = REFCOUNTED.search(text)
    if wide >= 32 and ref:
        return "AT RISK", f"a {wide}-byte vector and a reference-counted member in one literal"
    if wide >= 32:
        return "clean", f"a {wide}-byte vector, no reference-counted member"
    if wide:
        return "clean", f"a {wide}-byte vector, under the 32-byte threshold"
    if ref:
        return "clean", "a reference-counted member, no vector"
    return "clean", "neither"


CLASSIFY_CASES = [
    ("AT RISK", 'arguments: [("+X", SIMD3<Double>(1, 0, 0))])'),
    ("AT RISK", 'arguments: [("+X", SIMD4<Double>(1, 0, 0, 0))])'),
    ("AT RISK", 'arguments: [("+X", SIMD8<Float>(repeating: 1))])'),
    ("AT RISK", 'arguments: [("+X", SIMD4<Int64>(1, 0, 0, 0))])'),
    ("AT RISK", 'arguments: [("+X", SIMD16<Int16>(repeating: 1))])'),
    ("AT RISK", 'arguments: [("+X", simd_double3(1, 0, 0))])'),
    ("AT RISK", 'arguments: [(SIMD3<Double>(1, 0, 0), "+X")])'),
    ("AT RISK", "arguments: [([1], SIMD3<Double>(1, 0, 0))])"),
    ("clean", 'arguments: [(SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0))])'),
    ("clean", 'arguments: [("+X", 1)])'),
    ("clean", 'arguments: [("+X", SIMD2<Double>(1, 0))])'),
    ("clean", 'arguments: [("+X", SIMD4<Float>(1, 0, 0, 0))])'),
    ("clean", 'arguments: [("+X", simd_float4(1, 0, 0, 0))])'),
    ("clean", "arguments: [1.0, 2.0])"),
    ("clean", "arguments: 0...2)"),
    ("unknown", "arguments: ThreadFormsTests.smoothForms)"),
]

# (label, file body, expected (line, verdict) rows). These exercise `sites()`, which `classify()`'s
# own cases cannot reach: the skip, the string-literal mask and the paren scan are all in there.
SITE_CASES = [
    (
        "a doc comment naming arguments: is not a site",
        '/// six `arguments:` cases, not one\n'
        '@Test("t", arguments: [1, 2])\nfunc f(_ n: Int) {}\n',
        [(2, "clean")],
    ),
    (
        "a `//` comment naming arguments: is not a site",
        '// arguments: was the old spelling\n'
        '@Test("t", arguments: [1, 2])\nfunc f(_ n: Int) {}\n',
        [(2, "clean")],
    ),
    (
        "a display name is the only arguments: on the line, so the line is not a site",
        '@Test("what arguments: does")\nfunc f() {}\n',
        [],
    ),
    (
        "a display name's arguments: does not become the start of the captured type",
        '@Test("arguments: takes a SIMD3<Double> and a String", arguments: [1, 2])\n'
        "func f(_ n: Int) {}\n",
        [(1, "clean")],
    ),
    (
        "arguments: on its own line still reaches the element type",
        '@Test("t",\n      arguments: [\n        ("+X", SIMD3<Double>(1, 0, 0)),\n      ])\n'
        "func f(_ a: (String, SIMD3<Double>)) {}\n",
        [(2, "AT RISK")],
    ),
    (
        "a named collection reports unknown rather than a verdict it cannot support",
        "@Test(arguments: Fixtures.forms)\nfunc f(_ a: Form) {}\n",
        [(1, "unknown")],
    ),
]


def self_test(tmp_root):
    failures = 0
    for expected, text in CLASSIFY_CASES:
        got, why = classify(text)
        if got != expected:
            print(f"self-test FAIL: expected {expected}, got {got} ({why}) for {text}")
            failures += 1

    os.makedirs(tmp_root, exist_ok=True)
    for n, (label, body, expected) in enumerate(SITE_CASES):
        path = os.path.join(tmp_root, f"case{n}.swift")
        with open(path, "w", encoding="utf-8") as f:
            f.write(body)
        got = [(line, classify(text)[0]) for _p, line, text in sites(tmp_root)]
        os.remove(path)
        if got != expected:
            print(f"self-test FAIL: {label}: expected {expected}, got {got}")
            failures += 1

    total = len(CLASSIFY_CASES) + len(SITE_CASES)
    print(f"self-test: {total} cases, {failures} failures")
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", default="Tests")
    args = parser.parse_args()

    if args.self_test:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            return self_test(os.path.join(tmp, "fixtures"))

    if not os.path.isdir(args.root):
        print(f"no {args.root}/ here; run from the repo root", file=sys.stderr)
        return 2

    found = sites(args.root)
    at_risk = unknown = 0
    for path, line, text in found:
        verdict, why = classify(text)
        if verdict == "AT RISK":
            at_risk += 1
        elif verdict == "unknown":
            unknown += 1
        print(f"{verdict:8} {path}:{line}  ({why})")
    print(
        f"\n{len(found)} `arguments:` sites under {args.root}/, "
        f"{at_risk} at risk, {unknown} needing a human to open the named type"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

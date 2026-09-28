#!/usr/bin/env python3
"""CENSUS, not a gate: Swift Testing tests whose assertions cannot fail on a wrong value.

#766's walk. An execution PR certifies a set of tests as Red/Green against an injected defect. When
the PR does **not** change a test it certifies, the certification is the only evidence that the test
notices anything, and a test built out of the shapes below notices total failure and nothing else:

  * `guard let x = ... else { return }` - a nil result skips every assertion and the test passes.
  * `if let x = x { ... }` with no `else` - the same thing, one indentation level down.
  * `if n >= 0 { ... }` - true for every count a kernel can return.
  * a sole `!= nil` / `== nil`.
  * `> 0`, `>= n`, `!isEmpty`, or a bare Bool property as the only assertion.

Measured on batch 1 of the walk: boolean-only evidence density predicted the blind tests with no
false positives (7 of 9 in the rejected PR, 0 of 9 in the best one), and these shapes are the source
those records were summarising. So the detector reads the tests rather than the records.

WHY THIS IS A CENSUS AND NOT A GATE
-----------------------------------
Every shape above is sometimes correct. `guard let` is the house style for a fallible factory
(`CLAUDE.md`'s Test Conventions forbid force-unwrapping inside `#expect`, which is what pushes
authors into it), `!= nil` is the whole assertion for a test whose subject is "this refuses", and a
Bool property is the measurement for `isValid`. Nothing mechanical separates those from a blind
test, so this prints a list and always exits 0, per `okf/policies/static-gates.md`'s gate/census
distinction. What it buys is a reading order: the flagged tests are where the laundering is, and a
PR certifying one without changing it and without saying so is the finding.

NOT FOR `gate-scripts`
----------------------
Its subject is the `exec/766-*` branches, not `main`, and it is meant to be scoped to a file list a
caller supplies. Wired into `gate-scripts` it would report over whatever `Tests/` happened to be
checked out and say nothing about the PR under review. `--require-tests` makes a run that examined
nothing exit 2 instead of printing a clean report (#2098's mode).

    python3 Scripts/census-766-weak-assertions.py --files Tests/OCCTCurveTests/FooTests.swift
    python3 Scripts/census-766-weak-assertions.py --tests-root Tests --summary
    python3 Scripts/census-766-weak-assertions.py --self-test
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

TEST_ATTR = re.compile(r"^\s*@Test\b")
FUNC = re.compile(r"\bfunc\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(")
ASSERT_CALL = re.compile(r"#(?:expect|require)\s*\(")

GUARD_RETURN = re.compile(r"\bguard\b[^\n]*\belse\b")
IF_LET = re.compile(r"\bif\s+(?:let|case\s+let|var)\b")
NONNEG_INT = re.compile(r"\bif\s+[A-Za-z0-9_.()\[\] ]+\s*>=\s*0\s*[{,]")

NIL_ONLY = re.compile(r"^[^=<>]*(?:!=|==)\s*nil\s*$")
COUNT_ONLY = re.compile(r"^[^=<>]*(?:>\s*0|>=\s*\d+|\.isEmpty\s*==\s*false)\s*$")
NOT_EMPTY = re.compile(r"^\s*!\s*[A-Za-z0-9_.()\[\]]+\.isEmpty\s*$")
BARE_BOOL = re.compile(r"^\s*[A-Za-z_][A-Za-z0-9_.()\[\]?!]*\s*$")

# An assertion that pins a value: an equality against something that is not nil, a tolerance
# comparison, or a comparison against a non-integer literal. These are what a wrong value trips.
PINS_VALUE = re.compile(
    r"(?:abs\s*\(|simd_distance|\.isApproximatelyEqual|"
    r"==\s*(?!nil\b)[^=]|<\s*1e-|<\s*0\.\d|"
    r"!=\s*(?!nil\b)[A-Za-z0-9_\"'\-]|"
    r"<=?\s*-?\d*\.\d|>\s*-?\d*\.\d)"
)


def balanced_body(text: str, open_at: int) -> tuple[int, int]:
    """Return (start, end) offsets of the brace-delimited body opening at or after `open_at`.

    Skips string literals and both comment forms. A `{` inside a `#expect` message string would
    otherwise swallow the rest of the file, and every test after it would be reported as clean,
    which is the blindness `okf/policies/static-gates.md` asks a detector to assert against.
    """
    i = text.find("{", open_at)
    if i < 0:
        return (-1, -1)
    depth = 0
    j = i
    n = len(text)
    while j < n:
        c = text[j]
        if c == '"':
            j += 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
        elif c == "/" and j + 1 < n and text[j + 1] == "/":
            j = text.find("\n", j)
            if j < 0:
                break
        elif c == "/" and j + 1 < n and text[j + 1] == "*":
            k = text.find("*/", j + 2)
            j = n if k < 0 else k + 1
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return (i, j + 1)
        j += 1
    return (i, -1)


def strip_comments(body: str) -> str:
    """`body` with both comment forms removed and string literals kept."""
    out = []
    i = 0
    n = len(body)
    while i < n:
        if body[i] == '"':
            j = i + 1
            while j < n and body[j] != '"':
                j += 2 if body[j] == "\\" else 1
            out.append(body[i:j + 1])
            i = j + 1
        elif body.startswith("//", i):
            j = body.find("\n", i)
            i = n if j < 0 else j
        elif body.startswith("/*", i):
            j = body.find("*/", i)
            i = n if j < 0 else j + 2
        else:
            out.append(body[i])
            i += 1
    return "".join(out)


def assertion_args(body: str) -> list[str]:
    """The first argument of every `#expect`/`#require` in `body`, paren- and quote-balanced."""
    out = []
    for m in ASSERT_CALL.finditer(body):
        depth = 1
        j = m.end()
        start = j
        while j < len(body) and depth:
            c = body[j]
            if c == '"':
                j += 1
                while j < len(body) and body[j] != '"':
                    j += 2 if body[j] == "\\" else 1
            elif c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
                if depth == 0:
                    break
            elif c == "," and depth == 1:
                break
            j += 1
        out.append(re.sub(r"\s+", " ", body[start:j]).strip())
    return out


def weak(arg: str) -> str | None:
    """The weak-shape name for one assertion argument, or None when it pins a value."""
    a = arg.strip()
    if not a:
        return "empty"
    if PINS_VALUE.search(a):
        return None
    if NIL_ONLY.match(a):
        return "nil-only"
    if NOT_EMPTY.match(a):
        return "not-empty-only"
    if COUNT_ONLY.match(a):
        return "count-threshold-only"
    if BARE_BOOL.match(a):
        return "bare-bool-only"
    return None


def helpers_in(path: str) -> dict[str, str]:
    """Every `func` body in `path`, by name.

    A test that delegates its assertions to a helper in the same file has none of its own, and a
    detector that stops at the test body reports it as having no assertions at all. Measured on
    `Issue493InterpolatePeriodicParityTests.swift`: three of its five tests call one private
    `expectSameCurve` holding eleven assertions, and all three were reported SEVERE.
    """
    text = open(path, encoding="utf-8", errors="ignore").read()
    out: dict[str, str] = {}
    for m in FUNC.finditer(text):
        s, e = balanced_body(text, m.end())
        if s >= 0 and e > 0:
            out[m.group("name")] = text[s:e]
    return out


CALL = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def expand(body: str, helpers: dict[str, str], depth: int = 2,
           seen: frozenset[str] = frozenset()) -> str:
    """`body` with the bodies of same-file helpers it calls appended, to `depth` levels."""
    if depth <= 0:
        return body
    extra = []
    for name in {m.group(1) for m in CALL.finditer(body)}:
        if name in helpers and name not in seen:
            extra.append(expand(helpers[name], helpers, depth - 1, seen | {name}))
    return body + "\n" + "\n".join(extra)


def tests_in(path: str):
    """Yield (line_no, test_name, body) for every `@Test` function in `path`."""
    text = open(path, encoding="utf-8", errors="ignore").read()
    lines = text.split("\n")
    offsets = []
    pos = 0
    for ln in lines:
        offsets.append(pos)
        pos += len(ln) + 1
    for i, ln in enumerate(lines):
        if not TEST_ATTR.match(ln):
            continue
        m = FUNC.search(text, offsets[i])
        if not m:
            continue
        # A `@Test(arguments:)` attribute may span lines, but its func must still be close by.
        if text.count("\n", offsets[i], m.start()) > 12:
            continue
        s, e = balanced_body(text, m.end())
        if s < 0 or e < 0:
            continue
        yield i + 1, m.group("name"), text[s:e]


def inspect(path: str):
    """Yield one finding dict per `@Test` whose assertions cannot fail on a wrong value."""
    helpers = helpers_in(path)
    for line_no, name, raw in tests_in(path):
        body = expand(strip_comments(raw), {k: strip_comments(v) for k, v in helpers.items()
                                            if k != name})
        args = assertion_args(body)
        shapes = [weak(a) for a in args]
        pinning = [a for a, s in zip(args, shapes) if s is None]
        escapes = []
        if GUARD_RETURN.search(body) and re.search(r"\belse\b[^{]*\{[^{}]*\breturn\b", body):
            escapes.append("guard-else-return")
        if len(IF_LET.findall(body)) > len(re.findall(r"\}\s*else\s*\{", body)):
            escapes.append("if-let-no-else")
        if NONNEG_INT.search(body):
            escapes.append("if-int-ge-zero")
        if args and pinning and not escapes:
            continue
        reasons = []
        if not args:
            reasons.append("no-assertions")
        elif not pinning:
            reasons.append("all-assertions-weak:" + ",".join(sorted({s for s in shapes if s})))
        reasons += escapes
        if not reasons:
            continue
        # SEVERE is the tier that predicted batch 1's blind tests: nothing in the test pins a
        # value, so no wrong value can fail it. ESCAPABLE is the weaker signal: the test does pin
        # a value, but a nil or a false from the bridge skips the assertion instead of failing it.
        severe = not args or not pinning
        yield {
            "file": path,
            "line": line_no,
            "test": name,
            "assertions": len(args),
            "pinning": len(pinning),
            "tier": "SEVERE" if severe else "ESCAPABLE",
            "reasons": reasons,
        }


def swift_files(args) -> list[str]:
    if args.files:
        return [f if os.path.isabs(f) else os.path.join(ROOT, f) for f in args.files]
    out = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, args.tests_root)):
        out += [os.path.join(base, f) for f in files if f.endswith(".swift")]
    return sorted(out)


def scan(paths: list[str]) -> tuple[int, list[dict]]:
    total = 0
    findings: list[dict] = []
    for p in paths:
        total += sum(1 for _ in tests_in(p))
        findings += list(inspect(p))
    return total, findings


def census(args) -> int:
    paths = [p for p in swift_files(args) if os.path.isfile(p)]
    total_tests, findings = scan(paths)
    severe = [f for f in findings if f["tier"] == "SEVERE"]

    print("census-766-weak-assertions: tests whose assertions cannot fail on a wrong value")
    print(f"  files read: {len(paths)}")
    print(f"  @Test functions found: {total_tests}")
    pct = (100.0 * len(severe) / total_tests) if total_tests else 0.0
    print(f"  SEVERE   (nothing in the test pins a value): {len(severe)}  ({pct:.0f}%)")
    print(f"  ESCAPABLE(pins a value behind a nil-skip):   {len(findings) - len(severe)}")
    if args.require_tests and (not paths or total_tests == 0):
        print("  ERROR: --require-tests and nothing was examined. A clean report over an empty "
              "population is a false green, not a result.", file=sys.stderr)
        return 2

    if args.compare_baseline:
        every = []
        for base, _dirs, files in os.walk(os.path.join(ROOT, args.tests_root)):
            every += [os.path.join(base, f) for f in files if f.endswith(".swift")]
        b_total, b_find = scan(sorted(every))
        b_sev = sum(1 for f in b_find if f["tier"] == "SEVERE")
        b_pct = (100.0 * b_sev / b_total) if b_total else 0.0
        print(f"  baseline over {args.tests_root}: {b_sev}/{b_total} SEVERE ({b_pct:.0f}%)")
        print("  A scoped rate near the baseline is ordinary; well above it is the reading order.")

    if findings and not args.summary:
        print()
        for f in sorted(findings, key=lambda f: (f["tier"] != "SEVERE", f["file"], f["line"])):
            rel = (os.path.relpath(f["file"], ROOT)
                   if f["file"].startswith(ROOT + os.sep) else f["file"])
            print(f"  [{f['tier']}] {rel}:{f['line']}  {f['test']}")
            print(f"      assertions={f['assertions']} pinning={f['pinning']} "
                  f"reasons={' '.join(f['reasons'])}")
    if findings:
        print()
        print("  Each is a candidate, not a defect. A PR that CERTIFIES one of these Red/Green")
        print("  without changing it and without saying so is the finding this census is for.")
    return 0


def self_test() -> int:
    """Prove the census reports each weak shape, and stays silent on a test that pins a value."""
    import tempfile

    def run(src: str):
        with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False,
                                         encoding="utf-8") as fh:
            fh.write(src)
            p = fh.name
        try:
            return list(inspect(p)), list(tests_in(p))
        finally:
            os.unlink(p)

    cases = []

    # 1. A guard-else-return test is flagged. This is the primary laundering shape.
    got, _ = run("""@Test func a() throws {
  guard let s = Shape.box(width: 1, height: 1, depth: 1) else { return }
  #expect(abs((s.volume ?? 0) - 1) < 1e-9)
}
""")
    cases.append(("guard-else-return is flagged",
                  len(got) == 1 and "guard-else-return" in got[0]["reasons"]))

    # 2. A test that pins a value with no escape is silent.
    got, _ = run("""@Test func b() throws {
  let s = try #require(Shape.box(width: 1, height: 1, depth: 1))
  #expect(abs((s.volume ?? 0) - 1) < 1e-9)
}
""")
    cases.append(("a value-pinning test with no escape is silent", got == []))

    # 3. A sole `!= nil` is flagged even with no escape.
    got, _ = run("""@Test func c() {
  #expect(Shape.box(width: 1, height: 1, depth: 1) != nil)
}
""")
    cases.append(("a sole != nil is flagged",
                  len(got) == 1
                  and any(r.startswith("all-assertions-weak") for r in got[0]["reasons"])))

    # 4. `> 0` as the only assertion is flagged.
    got, _ = run("""@Test func d() {
  #expect(edges.count > 0)
}
""")
    cases.append((">0 as the only assertion is flagged", len(got) == 1))

    # 5. A bare Bool property as the only assertion is flagged.
    got, _ = run("""@Test func e() {
  #expect(shape.isValid)
}
""")
    cases.append(("a bare Bool as the only assertion is flagged", len(got) == 1))

    # 6. `if n >= 0 {` is flagged. It is true for every count a kernel can return.
    got, _ = run("""@Test func f() {
  if shape.faceCount >= 0 {
    #expect(abs(shape.volume - 8) < 1e-9)
  }
}
""")
    cases.append(("if n >= 0 is flagged",
                  len(got) == 1 and "if-int-ge-zero" in got[0]["reasons"]))

    # 7. A test with no assertions at all is flagged, not skipped.
    got, _ = run("""@Test func g() {
  let s = Shape.box(width: 1, height: 1, depth: 1)
  _ = s
}
""")
    cases.append(("a test with no assertions is flagged",
                  len(got) == 1 and "no-assertions" in got[0]["reasons"]))

    # 8. `if let` WITH an else branch is not an escape.
    got, _ = run("""@Test func h() {
  if let v = s.volume {
    #expect(abs(v - 8) < 1e-9)
  } else {
    Issue.record("no volume")
  }
}
""")
    cases.append(("if let with an else is silent", got == []))

    # 9. A brace inside a message string does not swallow the following test. This is the view
    #    assertion static-gates.md asks for: a parser that loses the file reports every later test
    #    as clean, which is indistinguishable from a clean file.
    got, tests = run("""@Test func i() {
  #expect(abs(v - 8) < 1e-9, "brace { in a message")
}
@Test func j() {
  #expect(x != nil)
}
""")
    cases.append(("a brace in a string does not hide later tests",
                  len(tests) == 2 and len(got) == 1 and got[0]["test"] == "j"))

    # 10. A `@Test(arguments:)` spanning lines still resolves to its func.
    got, tests = run("""@Test(arguments: [
  1, 2, 3,
])
func k(n: Int) {
  #expect(n != nil)
}
""")
    cases.append(("a multi-line @Test attribute still finds its func",
                  len(tests) == 1 and len(got) == 1))

    # 11. A commented-out assertion does not count as an assertion.
    got, _ = run("""@Test func l() {
  // #expect(abs(v - 8) < 1e-9)
  let s = 1
  _ = s
}
""")
    cases.append(("a commented-out assertion does not count",
                  len(got) == 1 and "no-assertions" in got[0]["reasons"]))

    # 12. A strong assertion behind a guard-return is still flagged, because the guard is what
    #     makes it skippable. Without this case the detector would only catch weak arguments.
    got, _ = run("""@Test func m() throws {
  guard let props = s.circleProperties else { return }
  #expect(abs(props.radius - 5) < 1e-9)
}
""")
    cases.append(("a strong assertion behind a guard-return is still flagged", len(got) == 1))

    # 12b. A test that delegates to a same-file helper is judged on the helper's assertions. This
    #      was the detector's largest false-positive class, found by reading what it flagged:
    #      three tests in one suite were reported as having no assertions when their one helper
    #      holds eleven.
    got, _ = run("""private func expectSameCurve(_ a: Curve3D?, _ b: Curve3D?) {
  #expect(a != nil)
  #expect(abs(a.domain.lowerBound - b.domain.lowerBound) < 1e-12)
}
@Test func delegating() {
  expectSameCurve(Curve3D.interpolatePeriodic(points: pts),
                  Curve3D.interpolate(points: pts, closed: true))
}
""")
    delegating = [f for f in got if f["test"] == "delegating"]
    cases.append(("a test delegating to a helper is not reported as assertion-free",
                  not delegating or "no-assertions" not in delegating[0]["reasons"]))

    # 13. The two tiers are distinguished, because the SEVERE one is the triage signal and the
    #     ESCAPABLE one is the tree's house style.
    sev, _ = run("@Test func n() {\n  #expect(x != nil)\n}\n")
    esc, _ = run("@Test func o() throws {\n  guard let v = s.volume else { return }\n"
                 "  #expect(abs(v - 8) < 1e-9)\n}\n")
    cases.append(("SEVERE and ESCAPABLE are told apart",
                  sev[0]["tier"] == "SEVERE" and esc[0]["tier"] == "ESCAPABLE"))

    # 14. One `if let` WITH an else and a second one WITHOUT is still flagged. A first version
    #     asked only whether the body held any `} else {` at all, so the second binding was free.
    got, _ = run("""@Test func p() {
  if let v = s.volume {
    #expect(abs(v - 8) < 1e-9)
  } else {
    Issue.record("no volume")
  }
  if let a = s.area {
    #expect(abs(a - 24) < 1e-9)
  }
}
""")
    cases.append(("a second if-let with no else is still flagged",
                  len(got) == 1 and "if-let-no-else" in got[0]["reasons"]))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", nargs="*", default=None,
                    help="the Swift test files to read; default is every file under --tests-root")
    ap.add_argument("--tests-root", default="Tests")
    ap.add_argument("--summary", action="store_true", help="counts only, no per-test list")
    ap.add_argument("--compare-baseline", action="store_true",
                    help="also print the SEVERE rate over the whole tree, so a scoped rate can be "
                         "read against it")
    ap.add_argument("--require-tests", action="store_true",
                    help="exit 2 rather than report clean when nothing was examined (#2098)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else census(args)


if __name__ == "__main__":
    sys.exit(main())

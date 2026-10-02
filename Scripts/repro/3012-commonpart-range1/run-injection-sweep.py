#!/usr/bin/env python3
"""#3012: the semantic injection sweep over `fillCommonPart`.

Run from the repository root with everything committed. It does one build and then runs the test
bundle once per switch, which is the mechanics `okf/references/injection-sweep-mechanics.md`
describes:

  * ONE temporary patch to `Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm`, every switch
    gated at run time by the `OCCT3012_INJECT` environment variable, so one build serves them all.
    Each anchor is asserted to match exactly once BEFORE anything is written, and the file is
    restored with `git checkout --` in a `finally`, never by reverse replacement. The file must
    be clean against HEAD to start, so that restore cannot discard work.
  * The built `.xctest` runs through `swiftpm-testing-helper` directly, which is 0.5 s a run
    against `swift test`'s minutes, with the three symlinks `PackageFrameworks` needs.
  * Failures are scraped with ANSI stripped, in both spellings Swift Testing prints (the display
    name and the function name), because a pattern anchored on the colour reset read eleven reds
    as green once.
  * The changed test set is derived from `git diff` against the base, not from anyone's notes,
    and checked against the switch set in both directions: every changed test is red under at
    least one switch, and every switch reddens at least one changed test.
  * The no-switch run is a control and must be green, so an inert harness cannot pass for a
    passing one.
  * A restore is not finished until the bundle is relinked, and nothing says when it is. Measured
    on this very sweep: the build that followed the restore recompiled `OCCTBridge.o` and linked
    `OCCTTopologyTests`, but left `OCCTAnalysisTests` linked against the INJECTED bridge, and the
    plain run was green because the switches are off unless the variable is set. What showed it
    was running the bundle with a switch set. So the script rebuilds until the bundle holds no
    injection marker, and then proves it with a switch set, which a clean bundle must ignore.

The switches are semantic: each is a mistake somebody could plausibly make in `fillCommonPart`,
not an arithmetic nudge.

    COLLAPSE         the pre-#3012 bridge: a vertex part's ranges are its vertex parameters twice over
    COLLAPSE_EDGE2   half a fix: Range1 is the kernel's but Ranges2(1) is still collapsed
    RANGE_SWAP       the two edges' ranges exchanged
    EDGE_VP          a vertex parameter reported on an .edge part, the constructor's 0.0
    EF_VP2           a second vertex parameter reported from an edge-face part, the constructor's 0.0
    NO_VP            no vertex parameter reported at all
    VP_SWAP          the two edges' vertex parameters exchanged
    VP_RAW           the raw VertexParameter1/2 instead of IntTools_Tools' resolution
    POINT_AT_FIRST   the point evaluated at the range's start instead of at the vertex parameter
"""

import os
import pathlib
import re
import subprocess
import sys

MM = "Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm"
FILES = [
    "Tests/OCCTAnalysisTests/IntToolsEdgeEdgeTests.swift",
    "Tests/OCCTAnalysisTests/IntToolsEdgeFaceTests.swift",
]
BUNDLE = "OCCTAnalysisTests"
MARKER = b"OCCT3012_INJECT"  # a string that exists only in the injected code
FILTER = "IntToolsEdge"
HELPER = ("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
          "/usr/libexec/swift/pm/swiftpm-testing-helper")
SWITCHES = ["COLLAPSE", "COLLAPSE_EDGE2", "RANGE_SWAP", "EDGE_VP", "EF_VP2", "NO_VP", "VP_SWAP",
            "VP_RAW", "POINT_AT_FIRST"]

# (anchor, replacement). Each anchor is asserted unique in the file before any edit.
ANCHORS = [
    (
        "    out.vertexParam1    = t1;\n"
        "    out.hasVertexParam1 = true;\n"
        "  }\n",
        "    out.vertexParam1    = t1;\n"
        "    out.hasVertexParam1 = true;\n"
        "  }\n"
        "  // 3012-INJECT: temporary, never committed. Each branch is one plausible wrong fillCommonPart.\n"
        "  const char* occt3012 = getenv(\"OCCT3012_INJECT\");\n"
        "  auto is3012 = [&](const char* mode) { return occt3012 != nullptr && strcmp(occt3012, mode) == 0; };\n"
        "  if (is3012(\"COLLAPSE\") && isVertex)\n"
        "  {\n"
        "    out.param1First = out.param1Last = out.vertexParam1;\n"
        "    if (hasEdge2)\n"
        "      out.param2First = out.param2Last = out.vertexParam2;\n"
        "  }\n"
        "  if (is3012(\"COLLAPSE_EDGE2\") && isVertex && hasEdge2)\n"
        "    out.param2First = out.param2Last = out.vertexParam2;\n"
        "  if (is3012(\"RANGE_SWAP\") && hasEdge2)\n"
        "  {\n"
        "    std::swap(out.param1First, out.param2First);\n"
        "    std::swap(out.param1Last, out.param2Last);\n"
        "  }\n"
        "  if (is3012(\"EDGE_VP\") && !isVertex)\n"
        "  {\n"
        "    out.hasVertexParam1 = true;\n"
        "    out.vertexParam1    = cp.VertexParameter1();\n"
        "    if (hasEdge2)\n"
        "    {\n"
        "      out.hasVertexParam2 = true;\n"
        "      out.vertexParam2    = cp.VertexParameter2();\n"
        "    }\n"
        "  }\n"
        "  if (is3012(\"EF_VP2\") && isVertex && !hasEdge2)\n"
        "  {\n"
        "    out.hasVertexParam2 = true;\n"
        "    out.vertexParam2    = cp.VertexParameter2();\n"
        "  }\n"
        "  if (is3012(\"NO_VP\"))\n"
        "  {\n"
        "    out.hasVertexParam1 = false;\n"
        "    out.hasVertexParam2 = false;\n"
        "  }\n"
        "  if (is3012(\"VP_SWAP\") && isVertex && hasEdge2)\n"
        "    std::swap(out.vertexParam1, out.vertexParam2);\n"
        "  if (is3012(\"VP_RAW\") && isVertex)\n"
        "  {\n"
        "    out.vertexParam1 = cp.VertexParameter1();\n"
        "    if (hasEdge2)\n"
        "      out.vertexParam2 = cp.VertexParameter2();\n"
        "  }\n",
    ),
    (
        "    const double      t = out.hasVertexParam1\n"
        "                            ? out.vertexParam1\n"
        "                            : IntTools_Tools::IntermediatePoint(out.param1First, out.param1Last);\n",
        "    const double      t = is3012(\"POINT_AT_FIRST\")\n"
        "                              ? out.param1First\n"
        "                              : (out.hasVertexParam1\n"
        "                                   ? out.vertexParam1\n"
        "                                   : IntTools_Tools::IntermediatePoint(out.param1First, out.param1Last));\n",
    ),
]

ANSI = re.compile(r"\x1b\[[0-9;]*m")
# The run-level summary line reads `Test run with N tests ... passed|failed`, which is not a test.
FAIL = re.compile(r"✘ Test (?!run with )(.+?) (?:recorded an issue|failed)")
PASS = re.compile(r"✔ Test (?!run with )(.+?) passed")


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def sh(cmd):
    p = run(cmd)
    if p.returncode != 0:
        sys.stderr.write(p.stdout + p.stderr)
        raise SystemExit("failed: %s" % " ".join(cmd))
    return p.stdout


def test_spans(path):
    """{func name: (display name, first line, last line)} for every @Test in the file, 1-based.

    The span runs from the `@Test` attribute to the closing brace of the function. Doc comments
    above the attribute are deliberately outside it: rewording one is not changing the test.
    String literals and comments are skipped while matching braces.
    """
    text = pathlib.Path(path).read_text(encoding="utf-8")
    lines = text.split("\n")
    starts = [m.start() for m in re.finditer(r"^\s*@Test\b", text, flags=re.M)]
    out = {}
    for start in starts:
        head = text[start:start + 400]
        fm = re.search(r"func\s+(\w+)\s*\(", head)
        dm = re.match(r"\s*@Test\(\s*\"((?:[^\"\\]|\\.)*)\"", head)
        name = fm.group(1)
        display = dm.group(1) if dm else name
        i = text.index("{", start + fm.end())
        depth, j = 0, i
        in_str = False
        while j < len(text):
            c = text[j]
            if in_str:
                if c == "\\":
                    j += 1
                elif c == '"':
                    in_str = False
            elif text.startswith("//", j):
                j = text.index("\n", j)
                continue
            elif c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        first = text.count("\n", 0, start) + 1
        last = text.count("\n", 0, j) + 1
        out[name] = (display, first, last)
    assert out, "no @Test found in %s" % path
    assert max(v[2] for v in out.values()) <= len(lines)
    return out


def changed_tests(base):
    """The tests whose own lines (attribute to closing brace) the diff against `base` touches."""
    changed = {}
    for path in FILES:
        diff = sh(["git", "diff", "-U0", "%s...HEAD" % base, "--", path])
        added = set()
        for m in re.finditer(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", diff, flags=re.M):
            start, count = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            added.update(range(start, start + count))
        for name, (display, first, last) in test_spans(path).items():
            if any(first <= n <= last for n in added):
                changed[name] = display
    return changed


def scrape(output, display_to_func):
    def norm(raw):
        raw = raw.strip()
        if raw.startswith('"') and raw.endswith('"'):
            return display_to_func.get(raw[1:-1], raw[1:-1])
        return re.sub(r"\(\)$", "", raw)

    failed = {norm(m) for m in FAIL.findall(output)}
    passed = {norm(m) for m in PASS.findall(output)}
    return failed, passed


def run_bundle(inject, display_to_func):
    env = dict(os.environ)
    env.pop("OCCTSWIFT_BRIDGE_PREBUILT", None)
    if inject:
        env["OCCT3012_INJECT"] = inject
    else:
        env.pop("OCCT3012_INJECT", None)
    exe = bundle_path()
    p = run([HELPER, "--test-bundle-path", exe, "--filter", FILTER, exe, "--testing-library",
             "swift-testing"], env=env)
    out = ANSI.sub("", p.stdout + p.stderr)
    summary = re.search(r"Test run with (\d+) tests? in (\d+) suites? (passed|failed)", out)
    failed, passed = scrape(out, display_to_func)
    return failed, passed, summary.group(0) if summary else None, p.returncode


def bundle_path():
    return os.path.abspath(".build/out/Products/Debug/%s.xctest/Contents/MacOS/%s" % (BUNDLE, BUNDLE))


def prove_clean(display_to_func):
    """Rebuild until the bundle holds no injection marker, then run it with a switch set."""
    env = dict(os.environ)
    env.pop("OCCTSWIFT_BRIDGE_PREBUILT", None)
    for attempt in range(1, 4):
        b = run(["swift", "build", "--target", BUNDLE], env=env)
        if b.returncode != 0:
            sys.stderr.write(b.stdout[-3000:] + b.stderr[-3000:])
            return False
        present = MARKER in pathlib.Path(bundle_path()).read_bytes()
        print("rebuild %d after the restore: injection marker %s in the test bundle" %
              (attempt, "STILL PRESENT" if present else "absent"))
        if not present:
            break
    else:
        sys.stderr.write("the bundle still carries the injection after three rebuilds\n")
        return False
    failed, _, summary, code = run_bundle("COLLAPSE", display_to_func)
    print("restored bundle with a switch set, which it must ignore: %s, exit %s" % (summary, code))
    return not failed and code == 0


def main():
    if not (os.path.isfile("Package.swift") and os.path.isfile(MM)):
        sys.stderr.write("error: run from the repository root\n")
        return 2
    if os.environ.get("OCCTSWIFT_BRIDGE_PREBUILT"):
        print("note: OCCTSWIFT_BRIDGE_PREBUILT is set; it is unset for every build and run below")
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    if run(["git", "diff", "--quiet", "HEAD", "--", MM]).returncode != 0:
        sys.stderr.write("error: %s has uncommitted changes; commit first so the restore cannot "
                         "discard them\n" % MM)
        return 2

    changed = changed_tests(base)
    print("changed tests derived from git diff %s...HEAD (%d):" % (base, len(changed)))
    for name in sorted(changed):
        print("  %s" % name)
    display_to_func = {}
    for path in FILES:
        for name, (display, _, _) in test_spans(path).items():
            display_to_func[display] = name

    text = pathlib.Path(MM).read_text(encoding="utf-8")
    for anchor, _ in ANCHORS:
        assert text.count(anchor) == 1, "anchor matches %d times:\n%s" % (text.count(anchor), anchor)
    print("both anchors resolve uniquely in %s" % MM)

    rows = []
    try:
        patched = text
        for anchor, replacement in ANCHORS:
            patched = patched.replace(anchor, replacement)
        pathlib.Path(MM).write_text(patched, encoding="utf-8")
        env = dict(os.environ)
        env.pop("OCCTSWIFT_BRIDGE_PREBUILT", None)
        b = run(["swift", "build", "--target", BUNDLE], env=env)
        if b.returncode != 0:
            sys.stderr.write(b.stdout[-3000:] + b.stderr[-3000:])
            return 1
        print("built once with every switch compiled in")

        failed, passed, summary, code = run_bundle("", display_to_func)
        print("control (no switch): %s, exit %s, %d passed, %d failed" %
              (summary, code, len(passed), len(failed)))
        if failed or code != 0 or not summary or "passed" not in summary:
            sys.stderr.write("the no-switch control is not green, so nothing below means anything\n")
            return 1

        for switch in SWITCHES:
            failed, _, summary, code = run_bundle(switch, display_to_func)
            rows.append((switch, failed, summary, code))
            reds = sorted(f for f in failed if f in changed)
            other = sorted(f for f in failed if f not in changed)
            print("%-15s red %2d of %d changed  exit %s%s" % (
                switch, len(reds), len(changed), code,
                ("  (also reddens unchanged: %s)" % ", ".join(other)) if other else ""))
            for f in reds:
                print("    %s" % f)
    finally:
        sh(["git", "checkout", "--", MM])
        print("restored %s with git checkout --" % MM)

    if not prove_clean(display_to_func):
        sys.stderr.write("the restored tree did not prove clean\n")
        return 1

    covered = set()
    for _, failed, _, _ in rows:
        covered |= {f for f in failed if f in changed}
    ok = True
    never = sorted(set(changed) - covered)
    if never:
        ok = False
        print("\nCHANGED TESTS RED UNDER NO SWITCH (a test no injection reds looks exactly like a "
              "blind test):")
        for n in never:
            print("   ", n)
    idle = [s for s, failed, _, _ in rows if not any(f in changed for f in failed)]
    if idle:
        ok = False
        print("\nSWITCHES THAT REDDEN NO CHANGED TEST:", ", ".join(idle))
    if ok:
        print("\nboth directions hold: every changed test is red under at least one switch, and "
              "every switch reddens at least one changed test (%d tests, %d switches)" %
              (len(changed), len(SWITCHES)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

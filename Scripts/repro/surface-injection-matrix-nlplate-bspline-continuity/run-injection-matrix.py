#!/usr/bin/env python3
"""Run the #766 Surface batch (batch 12) injection matrix against the built OCCTSurfaceTests bundle.

usage: python3 Scripts/repro/surface-injection-matrix-nlplate-bspline-continuity/run-injection-matrix.py LABEL [--root DIR]

Reads `switches.txt` beside this file, runs the fourteen suites once with NO switch (and requires
every test green, so an inert or already-red harness cannot read as a clean sweep), then once per
switch, and writes `matrix-LABEL.json` here. It then derives the CHANGED test set from
`git diff origin/main..HEAD` (a test is changed when its body differs from origin/main's) and
asserts the sweep in both directions: every changed test red under at least one switch (or named in
`NO_SWITCH` with its reason), and every switch reddening at least one changed test.

Mechanics, from okf/references/injection-sweep-mechanics.md:
  * the built .xctest goes through `swiftpm-testing-helper`, which needs XCTest.framework,
    Testing.framework and libXCTestSwiftSupport.dylib symlinked into
    .build/out/Products/Debug/PackageFrameworks (SIP strips DYLD_* from the signed helper);
  * ANSI is stripped before scraping, both failure-line spellings are matched (`Test "Display"` and
    `Test func()`), and a known issue (the `━` glyph) is a pass;
  * exit -15 / 143 is the machine reaping the run, so it is retried; a crash (any other negative or
    > 1 exit) is named as a crash.

LABEL `before` is run with origin/main's versions of the fourteen files in the tree, `after` with the
lifted ones. Commit the lifted files before swapping the old ones in (`git checkout HEAD -- <files>`
restores what was COMMITTED).
"""
import json
import os
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(__file__).resolve().parents[3]
HELPER = (
    "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
    "/usr/libexec/swift/pm/swiftpm-testing-helper"
)
D = "Tests/OCCTSurfaceTests/"
FILES = [D + n + ".swift" for n in (
    "SurfaceContinuityQueriesTests", "SurfaceContinuityTests", "SurfaceConversionTests",
    "SurfaceCurvatureParityTests", "BSplineSurfaceKnotTests", "BSplineSurfaceLocalEvalTests",
    "LoftRuledTests", "NLPlateDeformationTests", "NLPlateG2G3Tests", "ParametricPlateSurfaceTests",
    "TBezierCurve3DTests", "TBezierSurfaceTests", "TopTransSurfaceTransitionTests", "TypeNameTests")]
SUITES = [os.path.basename(f)[:-len(".swift")] for f in FILES]
FILTER = r"OCCTSurfaceTests\.(" + "|".join(SUITES) + r")/"

# A changed test with no switch that can redden it, and why. A known-issue pin that holds today
# cannot be reddened by distorting the subject (it already fails); only the opposite injection, a
# fix, reddens it, and where no fix can be injected the reason is stated here.
NO_SWITCH = {
    "NLPlateDeformationTests.nlPlateG0MultipleConstraints": (
        "pins three targets as a known issue (#3133); no shadow can fix a fixed-grid refit, so its "
        "teeth are withKnownIssue's own contract, not a switch"),
}

ANSI = re.compile(r"\x1b\[[0-9;]*m")
TEST_DECL = re.compile(
    r'@Test(?:\(\s*"((?:[^"\\]|\\.)*)"[^)]*\))?\s*(?:private\s+|fileprivate\s+)?func\s+(\w+)\s*\(')
FAIL = re.compile(r'^✘ Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) (?:recorded an issue|failed)', re.M)
PASS = re.compile(r'^[✔━] Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) passed', re.M)


def tests_in(text):
    """[(printed name, func name, body)] for every @Test in a file."""
    ms = list(TEST_DECL.finditer(text))
    out = []
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        disp, fn = m.group(1), m.group(2)
        key = (disp if disp else f"{fn}()").replace('\\"', '"')
        out.append((key, fn, text[m.start():end]))
    return out


def name_map(root):
    names, order = {}, []
    for f in FILES:
        text = (root / f).read_text(encoding="utf-8")
        stem = os.path.basename(f)[:-len(".swift")]
        for key, fn, _ in tests_in(text):
            if key in names:
                print(f"WARNING: printed name {key!r} is not unique ({names[key]} and {stem}.{fn})")
            names[key] = (stem, fn)
            order.append((stem, fn))
    return names, order


def changed_tests(root, from_head=False):
    """Tests whose body differs between origin/main and the working tree (or HEAD, for `before`,
    whose tree holds origin/main's files)."""
    out = set()
    for f in FILES:
        new_txt = (subprocess.run(["git", "show", f"HEAD:{f}"], capture_output=True, text=True,
                                  cwd=root).stdout if from_head else (root / f).read_text(encoding="utf-8"))
        new = {fn: body for _, fn, body in tests_in(new_txt)}
        old_txt = subprocess.run(["git", "show", f"origin/main:{f}"], capture_output=True, text=True,
                                 cwd=root).stdout
        old = {fn: body for _, fn, body in tests_in(old_txt)}
        stem = os.path.basename(f)[:-len(".swift")]
        for fn, body in new.items():
            if old.get(fn) != body:
                out.add(f"{stem}.{fn}")
    return out


def dump_matrix(data):
    rows = list(data["rows"].items())
    lines = ["{", f' "label": {json.dumps(data["label"])},', f' "tests": {json.dumps(data["tests"])},',
             ' "rows": {']
    for i, (switch, row) in enumerate(rows):
        comma = "," if i < len(rows) - 1 else ""
        lines.append(f"  {json.dumps(switch)}: {json.dumps(row)}{comma}")
    lines += [" }", "}", ""]
    return "\n".join(lines)


def run(bundle, switch):
    env = dict(os.environ)
    env.pop("SF_SWITCH", None)
    if switch:
        env["SF_SWITCH"] = switch
    for _ in range(4):
        p = subprocess.run(
            [HELPER, "--test-bundle-path", str(bundle), "--filter", FILTER, str(bundle),
             "--testing-library", "swift-testing"],
            capture_output=True, text=True, env=env, timeout=900)
        if p.returncode in (-15, 143):
            continue
        break
    return p.returncode, ANSI.sub("", p.stdout + p.stderr)


def scrape(out, names):
    def keyed(rx):
        found = set()
        for m in rx.finditer(out):
            key = (m.group(1) if m.group(1) is not None else f"{m.group(2)}()").replace('\\"', '"')
            if not key.startswith("run with"):
                found.add(names.get(key, ("?", key)))
        return found

    return keyed(FAIL), keyed(PASS)


def main():
    label = sys.argv[1]
    root = pathlib.Path(sys.argv[sys.argv.index("--root") + 1]) if "--root" in sys.argv else ROOT
    bundle = (root / ".build/out/Products/Debug/OCCTSurfaceTests.xctest/Contents/MacOS/OCCTSurfaceTests")
    names, order = name_map(root)
    switches = [l.strip() for l in (HERE / "switches.txt").read_text().splitlines()
                if l.strip() and not l.startswith("#")]

    code, out = run(bundle, "")
    red, green = scrape(out, names)
    print(f"[{label}] BASELINE exit={code} tests={len(order)} green={len(green)} red={len(red)}")
    if code != 0 or red or len(green) != len(order):
        print("baseline is not clean; stopping")
        print(out[-3000:])
        sys.exit(1)

    rows = {}
    for sw in switches:
        code, out = run(bundle, sw)
        red, green = scrape(out, names)
        crashed = code < 0 or code > 1 or "Abort ***" in out
        rows[sw] = {"red": sorted(f"{a}.{b}" for a, b in red), "exit": code, "crash": crashed,
                    "ran": len(red) + len(green)}
        print(f"{sw:34s} exit={code:<4} reds={len(red):<3}{'  CRASH' if crashed else ''}")
    data = {"label": label, "tests": [f"{a}.{b}" for a, b in order], "rows": rows}
    (HERE / f"matrix-{label}.json").write_text(dump_matrix(data))

    changed = changed_tests(root, from_head=(label == "before"))
    reddened = set()
    for r in rows.values():
        reddened |= set(r["red"])
    dead = [s for s, r in rows.items() if not (set(r["red"]) & changed)]
    uncaught = sorted(t for t in changed if t not in reddened and t not in NO_SWITCH)
    crashed = [s for s, r in rows.items() if r["crash"]]
    print(f"\n[{label}] switches={len(switches)} changed tests={len(changed)}")
    print(f"changed tests reddened by at least one switch: {len(changed & reddened)} of {len(changed)}")
    print(f"switches that redden no changed test: {len(dead)} {dead}")
    print(f"changed tests no switch reddens (unexplained): {uncaught}")
    print(f"declared NO_SWITCH: {sorted(t for t in changed if t in NO_SWITCH)}")
    print(f"crashes: {crashed}")


if __name__ == "__main__":
    main()

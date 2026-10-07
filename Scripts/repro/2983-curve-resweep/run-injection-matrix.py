#!/usr/bin/env python3
"""Run the #2983 Curve injection matrix against the built OCCTCurveTests bundle.

usage: python3 Scripts/repro/2983-shapehealing-resweep/run-injection-matrix.py LABEL [--root DIR]

Reads `switches.txt` and `files.txt` beside this file, runs the suites once with NO switch (and requires every
test green, so an inert or already-red harness cannot read as a clean sweep), then once per switch,
and writes `matrix-LABEL.json` here. Prints one line per switch and the summary.

Mechanics, all from okf/references/injection-sweep-mechanics.md:
  * the built .xctest goes through `swiftpm-testing-helper` (about half a second a run, against the
    minutes `swift test` takes under load); it needs XCTest.framework, Testing.framework and
    libXCTestSwiftSupport.dylib symlinked into .build/out/Products/Debug/PackageFrameworks, because
    SIP strips DYLD_* from the signed helper;
  * ANSI is stripped before scraping (the reset sits between the glyph and the word, and a scraper
    anchored on the glyph read eleven reds as green);
  * both failure-line spellings are matched, `Test "Display name"` and `Test func()`, and a known
    issue (`━`) is a pass;
  * exit -15 / 143 is the machine reaping the run, not a result, so it is retried.
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
FILES = [l.strip() for l in (HERE / "files.txt").read_text().splitlines() if l.strip()]
FILTER = "|".join(
    sorted({m for f in FILES for m in re.findall(r"^struct (\w+)", (ROOT / f).read_text(), re.M)})
)

HANG_SECONDS = 150
HANG_CODE = -999
ANSI = re.compile(r"\x1b\[[0-9;]*m")
TEST_DECL = re.compile(
    r'@Test(?:\(\s*"((?:[^"\\]|\\.)*)"[^\n]*?\))?\s+(?:private\s+|fileprivate\s+)?func\s+(\w+)\s*\(',
    re.M,
)
FAIL = re.compile(r'^✘ Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) (?:recorded an issue|failed)', re.M)
PASS = re.compile(r'^[✔━] Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) passed', re.M)


def name_map(root):
    """Printed name -> (suite stem, func name), and the declaration-ordered list of both."""
    names, order = {}, []
    for f in FILES:
        text = (root / f).read_text(encoding="utf-8")
        structs = [(m.start(), m.group(1)) for m in re.finditer(r"^struct (\w+)", text, re.M)]
        for m in TEST_DECL.finditer(text):
            disp, fn = m.group(1), m.group(2)
            stem = [n for pos, n in structs if pos < m.start()][-1]
            key = (disp if disp else f"{fn}()").replace('\\"', '"')
            assert key not in names, f"duplicate printed test name {key!r}"
            names[key] = (stem, fn)
            order.append((stem, fn))
    return names, order


def dump_matrix(data):
    """JSON with one line per switch, so a diff of two matrices reads switch by switch."""
    rows = list(data["rows"].items())
    lines = [
        "{",
        f' "label": {json.dumps(data["label"])},',
        f' "tests": {json.dumps(data["tests"])},',
        ' "rows": {',
    ]
    for i, (switch, row) in enumerate(rows):
        comma = "," if i < len(rows) - 1 else ""
        lines.append(f"  {json.dumps(switch)}: {json.dumps(row)}{comma}")
    lines += [" }", "}", ""]
    return "\n".join(lines)


def run(bundle, switch):
    env = dict(os.environ)
    env.pop("SWEEP_CURVE_SWITCH", None)
    if switch:
        env["SWEEP_CURVE_SWITCH"] = switch
    for _ in range(4):
        try:
            p = subprocess.run(
                [HELPER, "--test-bundle-path", str(bundle), "--filter", FILTER, str(bundle),
                 "--testing-library", "swift-testing"],
                capture_output=True, text=True, env=env, timeout=HANG_SECONDS)
        except subprocess.TimeoutExpired as e:
            # A switch that makes a call allocate or loop for minutes is a result (a hang), not a
            # reason to stop the sweep; the child was started here and is killed by `run`.
            partial = e.stdout.decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
            return HANG_CODE, ANSI.sub("", partial)
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
    bundle = (root / ".build/out/Products/Debug/OCCTCurveTests.xctest"
              "/Contents/MacOS/OCCTCurveTests")
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
        hung = code == HANG_CODE
        crashed = (code < 0 and not hung) or code > 1 or "Abort ***" in out
        rows[sw] = {"red": sorted(f"{a}.{b}" for a, b in red), "exit": code, "crash": crashed, "hang": hung,
                    "ran": len(red) + len(green)}
        print(f"{sw:34s} exit={code:<4} reds={len(red):<3}{'  CRASH' if crashed else ''}{'  HANG' if hung else ''}")
    data = {"label": label, "tests": [f"{a}.{b}" for a, b in order], "rows": rows}
    (HERE / f"matrix-{label}.json").write_text(dump_matrix(data))

    all_red = set()
    for r in rows.values():
        all_red |= set(r["red"])
    dead = [s for s, r in rows.items() if not (r["red"] or r["hang"] or r["crash"])]
    crashed = [s for s, r in rows.items() if r["crash"]]
    never = [f"{a}.{b}" for a, b in order if f"{a}.{b}" not in all_red]
    print()
    print(f"[{label}] switches whose run CRASHED the process ({len(crashed)}): {crashed}")
    print(f"[{label}] switches={len(rows)}  tests={len(order)}")
    print(f"[{label}] switches that redden, hang or crash NOTHING ({len(dead)}): {dead}")
    print(f"[{label}] tests that NO switch reddens ({len(never)}): {never}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Run one OCCTCurveTests batch 3 (bezier-bspline) PR's injection matrix against the built test bundles of the target(s) its files live in.

usage (repo root): python3 <this dir>/run-injection-matrix.py LABEL [--files FILE] [--switches FILE] [--out FILE]

--files  the PR's lifted test files, one per line (default: every Tests/ file in `git diff origin/main HEAD`)
--switches  default switches.txt beside this script
--out    default matrix-LABEL.json beside this script

LABEL names the output, `matrix-LABEL.json` beside this file. `after` is run with the lifted files in
the tree; `before` with `git checkout origin/main --` of every lifted path (restore with
`git checkout HEAD -- Tests`).

Reads `switches.txt` (written by generate-shadow.py), runs each bundle's lifted suites once with NO
switch and requires every test green (an inert or already-red harness cannot read as a clean sweep),
then once per switch with CRV_SWITCH set. It derives the CHANGED test set from the diff against
origin/main (a test is changed when its body differs, or it does not exist there) and reports, both
ways: which changed tests no switch reddens, and which switches redden no changed test.

Mechanics from okf/references/injection-sweep-mechanics.md: the built .xctest goes through
swiftpm-testing-helper; ANSI is stripped before scraping; both failure-line spellings are matched; a
known issue (the `━` glyph) is a pass; exit -15 / 143 is retried; any other negative or >1 exit is a
crash and is named as one.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(__file__).resolve().parents[3]
HELPER = ("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
          "/usr/libexec/swift/pm/swiftpm-testing-helper")
def _arg(flag):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else None


if _arg("--files"):
    LIFTED = pathlib.Path(_arg("--files")).read_text().split()
else:
    LIFTED = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AM", "origin/main", "HEAD", "--", "Tests"],
        capture_output=True, text=True, cwd=ROOT).stdout.split()

ANSI = re.compile(r"\x1b\[[0-9;]*m")
TEST_DECL = re.compile(
    r'@Test(?:\(\s*"((?:[^"\\]|\\.)*)"[^)]*\))?\s*(?:private\s+|fileprivate\s+)?func\s+(\w+)\s*\(')
FAIL = re.compile(r'^✘ Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) (?:recorded an issue|failed)', re.M)
PASS = re.compile(r'^[✔━] Test (?:"((?:[^"\\]|\\.)*)"|(\w+)\(\)) passed', re.M)
STRUCT = re.compile(r'^\s*(?:@Suite(?:\([^)]*\))?\s*)?(?:final\s+)?struct\s+(\w+)', re.M)


def tests_in(text):
    ms = list(TEST_DECL.finditer(text))
    out = []
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        disp, fn = m.group(1), m.group(2)
        key = (disp if disp else f"{fn}()").replace('\\"', '"')
        body = text[m.start():end].rstrip().split("\n")
        while body and (body[-1].strip().startswith("///") or not body[-1].strip()):
            body.pop()
        out.append((key, fn, "\n".join(body)))
    return out


def targets():
    t = {}
    for f in LIFTED:
        parts = f.split("/")
        if len(parts) > 2 and parts[1].startswith("OCCT") and parts[1].endswith("Tests") and f.endswith(".swift"):
            t.setdefault(parts[1], []).append(f)
    return t


def name_map(files, root):
    names, order = {}, []
    for f in files:
        text = (root / f).read_text(encoding="utf-8")
        stem = os.path.basename(f)[:-6]
        for key, fn, _ in tests_in(text):
            names[key] = (stem, fn)
            order.append((stem, fn))
    return names, order


def changed_tests(files, root, from_head):
    out = set()
    for f in files:
        new_txt = (subprocess.run(["git", "show", f"HEAD:{f}"], capture_output=True, text=True,
                                  cwd=root).stdout if from_head else (root / f).read_text(encoding="utf-8"))
        old_txt = subprocess.run(["git", "show", f"origin/main:{f}"], capture_output=True, text=True,
                                 cwd=root).stdout
        old = {fn: body for _, fn, body in tests_in(old_txt)}
        stem = os.path.basename(f)[:-6]
        for _, fn, body in tests_in(new_txt):
            if old.get(fn) != body:
                out.add(f"{stem}.{fn}")
    return out


def run(bundle, flt, switch):
    env = dict(os.environ)
    env.pop("CRV_SWITCH", None)
    if switch:
        env["CRV_SWITCH"] = switch
    for _ in range(5):
        p = subprocess.run([HELPER, "--test-bundle-path", str(bundle), "--filter", flt, str(bundle),
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
    sw_file = pathlib.Path(_arg("--switches") or HERE / "switches.txt")
    root = ROOT
    switches = [l.strip() for l in sw_file.read_text().splitlines()
                if l.strip() and not l.startswith("#")]
    result = {"label": label, "targets": {}}
    for target, files in sorted(targets().items()):
        bundle = root / f".build/out/Products/Debug/{target}.xctest/Contents/MacOS/{target}"
        structs = []
        for f in files:
            structs += STRUCT.findall((root / f).read_text(encoding="utf-8"))
        flt = target + r"\.(" + "|".join(sorted(set(structs))) + r")/"
        names, order = name_map(files, root)
        code, out = run(bundle, flt, "")
        red, green = scrape(out, names)
        print(f"[{label}/{target}] BASELINE exit={code} tests={len(order)} green={len(green)} red={len(red)}")
        if code != 0 or red or len(green) != len(order):
            print("baseline is not clean; stopping")
            print(out[-3000:])
            sys.exit(1)

        def one(sw):
            c, o = run(bundle, flt, sw)
            r, g = scrape(o, names)
            return sw, {"red": sorted(f"{a}.{b}" for a, b in r), "exit": c,
                        "crash": (c < 0 or c > 1 or "Abort ***" in o), "ran": len(r) + len(g)}

        with ThreadPoolExecutor(max_workers=4) as ex:
            rows = dict(ex.map(one, switches))
        changed = changed_tests(files, root, from_head=label.startswith("before"))
        reddened = set()
        for r in rows.values():
            reddened |= set(r["red"])
        dead = [s for s, r in rows.items() if not (set(r["red"]) & changed)]
        live = [s for s in rows if s not in dead]
        uncaught = sorted(t for t in changed if t not in reddened)
        crashed = [s for s, r in rows.items() if r["crash"]]
        print(f"[{label}/{target}] switches={len(switches)} changed tests={len(changed)}")
        print(f"  changed tests reddened by at least one switch: {len(changed & reddened)} of {len(changed)}")
        print(f"  switches that redden a changed test: {len(live)} of {len(switches)}")
        print(f"  changed tests no switch reddens: {uncaught}")
        print(f"  crashes: {crashed}")
        result["targets"][target] = {"tests": [f"{a}.{b}" for a, b in order], "changed": sorted(changed),
                                     "unreddened": uncaught, "live_switches": len(live),
                                     "switches": len(switches), "crashes": crashed, "rows": rows}
    out = pathlib.Path(_arg("--out") or HERE / f"matrix-{label}.json")
    # one switch per line, and only the switches that did something (a red test, or a crash): the rest
    # are implied by "switches" and cost thousands of lines of {"red": [], "exit": 0}
    for t in result["targets"].values():
        t["rows"] = {s: r for s, r in t["rows"].items() if r["red"] or r["crash"]}
    lines = ["{", f' "label": {json.dumps(label)},', ' "targets": {']
    tg = result["targets"]
    for ti, (name, t) in enumerate(tg.items()):
        head = {k: v for k, v in t.items() if k != "rows"}
        lines.append(f'  {json.dumps(name)}: {{')
        lines.append(f'   "summary": {json.dumps(head, sort_keys=True)},')
        lines.append('   "rows_that_did_something": {')
        items = sorted(t["rows"].items())
        for i, (s_, r) in enumerate(items):
            lines.append(f"    {json.dumps(s_)}: {json.dumps(r, sort_keys=True)}" + ("," if i < len(items) - 1 else ""))
        lines.append("   }")
        lines.append("  }" + ("," if ti < len(tg) - 1 else ""))
    lines.append(" }")
    lines.append("}")
    out.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

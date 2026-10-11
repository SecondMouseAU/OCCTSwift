#!/usr/bin/env python3
"""Run the #2983 Math re-sweep injection matrix against the built OCCTMathTests bundle.

usage: run-injection-matrix.py LABEL     (from anywhere; writes matrix-LABEL.json beside this file)

Runs the seven suites once with NO switch (every test must be green), then once per switch named in
inject.py. ANSI is stripped before scraping; a crash (exit <0 or >1 with no failure line) is named,
and exit -15/143 is retried. See okf/references/injection-sweep-mechanics.md.
"""
import json, os, pathlib, re, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
HELPER = ("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
          "/usr/libexec/swift/pm/swiftpm-testing-helper")
BUNDLE = ROOT / ".build/out/Products/Debug/OCCTMathTests.xctest/Contents/MacOS/OCCTMathTests"
FILES = {
    "PeriodTests": "Tests/OCCTMathTests/Utilities/PeriodTests.swift",
    "TransformExpansionTests": "Tests/OCCTMathTests/Transforms/TransformExpansionTests.swift",
    "TrsfExtrasTests": "Tests/OCCTMathTests/Transforms/TrsfExtrasTests.swift",
    "MathPolynomialRootsTests": "Tests/OCCTMathTests/Polynomials/MathPolynomialRootsTests.swift",
    "MathSolverSystemTests": "Tests/OCCTMathTests/Solvers/MathSolverSystemTests.swift",
    "NewtonMinimumTests": "Tests/OCCTMathTests/Solvers/NewtonMinimumTests.swift",
    "TrigRootsTests": "Tests/OCCTMathTests/Solvers/TrigRootsTests.swift",
}
FILTER = "OCCTMathTests\\.(" + "|".join(FILES) + ")/"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
DECL = re.compile(r"@Test(?:\([^)]*\))?\s*(?:private\s+)?func\s+(\w+)\s*\(")
FAIL = re.compile(r"^✘ Test (\w+)\(\) (?:recorded an issue|failed)", re.M)
PASS = re.compile(r"^[✔━] Test (\w+)\(\) passed", re.M)


def declared():
    out = []
    for suite, f in FILES.items():
        out += [f"{suite}.{m}" for m in DECL.findall((ROOT / f).read_text())]
    return out


def switches():
    src = (HERE / "inject.py").read_text()
    seen = []
    for n in re.findall(r"J\('([A-Z0-9_]+)'\)", src):
        if n not in seen:
            seen.append(n)
    return seen


def run(sw):
    env = dict(os.environ)
    env.pop("MATH_INJ", None)
    if sw:
        env["MATH_INJ"] = sw
    for _ in range(4):
        p = subprocess.run([HELPER, "--test-bundle-path", str(BUNDLE), "--filter", FILTER, str(BUNDLE),
                            "--testing-library", "swift-testing"],
                           capture_output=True, text=True, env=env, timeout=900)
        if p.returncode not in (-15, 143):
            break
    return p.returncode, ANSI.sub("", p.stdout + p.stderr)


def main():
    label = sys.argv[1]
    tests = declared()
    # test names are unique within a suite; the printed line only has the func name, so key by name
    names = {}
    for t in tests:
        names.setdefault(t.split(".")[1], []).append(t)
    code, out = run("")
    green = set(PASS.findall(out)); red = set(FAIL.findall(out))
    print(f"[{label}] BASELINE exit={code} declared={len(tests)} green={len(green)} red={len(red)}")
    if code != 0 or red or len(green) != len(names):
        print(out[-3000:]); sys.exit("baseline not green")
    rows = {}
    for sw in switches():
        code, out = run(sw)
        red = sorted(set(FAIL.findall(out)))
        crash = code < 0 or (code > 1)
        rows[sw] = {"exit": code, "crash": crash, "red": red}
        print(f"{sw:20s} exit={code:4d} red={len(red)} {red}{'  CRASH' if crash else ''}")
    (HERE / f"matrix-{label}.json").write_text(json.dumps({"label": label, "tests": sorted(names), "rows": rows}, indent=1) + "\n")
    silent = [s for s, r in rows.items() if not r["red"] and not r["crash"]]
    caught = {t for r in rows.values() for t in r["red"]}
    print("SWITCHES THAT REDDEN NOTHING:", silent)
    print("TESTS NEVER RED:", sorted(set(names) - caught))


main()

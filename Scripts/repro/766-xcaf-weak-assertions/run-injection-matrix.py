#!/usr/bin/env python3
"""#766 XCAF slice: run the injection matrix and report which tests each injection reds.

Runs the test bundle once per injection id, scraping BOTH spellings Swift Testing uses for a
failure line (the display-name form and the func() form). Asserts the switch count against the
test count at the end, so an injection that was never wired shows up as a missing row rather
than as a clean sweep.
"""
import os
import re
import subprocess
import sys
import pathlib

ROOT = pathlib.Path("/Users/elb/Projects/OCCTSwift/.claude/worktrees/agent-ab47633332e4e61a9")
BUNDLE = ROOT / ".build/out/Products/Debug/OCCTXCAFTests.xctest/Contents/MacOS/OCCTXCAFTests"
HELPER = (
    "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
    "/usr/libexec/swift/pm/swiftpm-testing-helper"
)

SUITES = [
    "TNamingTracingTests",
    "XDEShapeToolQueryTests",
    "DocumentExplorerTests",
    "XCAFDocShapeMapToolTests",
    "TNamingExtensionTests",
    "TNamingBasicTests",
    "IDFilterTests",
    "XDEEditorTests",
    "TNamingSelectResolveTests",
    "DocumentExplorerExtensionTests",
    "XCAFDocAssemblyIteratorTests",
    "DirectoryTests",
]
FILTER = "|".join(SUITES)

# The 63 tests this PR touched, keyed by the func() spelling the runner prints.
TOUCHED = {
    "TNamingTracingTests": [
        "traceForward", "traceBackward", "multipleGenerations", "emptyTraceForUnrelated",
        "traceModificationChain", "forwardTraceExcludesSource", "backwardTraceExcludesGenerated",
    ],
    "XDEShapeToolQueryTests": [
        "addShapeAndCount", "freeShapeCount", "findAndSearch", "newAndRemove", "labelQueries",
    ],
    "DocumentExplorerTests": [
        "exploreDocumentWithShape", "explorerShapeAtIndex", "explorerPathId", "findShapeFromPathId",
    ],
    "XCAFDocShapeMapToolTests": ["setShapeAndQuery"],
    "TNamingExtensionTests": [
        "namingIsEmpty", "namingIsEmptyAfterRecord", "namingVersion", "namingOriginalShape",
        "namingOriginalShapeFromModify", "namingHasLabel", "namingFindLabel", "namingValidUntil",
        "sameShapeCount", "sameShapeQueriesOnADocumentWithNoNaming", "sameShapeLabels",
    ],
    "TNamingBasicTests": [
        "createLabel", "createChildLabel", "recordPrimitive", "currentShapeAfterPrimitive",
        "storedShape", "evolutionType", "noEvolutionOnEmptyLabel", "historyAfterPrimitive",
        "newShapeFromHistory", "modifyEvolution", "deleteEvolution", "generatedEvolution",
        "secondRecordReplacesHistory",
    ],
    "DirectoryTests": ["createDirectory", "findDirectory", "addSubDirectory", "makeObjectLabel"],
    "IDFilterTests": ["createFilter", "keepMode", "keepGUID", "ignoreGUID", "toggleIgnoreAll"],
    "XDEEditorTests": [
        "editorExpand", "editorExpandRefusals", "rescaleGeometry", "rescaleGeometryRefusals",
    ],
    "TNamingSelectResolveTests": [
        "selectSubShape", "resolveShape", "resolveWithoutSelection", "selectForeignFace",
        "selectedEvolution",
    ],
    "DocumentExplorerExtensionTests": ["explorerDepth", "explorerDepthUnderAnAssemblyIsOne"],
    "XCAFDocAssemblyIteratorTests": ["iterateAssembly", "smallAssemblyCountIsComplete"],
}

# display name -> func name, for the tests whose @Test carries a title
DISPLAY = {}

INJECTIONS = list(range(1, 47))
SKIP = {26, 33, 34}  # never wired; see the report

# Swift Testing prints both forms. Match both, or do not scrape at all.
FAIL_FUNC = re.compile(r"Test (\w+)\(\) (?:recorded an issue|failed)")
FAIL_NAME = re.compile(r'Test "([^"]+)" (?:recorded an issue|failed)')
PASS_FUNC = re.compile(r"Test (\w+)\(\) passed")
PASS_NAME = re.compile(r'Test "([^"]+)" passed')


def run(inject):
    env = dict(os.environ)
    env.pop("OCCTSWIFT_BRIDGE_PREBUILT", None)
    if inject:
        env["OCCT766_INJECT"] = str(inject)
    else:
        env.pop("OCCT766_INJECT", None)
    p = subprocess.run(
        ["swift", "test", "--filter", FILTER, "--no-parallel"],
        capture_output=True, text=True, env=env, cwd=str(ROOT), timeout=1800,
    )
    out = p.stdout + p.stderr
    failed = set(FAIL_FUNC.findall(out)) | set(FAIL_NAME.findall(out))
    passed = set(PASS_FUNC.findall(out)) | set(PASS_NAME.findall(out))
    crashed = "Abort ***" in out or "SIGSEGV" in out
    return failed, passed, crashed, out


def main():
    baseline_failed, baseline_passed, baseline_crash, out = run(0)
    print(f"BASELINE: {len(baseline_passed)} seen passing, {len(baseline_failed)} failing, "
          f"crash={baseline_crash}")
    if baseline_failed or baseline_crash:
        print("baseline is not green, stopping", file=sys.stderr)
        print(out[-3000:], file=sys.stderr)
        sys.exit(1)

    # map display names seen in the baseline back to nothing; we only need the union of names
    covered = set()
    rows = []
    for inj in INJECTIONS:
        if inj in SKIP:
            continue
        failed, passed, crashed, out = run(inj)
        rows.append((inj, sorted(failed), crashed))
        covered |= failed
        flag = "  CRASH" if crashed else ""
        print(f"INJ{inj:<3} reds {len(failed):>2}: {', '.join(sorted(failed)) or '(none)'}{flag}")

    print()
    wanted = {t for v in TOUCHED.values() for t in v}
    print(f"switch count: {len([i for i in INJECTIONS if i not in SKIP])} injections run")
    print(f"test count:   {len(wanted)} touched tests")
    uncovered = sorted(wanted - covered)
    print(f"covered:      {len(wanted) - len(uncovered)}")
    if uncovered:
        print("UNCOVERED (a test no injection reds is exactly what a blind test looks like):")
        for t in uncovered:
            print("   ", t)
        sys.exit(1)
    print("every touched test is red under at least one injection")


if __name__ == "__main__":
    main()

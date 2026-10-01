#!/usr/bin/env python3
"""Score the #766 XCAF injection matrix: map display names back to func names and
assert every touched test is red under at least one injection."""
import re
import pathlib
import sys

ROOT = pathlib.Path("/Users/elb/Projects/OCCTSwift/.claude/worktrees/agent-ab47633332e4e61a9")
TESTS = ROOT / "Tests/OCCTXCAFTests"
SWEEP = pathlib.Path(
    "/private/tmp/claude-501/-Users-elb-Projects-OCCTSwift/"
    "7ca7a65c-aee4-4ed2-ac7a-0732e49711a4/scratchpad/xcaf-weak-sweep-out.txt"
)

FILES = [
    "TNamingTracingTests.swift", "XDEShapeToolQueryTests.swift", "DocumentExplorerTests.swift",
    "XCAFDocShapeMapToolTests.swift", "TNamingExtensionTests.swift", "TNamingBasicTests.swift",
    "IDFilterTests.swift", "XDEEditorTests.swift", "TNamingSelectResolveTests.swift",
    "DocumentExplorerExtensionTests.swift", "XCAFDocAssemblyIteratorTests.swift",
    "DirectoryTests.swift",
]

TOUCHED = {
    "TNamingTracingTests.swift": [
        "traceForward", "traceBackward", "multipleGenerations", "emptyTraceForUnrelated",
        "traceModificationChain", "forwardTraceExcludesSource", "backwardTraceExcludesGenerated"],
    "XDEShapeToolQueryTests.swift": [
        "addShapeAndCount", "freeShapeCount", "findAndSearch", "newAndRemove", "labelQueries"],
    "DocumentExplorerTests.swift": [
        "exploreDocumentWithShape", "explorerShapeAtIndex", "explorerPathId",
        "findShapeFromPathId"],
    "XCAFDocShapeMapToolTests.swift": ["setShapeAndQuery"],
    "TNamingExtensionTests.swift": [
        "namingIsEmpty", "namingIsEmptyAfterRecord", "namingVersion", "namingOriginalShape",
        "namingOriginalShapeFromModify", "namingHasLabel", "namingFindLabel", "namingValidUntil",
        "sameShapeCount", "sameShapeQueriesOnADocumentWithNoNaming", "sameShapeLabels"],
    "TNamingBasicTests.swift": [
        "createLabel", "createChildLabel", "recordPrimitive", "currentShapeAfterPrimitive",
        "storedShape", "evolutionType", "noEvolutionOnEmptyLabel", "historyAfterPrimitive",
        "newShapeFromHistory", "modifyEvolution", "deleteEvolution", "generatedEvolution",
        "secondRecordReplacesHistory"],
    "DirectoryTests.swift": [
        "createDirectory", "findDirectory", "addSubDirectory", "makeObjectLabel"],
    "IDFilterTests.swift": [
        "createFilter", "keepMode", "keepGUID", "ignoreGUID", "toggleIgnoreAll"],
    "XDEEditorTests.swift": [
        "editorExpand", "editorExpandRefusals", "rescaleGeometry", "rescaleGeometryRefusals"],
    "TNamingSelectResolveTests.swift": [
        "selectSubShape", "resolveShape", "resolveWithoutSelection", "selectForeignFace",
        "selectedEvolution"],
    "DocumentExplorerExtensionTests.swift": ["explorerDepth", "explorerDepthUnderAnAssemblyIsOne"],
    "XCAFDocAssemblyIteratorTests.swift": ["iterateAssembly", "smallAssemblyCountIsComplete"],
}

# display name -> func name, read out of the sources so nothing is hand-maintained
display = {}
for f in FILES:
    text = (TESTS / f).read_text()
    for m in re.finditer(r'@Test\("([^"]+)"\)\s*\n?\s*func\s+(\w+)\s*\(', text):
        display[m.group(1)] = m.group(2)
    for m in re.finditer(r'@Test\("([^"]+)"\)\s+func\s+(\w+)\s*\(', text):
        display[m.group(1)] = m.group(2)

wanted = {t for v in TOUCHED.values() for t in v}
covered = {}
rows = []
for line in SWEEP.read_text().splitlines():
    m = re.match(r"INJ(\d+)\s+reds\s+(\d+): (.*)", line)
    if not m:
        continue
    inj = int(m.group(1))
    names = [] if m.group(3) == "(none)" else [s.strip() for s in m.group(3).split(", ")]
    # a display name may itself contain ", "; re-glue by checking membership
    resolved, buf = [], ""
    for part in names:
        cand = (buf + ", " + part) if buf else part
        if cand in display or cand in wanted:
            resolved.append(display.get(cand, cand))
            buf = ""
        else:
            buf = cand
    if buf:
        resolved.append(display.get(buf, buf))
    rows.append((inj, resolved))
    for r in resolved:
        covered.setdefault(r, []).append(inj)

print(f"{len(rows)} injections scored")
unknown = sorted(set(sum((r for _, r in rows), [])) - wanted)
if unknown:
    print("UNRESOLVED names (display map missed them):")
    for u in unknown:
        print("   ", u)
print()
for inj, names in rows:
    print(f"INJ{inj:<3} -> {', '.join(sorted(names)) or '(none)'}")
print()
uncovered = sorted(wanted - set(covered))
print(f"touched tests: {len(wanted)}   covered: {len(wanted) - len(uncovered)}")
if uncovered:
    print("UNCOVERED:")
    for t in uncovered:
        print("   ", t)
    sys.exit(1)
print("every touched test is red under at least one injection")

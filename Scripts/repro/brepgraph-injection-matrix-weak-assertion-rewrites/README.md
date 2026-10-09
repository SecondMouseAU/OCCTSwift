# BRepGraph weak-assertion lift: the injection matrix

Evidence for the PR that lifted 23 OCCTBRepGraphTests files off `v5.0.0-766-execution` (six source
PRs, each file at its area-directory path). Measured against the pinned kernel `v4.0.0-kernel.5`;
re-derive rather than quote.

| file | what it is |
|---|---|
| `generate-shadow.py` | reads the C declarations of the `OCCTBRepGraph*` bridge entry points the BRepGraph Swift wrappers call and writes a module-local Swift shadow of each (same name and signature), calling the real function and distorting its answer when `BGI_SWITCH` names a switch |
| `switches.txt` | the 559 switches the generator derived (a Bool verdict inverted, a reference dropped, a scalar offset or negated, a count off by one or zeroed or short by one, one out parameter or struct field offset or negated, a Double input offset, a Bool input inverted) |
| `run-injection-matrix.py` | runs the built `OCCTBRepGraphTests` bundle per switch through `swiftpm-testing-helper`, writes `matrix-LABEL.json`, derives the changed-test set from `git diff origin/main` and reports both directions |
| `matrix-before.json` | the switches against `origin/main`'s versions of the lifted files |
| `matrix-after.json` | against the lifted ones |

Running it: `python3 generate-shadow.py --out Sources/OCCTSwift/InjectionShadow.swift --switches
switches.txt` from the repo root (the output is never committed; `.git/info/exclude` hides it),
`swift build --product OCCTBRepGraphTests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, run the script
with label `after`. For `before`: `git checkout origin/main -- <the modified lifted files>`, rebuild,
run with label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c BGI_SWITCH` to read 0.

`OCCTBRepGraphHistoryGetRecordInfo` is not shadowed: `Issue1078HistoryRecordOpNameLengthTests` calls
it directly, and a module-local copy makes that call ambiguous.

## Result

| | tests changed vs `main` | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|---|
| `main`'s versions | 64 | 56 | 107 of 559 |
| lifted | 64 | 64 | 188 of 559 |

Every switch was run; the baseline (no switch) was green on both sides. On `main`'s versions the 8
tests no switch reddens are `BRepGraphCoEdgeQueryTests.coedgeSeamPairForSphere`,
`BRepGraphEdgeSamplingTests.sampleEdgeWithoutCurve` and `sampleZeroCount`,
`BRepGraphFaceGeometryTests.faceHasTriangulation` and `faceNaturalRestriction`,
`BRepGraphFaceQueryTests.outerWire`, `BRepGraphPolyCountTests.polyCounts` and
`BRepGraphRefEntryTests.refOrientation`. After: none.

Crashes are named as crashes and are not counted as red rows: before,
`OCCTBRepGraphSampleEdgeCurve_RET_PLUS1`, `OCCTBRepGraphShellSolidCount_RET_MINUS1`,
`OCCTBRepGraphShellSolidCount_RET_ZERO`; after, those three plus `OCCTBRepGraphNbEdges_RET_PLUS1`
(the lifted tests index by the reported count, so an inflated count reads past the buffer instead of
failing an expectation).

The switches are generic distortions of a function's answer, not a hand-picked list per test, so
the number that redden nothing is large by construction. The figure that matters is the second
column: a changed test no switch can redden pins nothing the bridge produced.

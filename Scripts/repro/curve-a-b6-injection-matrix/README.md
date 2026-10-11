# OCCTCurveTests batch 6, curve-a: the injection matrix

Evidence for the PR that lifted 7 test files off `v5.0.0-766-execution` (source PRs #2642, #2434, #2556,
#2648, #2637, #2598, #2601). Measured against the pinned kernel `v4.0.0-kernel.6`; re-derive rather than
quote. Same harness as `curve-b3-bezier-bspline-injection-matrix` (see its README for what each script
does and how to run it), scoped to this PR: `files.txt` lists the 7 test files, `reachable-funcs.py`
derives the bridge entry points they reach (`funcs.txt`, 119 names, 113 shadowed) and
`generate-shadow.py` writes the switches (`switches.txt`, 552). Skipped as unmappable by the generator:
`OCCTCurve3DJoinCurves` and four others, so `CurveJoinTests` is reddened only through the point and
domain accessors it reads back.

## Result

33 tests changed against `main` (35 in the seven suites; two are unchanged).

| | changed tests reddened by some switch | switches that redden a changed test |
|---|---|---|
| `main`'s versions | 25 of 33 | 40 of 552 |
| lifted | **33** of 33 | 97 of 552 |

On `main`'s versions these changed tests catch nothing: Adaptor3dIsoCurveTests.uIsoOnCylinder,
vIsoOnCylinder; CurveJoinTests.joinSingleCurve, joinThreeSegments, joinTwoSegments;
Issue506ArcLengthBridgeContractTests.everySpellingAgreesOnDivergentRanges, reversedRangeMeasuresTheSpan;
Issue600OutOfDomainRangeTests.ellipseWinds. After the lift: none. Every baseline (no switch) was green on
both sides. A crash (exit < 0 or > 1) is named, not counted as a red row: 5 after
(`OCCTCurve2DGetDomain_last_NEG`, `OCCTCurve3DGetDomain_last_NEG`, `OCCTCurve3DGetPoleCount_RET_MINUS1`,
`OCCTCurve3DGetPoles_RET_PLUS1`, `OCCTEdgeAdaptorDomain_last_NEG`), 10 before (the extra five are
`RET_NIL`/`RET_ZERO`/`RET_MINUS1` rows that hit a force-unwrap or a fixed index in `main`'s versions).
The shadow was deleted and the bundle rebuilt: `strings <bundle> | grep -c CRV_SWITCH` reads 0.

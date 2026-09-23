# Phase 3: OCCTThreadTests Red→Green record (#1990)

Every row below was run: injection applied, `swift test --filter` captured red, injection reverted,
captured green. The previous version of this file (12 rows, PR #2022) was removed: the #1990 audit
found every row a stub, three of its Red claims impossible given the code, and its parity values
copied from bridge to kernel. Sections are one per PR.

## Thread::Issue193-222 (PR #TBD, files: Issue193LongThreadTests.swift, Issue196PolyHLRTests.swift, Issue213VProfileTests.swift, Issue219SmoothInternalTests.swift, Issue222EnvelopeTests.swift)

Injections are the named entries of the PR body's injection table; every one was applied with `Sources/` otherwise clean and reverted with `git checkout -- Sources` before the green run.

| Test (Suite::func) | Code under test | Injection | Red (failing line) | Green | Parity |
|---|---|---|---|---|---|
| Issue #193, long full-length threads return a usable solid (not nil) :: M10x1.0 long threads stay in-envelope and remove material (never nil) | `threadedShaft` direct build | `balloon` | `Issue193LongThreadTests.swift:38` `c.max.x <= b.max.x + tol` (and :39, :45 `vt < vb`), all 3 lengths | passed | PASS: e.g. length 26: volume 3689.302 of 3926.991 |
| Issue #193, long full-length threads return a usable solid (not nil) :: Short thread is the smooth analytic helicoid and is valid | `threadedShaft` path selection | `nodirect` | `Issue193LongThreadTests.swift:68` `t.subShapes(ofType: .face).count < 40` | passed | PASS: valid, 9 faces both sides |
| Issue #196, polyhedral HLR for threaded solids (fast 2D drawings) :: poly HLR projects the analytic thread to 2D edges | `hlrPolyEdges` -> `OCCTHLRPolyGetEdgesByCategory` | `hlrnil`: `hlrPolyEdges` returns nil | `Issue196PolyHLRTests.swift:33` `edges != nil` | passed | PASS: 1741 edges both sides (deflection 0.1) |
| Issue #196, polyhedral HLR for threaded solids (fast 2D drawings) :: deflection is honoured, coarser mesh yields fewer drawing edges | `hlrPolyEdges` deflection argument | `hlrdefl`: `hlrPolyEdges` passes 0.1 whatever the caller asks | `Issue196PolyHLRTests.swift:60` `coarse != fine` | passed | PASS: 0.05: 1873 in-process, 1869 from BREP on both sides; 0.8: 2089 both |
| Issue #213, ISO-68 V-thread profile :: threadedShaft removes a V-groove's worth of material, not a square slot's | `threadedShaft` direct build | `balloon` (adds material instead of cutting) | `Issue213VProfileTests.swift:40` `removed > 0.08` | passed | PASS: removed fraction 0.1365 (1356.44 of 1570.80) |
| Issue #213, ISO-68 V-thread profile :: the cutter cross-section spec yields 30° flanks (the geometric core of #213) | `ThreadSpec.halfFlankAngle` | `flank`: `halfFlankAngle` = pi/7.2 (25 degrees) | `Issue213VProfileTests.swift:53` `abs(flank - 30.0) < 0.01` | passed | N/A: N/A |
| Issue #219, smooth fine-pitch internal thread :: 3/8-16 UNC internal thread cuts smooth (few faces), not faceted | `threadedHole` smooth internal cut | `nosmoothinternal`: `smoothInternalCut` never attempted (the #219 regression) | `Issue219SmoothInternalTests.swift:40` `faces < 40` | passed | PASS: 15 faces, valid, both sides |
| Issue #219, smooth fine-pitch internal thread :: the smooth internal cut still removes a thread's worth of material | `threadedHole` cut path | `cutnil` | `Issue219SmoothInternalTests.swift:63` `#expect(Bool(false))` (threadedHole nil) | passed | PASS: 1268.520 of 1378.790 |
| Issue #222, coarse-pitch thread crest is in-envelope (tight measure) :: Direct build keeps the crest within the nominal major radius (iso68, coarse) | `threadedShaft(build: .direct)` | `balloon` | `Issue222EnvelopeTests.swift:39` `r <= 6.0 * 1.005` (optimal) and `:42` (mesh), `:45` `v1 < v0` | passed | PASS: optimal crest 6.0000070, mesh crest 6.0000072. Under `nodirect` it stays green: nothing in the test detects that the direct build was not used |
| Issue #222, coarse-pitch thread crest is in-envelope (tight measure) :: Direct build keeps the crest within the nominal major radius (Tr trapezoidal, coarse) | `threadedShaft(build: .direct)` | `balloon` | `Issue222EnvelopeTests.swift:66` `r <= 6.0 * 1.005` (and :69) | passed | PASS: optimal crest 6.0000066, mesh crest 6.0000067 |
| Issue #222, coarse-pitch thread crest is in-envelope (tight measure) :: default `.auto` still builds a valid single-start rod (no regression) | `threadedShaft(.auto)` | `shaftnil`: `threadedShaft` returns nil | `Issue222EnvelopeTests.swift:86` `#expect(Bool(false), "auto build returned nil")` | passed | PASS: valid, volume 1302.85 both sides |

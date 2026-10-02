# #2926 and #2929: what the probes measured

Both issues named one decisive measurement and both measurements came back against the readings
the issues proposed. Run under Node 26.10.0 with `@bjorn3/browser_wasi_shim@0.4.2`, the runtime the
suites use since #2894, against the same kernel and toolchain as the Apple column.

## #2929: `OCCTDiagnostics.capturing` is necessary and sufficient on wasm

| variant, differing only in what runs before or around the mutation | wasm | Apple |
|---|---|---|
| A, the failing test's exact shape: set the flag, read `isValid` | `true` WRONG | `false` |
| B, `isValid` called once first | `true` WRONG | `false` |
| C, the flag read once first | `true` WRONG | `false` |
| E, both of those first | `true` WRONG | `false` |
| **D, the setter inside `OCCTDiagnostics.capturing`** | **`false` RIGHT** | `false` |

`records=0` in D, so the capture collected nothing. Wrapping the call is what makes the mutation
visible, not anything the capture observes.

**Both of the issue's candidate causes are therefore wrong.** The flag write reaches the shared
`TShape`, since D proves it lands and a fresh `box.edges()` walk reads it back as cleared. And
`BRepCheck_Analyzer` does fault the mismatch, since D reports invalid. Neither is platform-broken.

**The mechanism is NOT established, and is deliberately not named here.** What is established is
that one unrelated pair of bridge calls around the mutation changes a kernel result on wasm and
changes nothing on Apple. Candidates, in the order worth testing:

1. Release-mode codegen. These runners are `Release-webassembly-wasm32`; the Apple column is debug.
   **Run variant A under a debug wasm build before anything else**, because it separates
   optimisation from platform in one step and no probe here has done it.
2. ARC lifetime. Without the closure the `edges` array's last use is the setter call, so the `Edge`
   and its `OCCTEdgeRef` may be released earlier relative to the `isValid` read.
3. Reordering of the two opaque bridge calls, which should not be legal, and so is the least likely.

**It is almost certainly not a kernel patch.** No change to OCCT source is implicated by a result
that an unrelated bridge call around the same kernel call repairs.

## #2926: the tolerance IS live on wasm, and saturates earlier than on Apple

Max delta of a 25-point surface fingerprint against the `tol=100.0` surface:

| tolerance | Apple | wasm |
|---|---|---|
| 10.0 | 65013.50 | 99380.41 |
| 1.0 | 65013.50 | 162726.43 |
| 0.1 | 65013.50 | 162726.43 |
| 1e-3 | 128984.45 | 162726.43 |
| 1e-12 | 128984.45 | 162726.43 |

Three distinct regimes on Apple (`100` alone, `{10, 1, 0.1}`, `{1e-3, 1e-12}`) and three on wasm
(`100`, `10`, everything from `1.0` down). The parameter reaches the computation on both platforms.

**So #2926 is a test-fixture matter, not a defect, and an earlier claim of mine that the tolerance
is inert on wasm was wrong.** `Issue999NLPlateParameters."Varying the tolerance changes the G3
result"` compares `1e-1` against `1e-3`. On Apple those straddle a regime boundary; on wasm both sit
inside the saturated regime that starts at `1.0`, so the surfaces are identical and the delta is
exactly 0.0. The test asserts a difference that this platform's saturation point removes.

The tolerance is never passed to the plate solve. `OCCTSurfaceNLPlateG3` calls
`solver.Solve2(3, 1)` with constants and forwards the tolerance to `occtNLPlateFitSolved`, where it
reaches `approx.Init(poles, 3, 8, GeomAbs_C2, tolerance)`. It is the degree-3-to-8 C2 approximation
of the solved plate that saturates, which is why tightening past the saturation point changes
nothing on either platform.

A fix picks a pair that straddles a boundary on both platforms, `100.0` against `1e-3` by this
table, rather than widening a tolerance on the assertion.

## A separate weakness in #999's test, independent of wasm

It asserts only that two tolerances DIFFER, never that either answer is sane. A delta of 162,726 on
a plane whose three constraints target z of +1, -1 and +2 means at least one regime is a diverging
fit that the test accepts as proof the parameter is live. Filed separately.

## Reproducing

```
Scripts/fetch-occt-wasm.sh
./Scripts/run-wasm-tests.sh build
./Scripts/run-wasm-tests.sh run OCCTTopologyTests OCCTSurfaceTests
grep -rhE 'PROBE2929|PROBE2926' <the transcript directory>
```

The probes are `Tests/OCCTTopologyTests/Probe2929SameParameterTests.swift` and
`Tests/OCCTSurfaceTests/Probe2926ToleranceTests.swift`, both marked PROBE and both to be deleted
once the two issues are resolved.

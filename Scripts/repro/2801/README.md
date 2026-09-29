# #2801: what `No_Exception` removes from the kernel we ship

The rule these measurements support is
[`okf/policies/occt-validation-is-compiled-out.md`](../../../okf/policies/occt-validation-is-compiled-out.md).
Everything here is reproducible against the pinned asset; no kernel rebuild is involved.

## `probe.mm`, `run.sh`: does the check fire

Builds the same file twice, once as SwiftPM compiles `Sources/OCCTBridge/src/*.mm` and once with
`-DNo_Exception`, which is how every OCCT translation unit was compiled.

```bash
OCCT_XCFRAMEWORK=/path/to/OCCT.xcframework bash Scripts/repro/2801/run.sh
```

Measured 2026-09-29 against `v4.0.0-kernel.2`:

| case | without the define (the bridge) | with it (the kernel) |
|---|---|---|
| `gp_Dir(0, 0, 0)`, check inline in `gp_Dir.hxx` | **throws** `Standard_ConstructionError` | no throw |
| `Geom_Direction(0, 0, 0)`, check in `Geom_Direction.cxx` | no throw, `X()` is `nan` | same |
| `gp_Ax2(P, Dz, Dz)`, N parallel to Vx | no throw | same |
| `BRepPrimAPI_MakeHalfSpace::Solid()` when not done | no throw, null `TopoDS_Solid` | same |
| `GC_MakeSegment2d::Value()` on coincident points | no throw, null `Handle` | same |

Row one is the mechanism: the same source, the same compiler, one define apart. Row three is the
part the raw counts do not state, and the reason "the check is inline" is not enough on its own:
`gp_Ax2` reaches `gp_Dir`'s inline check from inside `gp_Ax2.cxx`, where the define was on, so the
documented `ConstructionError` cannot happen in either build. Rows four and five are
`StdFail_NotDone`, the largest class of compiled-out check, and row four is #2831.

## `bench.mm`, `run-bench.sh`: what one check costs

The out-of-line checks cannot be timed without rebuilding the kernel. The inline ones can, out of
the same source with and without the define, which bounds the per-check cost. `-O2`, three
interleaved runs, medians on one laptop 2026-09-29:

| body | check compiled in | check removed |
|---|---|---|
| `gp_Vec::Normalized()` | 1.60 ns/op | 1.29 ns/op |
| `gp_Dir(x, y, z)` | 1.70 ns/op | 1.57 ns/op |
| `gp_Dir::Coord(index)` | 1.19 ns/op | 1.18 ns/op |

Read it as a tenth of a nanosecond per check, visible as 10% to 20% on a body that does almost
nothing else and invisible on an index test. **It says nothing about how many checks a real workload
executes**, which is the number that would decide
`BUILD_RELEASE_DISABLE_EXCEPTIONS`, and which needs the kernel built both ways. Nor does it measure
libOCCT: these are the checks that ARE in the binary, used as a stand-in for the ones that are not. The spread between
runs of the same binary is comparable to the effect on the constructor row, so that row is the weak
one; `Normalized()` is consistent across all three runs.

## `removal-matrix.sh`: proving the census is not blind

Removes each rule in `Scripts/census-compiled-out-validation.py` in turn and checks the self-test
loses a case, per [`prove-the-test-fails`](../../../okf/policies/prove-the-test-fails.md). It found
three of its own fixtures decorative on the first run, all three because they restated the logic
rather than calling it.

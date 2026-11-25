# OCCTSwift#3522 ground truth: `BRepFilletAPI_MakeChamfer::NbSurf(IC)` on a contour with no surface data

`ChamferBuilder.simulatedSurfaceCount(contour:)` faulted the process on a builder that holds a contour
and was never built or simulated, and on any builder after `Reset()`. The cause, the states and the
fillet's fix are in `Scripts/repro/3519/`; this directory is the chamfer half, and the answer to the
question #3519 left open: is there a predicate for "this contour holds surface data" that does not
need a kernel change?

`occt_3522_chamfer_surfdata_matrix.mm` runs every `(builder state, contour)` pair in its own forked
child, so a SIGSEGV is a recorded cell and not the end of the probe. `probe-output.txt` is its output
on the pinned kernel (OCCT V8_0_2 plus the carried patches, `macos-arm64`). It exits non-zero when the
bridge's answer would fault, or would differ from `NbSurf` where `NbSurf` answers for a real contour.

## Compile and run

```bash
XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3522/occt_3522_chamfer_surfdata_matrix.mm -o /tmp/occt_3522
/tmp/occt_3522 > Scripts/repro/3522/probe-output.txt; echo "exit $?"
```

## The predicate

`ChFi3d_ChBuilder::NbSurf(IC)` (`ChFi3d_ChBuilder.cxx:626-638`) is `stripe->SetOfSurfData()->Length()`
with no null test. `ChFi3d_Builder::NbComputedSurfaces(IC)` (`ChFi3d_Builder_1.cxx:438-467`) reads the
same length behind `if (hd.IsNull()) return 0;`, and it is a public member of the base class
`ChFi3d_ChBuilder` inherits, so it is the null test OCCT ships. `BRepFilletAPI_MakeFillet` forwards it
and `BRepFilletAPI_MakeChamfer` does not, and keeps its `ChFi3d_ChBuilder` in a private field
`myBuilder`. The #3522 issue read that as "unguardable from the bridge".

C++ has one construct that may name a private member outside its class: the argument of an explicit
instantiation. The probe uses it to take a pointer to `BRepFilletAPI_MakeChamfer::myBuilder` and calls
`NbComputedSurfaces` on the result, which is what the bridge does. It is standard C++ and not a macro
over `private`, it changes no layout, and a rename of the field upstream is a compile error.

## Why not a flag kept beside the builder

Whether a stripe holds a sequence depends on `Build`, `Simulate`, `Reset`, `Add` and `Remove`
together, and the matrix has two states that a flag per contour gets wrong:

| state | what a flag says | what OCCT holds |
|---|---|---|
| `Build()` completed, then a second edge added | "built", so contour 2 holds data | contour 2 is a new stripe: `NbSurf(2)` SIGSEGV |
| two contours built, the first removed | contour 2 is now contour 1 | the stripe kept its data under the new number: `NbSurf(1)` is 1 |

The first is the more telling: a flag has to learn about `Add`, and then about `Remove`'s renumbering,
and then about every declined build, which is the lifecycle of the stripe list written a second time.

## Measured

Every state in `probe-output.txt`, contour 1 unless a row says otherwise. `predicate` is
`NbComputedSurfaces(IC)` through the opened member.

| state | `NbSurf` | `predicate` | bridge |
|---|---|---|---|
| fresh, no contour | 0 | 0 | 0 |
| edge added, never built or simulated | SIGSEGV | 0 | 0 |
| `Simulate(1)` (control) | 1 | 1 | 1 |
| `Simulate(1)`, `Reset()` | SIGSEGV | 0 | 0 |
| `Simulate(1)`, `Reset()`, `Simulate(1)` | 1 | 1 | 1 |
| built ok | 1 | 1 | 1 |
| built ok, `Reset()` | SIGSEGV | 0 | 0 |
| `Simulate(1)`, `Build()`; `Build()`, `Simulate(1)` | 1 | 1 | 1 |
| declined build; declined `Simulate(1)` | 0 | 0 | 0 |
| `Build()` with no contour | 0 | 0 | 0 |
| two contours, only `Simulate(1)`: contour 1; contour 2 | 1; SIGSEGV | 1; 0 | 1; 0 |
| two contours, nothing run: contours 1 and 2 | SIGSEGV; SIGSEGV | 0; 0 | 0; 0 |
| built ok, then a second edge added: contour 1; contour 2 | 1; SIGSEGV | 1; 0 | 1; 0 |
| two built, the first removed: contour 1 | 1 | 1 | 1 |
| three edges at a vertex, built: contours 1 to 3; **IC 4** | 1 each; **1** | 1 each; **0** | 1 each; **0** |

The predicate equals `NbSurf` in every state where `NbSurf` answers for a contour in
`1..NbContours()`, and is 0 in every state where it faults: no mismatch in 85 cells.

The one answer that changes is the last row's fourth index. Three chamfers meeting at a vertex leave a
fourth stripe in the list, a corner stripe with no spine, and `NbSurf(4)` reads it as a contour and
answers `1` where `NbContours()` is 3. `contourCount` is 3, so `4` names no contour, and the bridge
answers `0` for it, as it does for every index outside `1...contourCount`.

## The fillet side, checked in the same states

`FilletBuilder.simulatedSurfaceCount` reads `NbComputedSurfaces(IC)` first (#3519), so it has the same
answers by construction: a contour added after a build and a corner stripe both read 0, and the new
test suite pins both.

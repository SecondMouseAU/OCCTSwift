# OCCTSwift#491 measurements — the two `GeomConvert_Approx*` wrappers per type

The evidence behind #491's two decisions. Not crash reproducers: both programs exit cleanly and print
a table. They exist because the audit finding for #491 described one divergence that turns out to be
unreachable and one that is real but had no obvious "correct" resolution, and both conclusions rest
on measurement rather than on reading the headers.

Compile either with the standard ground-truth invocation from `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/491-approx-wrapper-drift/occt_491_precis_code_sweep.mm -o /tmp/occt_491_precis
/tmp/occt_491_precis
```

## 1. `occt_491_isdone_vs_hasresult.mm` — the divergence that does not reproduce

`GeomConvert_ApproxCurve.hxx` documents its two completion accessors as different questions:

- `IsDone()` — "true if the approximation has been done **within required tolerance**"
- `HasResult()` — "true if the approximation did come out with a result that is **not NECESSARILY**
  within the required tolerance"

`OCCTCurve3DApproximate` gated on the first and `OCCTGeomConvertApproxCurve` on the second, so on
paper the pair disagreed for any completed-but-over-tolerance fit: one returns `nil`, the other
returns the curve.

**They cannot disagree in this kernel.** `GeomConvert_ApproxCurve::Approximate` copies both flags
straight off `AdvApprox_ApproxAFunction` (`GeomConvert_ApproxCurve.cxx:169-170`), and that class sets
them together:

```c++
// AdvApprox_ApproxAFunction.cxx:945-953
if (ErrorCode == 0)      { myDone = true; myHasResult = true; }
else if (ErrorCode == -1) { myHasResult = true; }
```

`ErrorCode == -1` is the only `HasResult`-without-`IsDone` path, and the only assignment that would
produce it is commented out upstream:

```c++
// AdvApprox_ApproxAFunction.cxx:550, inside the "stack is full" branch
//-> If the stack is full...
// for now               ErrorCode=-1;
NumCurves++;
```

With that line dead, `ErrorCode` is only ever `0` (both flags set) or `1` (early return, neither set),
so `IsDone() == HasResult()` for every input. This program confirms it empirically over 10 requests —
including deliberately starved fits, where OCCT reports success against a tolerance it missed by nine
orders of magnitude:

```
  circle r=10, 1 segment deg 3      tol=1e-09  seg=1   deg=3  IsDone=1 HasResult=1 maxError=5.10851
  ellipse 50x1, 1 segment deg 3     tol=1e-09  seg=1   deg=3  IsDone=1 HasResult=1 maxError=24.1927
  offset(ellipse 50x1) tol 1e-12    tol=1e-12  seg=100 deg=8  IsDone=1 HasResult=1 maxError=6.96736
```

So gating on `IsDone()` never rejected an over-tolerance curve — the practical consequence is that
`Curve3D.approximated`'s behaviour is unchanged by #491's move to `HasResult()`. The gate was unified
anyway, on `HasResult()`, because that is what OCCT's own curve-conversion sites use
(`GeomConvert.cxx:345/441`, `GeomToIGES_GeomCurve.cxx:632`, `GeomFill_Profiler.cxx:136`), what both
surface entry points already used, and the only gate under which `approxWithDetails`' `isDone: false`
diagnostic means anything.

Re-run this if that upstream line is ever re-enabled: the parity tests
(`Tests/OCCTCurveTests/Issue491Curve3DApproxParityTests.swift`) are the guard for that day.

## 2. `occt_491_precis_code_sweep.mm` — choosing the shared `PrecisCode`

`GeomConvert_ApproxSurface`'s eighth constructor argument is `PrecisCode`, "the index of precision".
`OCCTSurfaceApproximate` passed `0`, `OCCTGeomConvertApproxSurface` passed `1`, neither with a
comment. It is a genuine algorithm knob: `GeomConvert_ApproxSurface::Approximate` forwards it into
`AdvApp2Var_ApproxAFunc2Var`, which clamps it to `[0, 3]` and passes it to `AdvApp2Var_Context` as
`iprecis`, where `lesparam` (`AdvApp2Var_Context.cxx:22-76`) turns it into the Jacobi degree and the
initial per-axis sample-point count that seed the iterative fit:

```c++
ndgjac = ncflim;                        // icodeo == 0: unchanged
if (icodeo > 0) {
  ndgjac += (9 - (iordre + 1));         // icodeo >= 1: inflate the Jacobi degree
  ndgjac += (icodeo - 1) * 10;
}
// ndgjac then selects nbpnts from a 8/10/20/30/40/50 ladder
```

So the two wrappers seeded a different parameterisation for identical
tolerance/continuity/degree/segment inputs. This program runs both codes over 72 bounded cases — 8
surface families (sphere, torus, trimmed cylinder, trimmed cone, revolved ellipse, offset sphere,
offset torus, bicubic Bezier) x 6 tolerances from `1e-1` to `1e-9`, plus C0/C1 and `maxDegree` 10
variants — and tallies the differences:

```
== tally over 72 cases ==
  result shape (poles/knots/degree) differs : 1
  IsDone differs between the two codes      : 0  (only P0 done: 0, only P1 done: 0)
  smaller maxError with PrecisCode=0        : 64
  smaller maxError with PrecisCode=1        : 8
  identical maxError                        : 0
```

The one layout difference is an offset sphere at tolerance `1e-5`, where both met the tolerance but
`0` did it with fewer poles:

```
offset sphere +1.5  tol=1e-05 | P0 done=1 err=1.79952e-06 27x15 k 5x3 | P1 done=1 err=6.92185e-07 27x23 k 5x5
```

**#491 standardised on `0`.** A caller who states a tolerance wants the lightest surface that meets
it, and `0` was never worse on that criterion. The residual `maxError` differences elsewhere are
sub-1% either way, so this is a tie broken on economy rather than a quality gap.

OCCT itself is split on the value, and splits along the same line. Every live construction of
`GeomConvert_ApproxSurface` in the pinned p1 kernel, each one read rather than counted by filename
(corrected in #573):

| passes `0` | what it does with the result | passes `1` | what it does with the result |
|---|---|---|---|
| `ShapeCustom_BSplineRestriction.cxx:852` (`ConvertSurface`) | accepts on `MaxError() <= myTol3d && IsDone()`; on a miss re-fits at a looser approximation tolerance, a doubled `MaxSeg` or a lower continuity, until the error stops improving | `GeomConvert_1.cxx:786` (`SurfaceToBSplineSurface`, trimmed branch) | takes `Surface()` unconditionally |
| `ShapeConstruct.cxx:265` (`ConvertSurfaceToBSpline`) | accepts on `MaxError() <= Tol3d && IsDone()`; on a miss returns the over-tolerance surface, and drops a continuity only when the fit throws | `GeomConvert_1.cxx:960` (`SurfaceToBSplineSurface`, direct branch) | takes `Surface()` unconditionally |
| | | `ShapeUpgrade_UnifySameDomain.cxx:3629` (`IntUnifyFaces`) | takes `Surface()` unconditionally |
| | | `GeomFill_Sweep.cxx:296` (`BuildAll`) | `HasResult()` only |
| | | `GeomLib.cxx:1517` (`ExtendSurfByLength`) | `HasResult()` only, then falls back to `GeomConvert::SurfaceToBSplineSurface` |
| | | `BRepOffset_Offset.cxx:1626` (`Init`, spherical vertex face) | `IsDone()` only, then falls back to the exact sphere |

The discriminator is the second column, not the tolerance's provenance. Five of the six `1` sites do
convert with their own hardcoded internal tolerance (`1e-4`, `Precision::Confusion()`), but
`BRepOffset_Offset` takes the caller's `TolApp` (`1e-4` by default) and still passes `1`, because it
never checks the fit against it. No `1` site reads `MaxError()` at all. This bridge takes a caller's
tolerance and hands `MaxError()` straight back, so it is in the first group, which is the other half
of the argument for `0`.

**Two mentions are not call sites.** `BRepFill_Sweep.cxx:1162` sits inside a `/* */` block spanning
`:1064` to `:1179`, and `BRepFill_Filling.cxx:712` is a `//`-commented line. Neither is compiled. The
first revision of this table listed `BRepFill_Sweep` as a live `0` site, and `BRepOffset_Offset` was
missing from it entirely; #573 is that correction.
`GeomliteTest_SurfaceCommands.cxx:1044` (Draw's `approxsurf`, which takes `PrecisCode` from the
command line) and `QABugs_19.cxx:244` are harness code, excluded on purpose. `GeomPlate_MakeApprox`
has no `PrecisCode` to census: it drives `AdvApp2Var_ApproxAFunc2Var` directly rather than through
`GeomConvert_ApproxSurface` (#571).

## Note on infinite surfaces

`occt_491_precis_code_sweep.mm` trims the cylinder and cone before approximating, per the project rule
that infinite OCCT surfaces must be trimmed before BSpline conversion. Passing an untrimmed
`Geom_CylindricalSurface` straight in (as `occt_491_isdone_vs_hasresult.mm` deliberately does, to show
what it looks like) yields `maxError` around `1e+84` and a wildly different pole count per
`PrecisCode` — both meaningless. Do not read anything into those rows.

## Sibling finding

Building #491's parity tests surfaced an unrelated upstream defect in the same class, tracked as
[#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522) with its own reproducers in
[`Scripts/repro/522-approx-c0-collapse/`](../522-approx-c0-collapse/): at `GeomAbs_C0`,
`GeomConvert_ApproxSurface` can collapse a parametric direction to degree 1 and still report
`IsDone()` with a `maxError` five orders of magnitude below the surface it returns. It predates #491
and both entry points hit it identically.

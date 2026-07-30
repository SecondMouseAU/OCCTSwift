# OCCTSwift#501 reproducer: GCPnts arc-length samplers overflow the caller's buffer

Standalone reproducer for the heap write past the end of a caller-supplied buffer in four bridge
functions that discretize a curve by arc length. Found while resolving #501's orphaned duplicate:
the two spellings of quasi-uniform curve sampling disagreed about whether the output buffer needed a
bound, and measuring which one was right showed that the one actually in service was wrong.

## Root cause

`GCPnts_UniformAbscissa::initialize` sizes its own parameter array at `theNbPoints + 5`:

```cpp
const int aSize = theNbPoints + 5;
myParams = new NCollection_HArray1<double>(1, aSize);
```

and both fill helpers walk until they reach the end parameter *or* run out of array
(`isNotDone = ... && (anIndex + 1 <= theParameters.Length())`), so `NbPoints()` is bounded by
`nbPoints + 5`, not by `nbPoints`. `GCPnts_QuasiUniformAbscissa` inherits this for every curve that
is neither Bezier nor BSpline, because it forwards to `GCPnts_UniformAbscissa` for those; only its
Bezier/BSpline branch sets `myNbPoints = theNbPoints` outright.

Four bridge functions were handed a buffer sized from the count the caller asked for and then filled
it with `NbPoints()` values:

| bridge function | buffer the caller allocates | Swift entry point |
|---|---|---|
| `OCCTCurve3DQuasiUniformAbscissa` | `count` doubles | `Curve3D.quasiUniformParameters(count:)` |
| `OCCTCurve3DDrawUniform` | `pointCount * 3` doubles | `Curve3D.drawUniform(pointCount:)` |
| `OCCTCurve2DDrawUniform` | `pointCount * 2` doubles | `Curve2D.drawUniform(pointCount:)` |
| `sampleAdaptorUniform` | `count * 3` doubles | `CompCurve`/`EdgeCurve` `sampleUniform(count:)` |

## Triggering geometry

The overshoot is a rounding effect, so it needs a curve whose arc-length walk lands outside the
sampler's epsilon of the end parameter. An **ellipse with major radius 1e6 and minor radius 1e-3**
does it: the walk stops ~1.6e-8 in parameter short of `2*pi`, against an epsilon of
`Resolution(1e-7)` which is about 1e-13 there, so the sampler takes one more step and snaps it to
the end. 22 of the first 59 point counts overshoot by exactly one.

Well-conditioned geometry does not reproduce it. A line, a circle at any radius from 1e-6 to 1e7, a
5 x 2 ellipse, a hyperbola, a parabola, a 4-pole Bezier, a 2-pole Bezier, an 8-point BSpline fit, a
40-point BSpline with uneven knots, a rational Bezier with weights from 1e-3 to 1e4, an offset of a
circle, an offset of a BSpline and a trimmed circle were all measured across counts 2..200: zero
excess. Which is why this survived from v0.31.0.

## What the caller sees

Not the same thing at every entry point, which is worth knowing when reading old bug reports:

- `Curve3D.drawUniform(pointCount:)` and `Curve2D.drawUniform(pointCount:)` **trap**. Their wrappers
  unpack the buffer by index using the count the bridge returned, so `pointCount + 1` reads past the
  end of the Swift `Array` and hits its bounds check: `Fatal error: Index out of range`. Confirmed
  by running the new tests against the unfixed bridge: the test process dies at
  `ContiguousArrayBuffer.swift:692`.
- `Curve3D.quasiUniformParameters(count:)` is silent. It returns `Array(params.prefix(n))`, and
  `prefix` clamps to the array's own count, so the surplus never surfaces. Only the heap write
  does.
- `Edge.quasiUniformParameters(count:)` is silent and wrong: it clamps in the bridge, so it is
  memory-safe, but it drops the end of the edge (below).

## Clamping alone is not the fix

The surplus point *is* the end of the curve: the walk's final step always sets the end parameter.
Truncating the tail therefore leaves the distribution stopping short of the curve:

```
curve parameter range: [0, 6.2831853071795862]
returned 5 params: 0  1.9106332362490186  4.3725520709305679  6.2831852916099189  6.2831853071795862
                                                              ^ what a count-clamped caller sees
                                                                as its last parameter, 1.56e-08
                                                                short of the end
```

`OCCTGCPntsQuasiUniform` was the one member of the family that already clamped, and it had exactly
this defect, silently, for every overshooting call. The fix keeps the first `capacity - 1` samples
and the sampler's own last one, via `occtSamplerKept` / `occtSamplerIndex` in
`Sources/OCCTBridge/src/OCCTBridge_Internal.h`.

## The degenerate-count SIGSEGV next door

Both samplers document `nbPoints >= 2` and enforce it with `Standard_ConstructionError_Raise_if`,
which the pinned Release kernel compiles out (`No_Exception`, see #487). Measured with
`nbPoints == 0`:

| curve | `GCPnts_QuasiUniformAbscissa` | `GCPnts_UniformAbscissa` |
|---|---|---|
| line, circle | `IsDone()`, 1 point | `IsDone()`, 1 point |
| ellipse | `IsDone()`, **5 points** | `IsDone()`, 5 points |
| 4-pole Bezier | **SIGSEGV** | `IsDone()`, 5 points |
| all-coincident-pole Bezier | **SIGSEGV** | not done |
| 8-point BSpline fit | **SIGSEGV** | `IsDone()`, 5 points |

The crash is the Bezier/BSpline branch building `new NCollection_HArray1<double>(1, 0)`, an empty
range, and then calling `SetValue(1, theU1)` on it. That bounds check is a `Raise_if` too, so it is
also compiled out, and the store lands out of bounds. Uncatchable, same class as #263/#310/#317/#318.

No bridge entry point reached it: every quasi-uniform caller already rejected `nbPoints < 2` or
`nbPoints <= 0`. But `OCCTUniformAbscissaByCount` and `OCCTUniformAbscissaByCountRange` had no count
precondition at all, so `Shape.uniformAbscissa(pointCount: 0)` returned five bogus parameters for a
request of zero. `occtValidSampleCount` is now applied at all of them.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w -O0 \
  -ISources/OCCTBridge/include -ISources/OCCTBridge/src \
  -ILibraries/OCCT.xcframework/macos-arm64/Headers \
  -LLibraries/OCCT.xcframework/macos-arm64 \
  Scripts/repro/501-quasiuniform-buffer-overflow/repro_501.mm \
  Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm \
  Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/repro_501
/tmp/repro_501
```

It compiles the shipped `.mm` files, so it measures the real bridge functions rather than copies of
them. Each call writes into a buffer followed by sentinel doubles; a changed sentinel is a real
write past the end. Exit status is 1 while any call overflows.

Before: 48 overflowing calls (16 counts x 3 functions), plus `OCCTGCPntsQuasiUniform` reporting a
last parameter short of the edge's end on all 16.
After: `PASS: 0 overflowing calls`, and the end parameter kept everywhere.

## Not examined

`OCCTUniformAbscissaByDistance` / `OCCTUniformAbscissaByDistanceRange` take an arc-length step rather
than a count, so the clamp does not apply to them and they were left alone. Their behaviour on a
zero or negative distance was not measured.

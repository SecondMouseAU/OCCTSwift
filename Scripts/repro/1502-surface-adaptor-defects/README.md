# #1502: `Surface_Adaptor.mm` -- Darboux trihedron crash + surface-surface extrema drop V

Two findings from the #1413 Wave 6 correctness sweep, both in
`Sources/OCCTBridge/src/OCCTBridge_Surface_Adaptor.mm`. Both are bridge-only fixes; neither needed
an OCCT kernel patch.

## Finding 1: `OCCTGeomFillDarbouxTrihedron` crash

`GeomFill_Darboux::D0`/`D1`/`D2` (`GeomFill_Darboux.cxx:369-372`) unconditionally
`static_cast<Adaptor3d_CurveOnSurface*>(myTrimmed.get())->GetCurve()`/`GetSurface()` on the handle
`SetCurve()` was given. The bridge function accepted a `faceShape` argument (its own comment: "Darboux
needs a curve on surface") but never used it after casting -- it built a plain
`new BRepAdaptor_Curve(edge)` and handed that to `SetCurve()`. `Adaptor3d_CurveOnSurface` and
`BRepAdaptor_Curve` are unrelated siblings under `Adaptor3d_Curve`, so the cast reads private fields
at offsets that don't exist in a `BRepAdaptor_Curve` object: an uncatchable bus error, not a
`Standard_Failure` the bridge's `catch (...)` can absorb.

### Files

| File | What it is |
|---|---|
| `occt_1502_darboux_crash.mm` | The reproducer. `argv[1]` selects `old` (the original bridge code) or `new` (the fixed one). Installs its own SIGBUS/SIGSEGV handler, exits 86 on a crash. |
| `run.sh` | Builds and runs it: `./run.sh old`, `./run.sh new`, or `./run.sh both` (default). Needs `Libraries/OCCT.xcframework` (symlink from the main checkout in a worktree that doesn't have its own). |
| `transcript.txt` | A `./run.sh both` transcript. |

### Fixture

The issue's own repro shape: a circular edge belting a planar disc face
(`BRepBuilderAPI_MakeEdge(gp_Circ(...))` -> `BRepBuilderAPI_MakeWire` -> `BRepBuilderAPI_MakeFace`),
the simplest fixture with a genuine pcurve on a real face.

### How this was validated (an uncatchable crash can't run inside `swift test`)

This is a bridge-only fix, so unlike the kernel-patch findings elsewhere in this repo's history
there is no override-link step: both lanes compile the exact call sequence
`OCCTGeomFillDarbouxTrihedron` used before and after the fix, straight against the pinned
`OCCT.xcframework`.

- **Before** (`./run.sh old`, the code as `main` had it): reliably `SIGBUS` (5/5 runs), matching the
  issue's own report ("Bus error: 10", exit 138 under a plain shell, 86 here under the probe's own
  handler).
- **After** (`./run.sh new`, the fixed code): `D0` returns `true` with a geometrically correct frame.
  For a radius-5 circle centred at the origin in the XY plane evaluated at parameter 0.1 (`gp_Circ`'s
  own angular parametrization): tangent `(-sin 0.1, cos 0.1, 0)` = `(-0.0998, 0.9950, 0)`, normal
  (pointing to the circle's centre) `(-cos 0.1, -sin 0.1, 0)` = `(-0.9950, -0.0998, 0)`, binormal
  `(0, 0, 1)` matching the disc's own normal -- all three match the transcript exactly.

`Tests/OCCTSurfaceTests/Issue1502DarbouxTrihedronTests.swift` exercises the fixed code path through
the public Swift API (`Shape.darbouxTrihedron(onFace:at:)`) as an ordinary regression test; it asserts
the same geometry this reproducer measured. It cannot exercise the *unfixed* path (that would crash
the whole `swift test` process), which is why this standalone reproducer exists and is kept in the
tree: it is the evidence that the crash was real and that the fix closes it, the same role this
project's other uncatchable-crash reproducers play (see `Scripts/repro/1022-datum-point-from-plane-array/`
for the same shape applied to a kernel-side crash).

## Finding 2: `OCCTExtremaExtSSPoint` drops the V parameter of both points

Both extremal points from a surface-surface computation sit on a surface, so each needs a full
`(u, v)`. `OCCTExtremaExtSSPoint` called `p1.Parameter(u1, v1)`/`p2.Parameter(u2, v2)` but only
stored `u1`/`u2` (into `OCCTExtremaPointPair.param1`/`param2`), discarding both `v`s. That struct's
single `param` per point is correct for curve-curve extrema (`OCCTExtremaExtCCPoint`) and for the
curve-side point of curve-surface extrema (`OCCTExtremaExtCSPoint`), which is why it isn't touched
here: reusing it for a surface-surface result -- where *both* points are surface points -- is what
lost the data.

**Fixed with a new, dedicated result type** (`OCCTExtremaSSPointPair`, `(x, y, z, u, v)` per point),
rather than extending `OCCTExtremaPointPair` in place, mirroring how `OCCTExtremaExtPSPoint`
(point-surface) already has its own `OCCTExtremaPointOnSurf` struct instead of reusing the generic
pair. Extending the shared struct instead was considered and rejected: `OCCTExtremaExtCSPoint`'s
surface-side point has the identical missing-V shape (its own comment says so: "V not directly
available in this struct") but is **not** fixed by this PR (different file,
`OCCTBridge_Curve3D_Adaptor.mm`, out of scope for #1502's two findings). Adding `v1`/`v2` fields to
the struct all three functions share would leave `OCCTExtremaExtCSPoint` writing a `0.0` into a field
that looks like a real, computed V but isn't -- exactly the "value returned as a measurement that was
never computed" shape #726's census exists to catch. A dedicated struct populated only by the one
function that returns it has no such gap. Filed separately as a new issue rather than fixed here (see
the PR body / issue tracker), since it needs no kernel patch either but is a distinct defect in a
different file.

No standalone reproducer needed for this one: it isn't a crash, and
`Tests/OCCTAnalysisTests/ExtremaExtSSTests.swift` (`bothPointsCarryTheirOwnUV`) asserts the fix
directly against a real surface-surface extremum with known, non-trivial U and V on both sides.
`probe_extrema_ss.cxx` is the scratch tool used to pick that fixture (two spheres offset in both X
and Z, so the closest points land away from either equator, where V is 0 and a dropped V would pass
undetected) and to confirm its measured distance and (u, v) values independently of the Swift test.

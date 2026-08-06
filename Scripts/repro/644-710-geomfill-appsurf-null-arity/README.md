# OCCTSwift#644 + #710 reproducer, `OCCTGeomFillAppSurf` and two sibling `GeomFill_*` bridge functions

Two independent, uncatchable SIGSEGVs living in `OCCTGeomFillAppSurf`
(`Sources/OCCTBridge/src/OCCTBridge_Surface.mm`) and its two sibling functions
`OCCTGeomFillProfilerAddCurve` and `OCCTGeomFillSectionPlacement`. Filed separately (#644, #710)
because they are different bugs reached by different inputs, fixed together because splitting the
work means two people editing the same function.

## #644: arity, not the divisor

`Surface.appSurf(curves:)` SIGSEGVs on 0 or 1 curves; counts of 2+ return `isDone: true` cleanly.
The issue's own investigation had already disproved the first hypothesis (the unguarded
`(double)i / (double)(count - 1)` divisor at the old line 3285): substituting a guarded `0.0`
there still crashes.

**Root cause**: `GeomFill_AppSurf::Perform` (the constructor-templated `AppBlend_AppSurf`) is
reached by `Surface.appSurf` with `SpApprox = false`, which routes into
`AppDef_Compute::Perform(multL)`. `AppBlend_AppSurf::InternalPerform` builds `multL` as an
`AppDef_MultiLine` sized to `NbPoint = Lin->NbPoints()` (the caller's curve count) and evaluates
the first and last sections at indices `1` and `NbPoint`. At `NbPoint == 1` those are the *same*
section evaluated twice, and `AppDef_Compute::Perform`'s degree-of-freedom bookkeeping -- built
assuming at least one free interior span between two distinct end constraints -- segfaults. At
`NbPoint == 0` the same code (`Lin->Point(1)` with zero points) fails even earlier. Neither path
touches the `(double)i / (double)(count - 1)` divisor at all (it lives in `OCCTGeomFillAppSurf`'s
own `SetParam` loop below `Perform`, never reached at these counts).

**Not new to this family.** `Surface.nSections(curves:params:)` and
`Surface.generatedFromSections(curves:tolerance:)` -- the other two `GeomFill_*` bridge functions
in `OCCTBridge_Surface.mm` taking a variable-length section-curve array
(`OCCTGeomFillNSections`/`OCCTGeomFillGenerator`) -- already carry a `curves.count >= 2` guard at
the Swift boundary (`Sources/OCCTSwift/Surface.swift`). `Surface.appSurf` was the one exception in
the family, not a new pattern.

**Fix**: `Surface.appSurf(curves:)` gets the identical `guard curves.count >= 2 else { return nil
}`, matching its two siblings exactly (same layer, same idiom, same fallback). No bridge-side count
guard was added, matching those two siblings' own bridge-side C functions, which also carry none.

## #710: a fifth alias form the null-handle checker cannot see

`OCCTBridge_Surface.mm` has nine sites reaching a `Handle(Geom_Curve)` through
`*(const Handle(Geom_Curve)*)curveRef` -- reinterpreting the wrapper pointer directly as a pointer
to the `Handle` it contains, valid only because the wrapper struct's sole field is that `Handle`.
`Scripts/check-null-handle-guards.py`'s `aliases()` only recognises `IDENT -> field`, so this form
is invisible to it regardless of whether the use is guarded.

Six of the nine wrap the result immediately in `new GeomAdaptor_Curve(curve)`, which raises a
catchable `Standard_Failure` on a null `Handle` -- already absorbed by each function's own
`catch (...)`. **Three do not**, and each SIGSEGVs uncatchably on a null `Handle(Geom_Curve)`:

| function | OCCT call | root cause |
|---|---|---|
| `OCCTGeomFillProfilerAddCurve` | `GeomFill_Profiler::AddCurve` | `theCurve->IsInstance(...)` dereferences `Curve` before any null check (`GeomFill_Profiler.cxx:130`) |
| `OCCTGeomFillAppSurf` | `GeomFill_SectionGenerator::AddCurve` | the same non-virtual `GeomFill_Profiler::AddCurve` -- `GeomFill_SectionGenerator` does not override it |
| `OCCTGeomFillSectionPlacement` | `GeomFill_SectionPlacement` ctor | `Section->IsInstance(...)` dereferences `Section` before any null check (`GeomFill_SectionPlacement.cxx:169`) |

`OCCTGeomFillSectionPlacement`'s *other* curve argument, `pathCurve`, is already safe: it is
wrapped in `new GeomAdaptor_Curve(pathCurve)` before use, which is one of the six catchable sites.

**Fix**: each site gets `if (<curve>.IsNull()) return <fallback>;` immediately after binding the
alias, matching this file's existing idiom for every other guarded site in the family.

**Addendum, PR #722 review pass.** The first version of this fix left the three aliases bound
through the file's `*(const Handle(Geom_Curve)*)ref` cast form, invisible to
`check-null-handle-guards.py`: a real gap an automated review caught, since nothing stopped a
future edit from silently deleting one of the three `IsNull()` checks. Fixed by rebinding just
those three aliases (`curveRef->curve`, `curveRefs[i]->curve`, `sectionCurveRef->curve`) through
the field access the checker's existing "handle alias" pattern already recognises, instead of the
cast form; no change to the checker itself. `sectionCurve`'s sibling argument `pathCurve` keeps the
cast form deliberately: it needs no guard, and `ALLOWED` has no per-argument granularity, so
exempting `OCCTGeomFillSectionPlacement` by name to cover `pathCurve` would blind the checker to
the `sectionCurve` guard entirely. Proven by injection: removing each of the three guards in turn
now makes `check-null-handle-guards.py` report exactly that site; restoring it goes clean again.
This does **not** teach the checker to see a future fourth site written in the cast form: the six
untouched `GeomAdaptor_Curve`-wrapped sites (including `pathCurve`) keep using it, so the shape
itself stays in the tree; see "Should the checker learn this shape" below, unchanged by this
addendum.

**Reachability, measured, not assumed.** Two of the three are reachable from public Swift API
(`Surface.swift`'s `appSurf(curves:)`, `Curve3D.swift`'s `sectionPlacement(section:...)`). The
third, `OCCTGeomFillProfilerAddCurve`, backs `CurveProfiler.addCurve(_:)` -- and **`CurveProfiler`
itself is publicly constructible**, via `CurveProfiler.create()` (a `public static func`, already
exercised by `Tests/OCCTSurfaceTests/OCCTSurfaceTests.swift`'s `GeomFillProfilerTests` suite). A
claim on file that `CurveProfiler` has "no public factory anywhere" is wrong -- `create()` is
exactly that factory, and has been since the type was first wrapped. All three sites are therefore
equally reachable *in that respect*: whether any of them is reachable with a *null-handle* curve
argument is the separate, harder question below.

### Can a public factory produce a null-handle `Curve3D`?

All three crash only if a live `Curve3D` wrapper (passed as the `curve`/`section` argument) holds a
**null** internal `Handle(Geom_Curve)` -- not if the `CurveProfiler`/`Surface`/other receiver is
somehow invalid. `Curve3D`'s own initialiser (`internal init(handle:)`, `Curve3D.swift`) is reachable
from any `@testable import OCCTSwift` test target, so the real question is whether any bridge
function -- called by any public `Curve3D` factory -- can hand back a non-null `OCCTCurve3DRef`
wrapping a default-constructed (null) `Handle(Geom_Curve)`.

Measured by reading every `new OCCTCurve3D` / `new OCCTCurve3D()` construction site across all five
bridge files that produce one (`OCCTBridge_Curve3D.mm`, `OCCTBridge_Surface.mm`,
`OCCTBridge_Topology.mm`, `OCCTBridge_IO.mm`, `OCCTBridge_ProjLib_NLPlate.mm` -- ~100 sites): every
single one either (a) checks `IsNull()`/`IsDone()` on the source handle before assigning it into
the wrapper, (b) constructs from a freshly-allocated concrete `Geom_*`/`GeomEval_*` object that
cannot be null, or (c) is a down-cast/copy of an already-checked input. This reconfirms, in the
current tree, the same finding #478's sweep made of the (then) 228 handle-binding sites: **no
public factory produces a null-handle wrapper.**

Consequence: the two publicly-reachable sites (`OCCTGeomFillAppSurf`'s `curveRefs` loop,
`OCCTGeomFillSectionPlacement`'s `sectionCurve`) are latent hardening against a hazard the current
tree cannot actually trigger through the public Swift API today, not a live crash a caller can
reach right now. `OCCTGeomFillProfilerAddCurve` is in the same position. This is a materially lower
severity than #710's own filing implied, and worth fixing anyway: (1) it is a one-line guard
matching an established idiom, (2) the invariant is a fact about today's ~100 sites, not a
guarantee about the next one this fast-moving codebase adds, and (3) the alias form stays
checker-invisible regardless (see below), so nothing else stands between a future null-producing
site and this exact crash.

### Was `CurveProfiler`'s unconstructibility a design or an oversight?

Neither -- it was a wrong premise. `CurveProfiler.create()` is public and has been since the type
was introduced (`git log -S OCCTGeomFillProfilerCreate` finds it at the type's original commit, not
a later addition). The "no public factory" claim in #710 traces to trying to call the *internal*
`init(handle:)` directly and reading the resulting "inaccessible due to 'internal' protection
level" compiler error as "this type cannot be constructed" -- it means only that a caller cannot
inject an arbitrary raw handle, which is the correct, intentional design (every other geometry
wrapper in this codebase -- `Curve3D`, `Surface`, `Curve2D` -- has the identical internal-init /
public-factory split). Nothing about `CurveProfiler` needed deciding or fixing on this point.

### Should the null-handle checker learn this alias form?

Not as a follow-up carrying any urgency. Fixing these three sites does not make
`Scripts/check-null-handle-guards.py` able to see a future fourth site written the same way --
the six already-guarded sites in this file keep using the identical alias form, so the shape stays
in the tree regardless of what this PR does. Teaching the checker `*(const Type*)wrapperExpr` as a
fifth alias-binding form (alongside the four #618 already documented) is real, valuable work -- but
it is general-purpose census work belonging with the checker's own maintenance, not something this
PR's two narrow bug fixes need to carry. It is exactly the kind of task #666/#711's own "teach the
checker a new shape" pattern already exists for.

## Verification

`probe.mm` in this directory runs all of PART 1 (arity) and PART 2 (null handle) forked per case
against the pinned kernel, then PART 3 reproduces the fix (guard + call) inline against the same
kernel:

```bash
ARTIFACT_DIR=".build/artifacts/<hash>/OCCT/OCCT.xcframework/macos-arm64"   # what `swift build`
                                                                            # already fetched --
                                                                            # or a local
                                                                            # Libraries/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w \
  -I"$ARTIFACT_DIR/Headers" -L"$ARTIFACT_DIR" \
  Scripts/repro/644-710-geomfill-appsurf-null-arity/probe.mm -o /tmp/occt_644_710_probe \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
/tmp/occt_644_710_probe
```

Measured against `v2.0.0-kernel.1`:

```
PART 1 -- #644 arity (GeomFill_SectionGenerator + GeomFill_AppSurf, valid curves)
  count=0 curves                                 SIGNAL (uncatchable, uncaught by any catch(...))
  count=1 curve                                  SIGNAL (uncatchable, uncaught by any catch(...))
  count=2 curves (control -- must succeed)       returned normally

PART 2 -- #710 null Handle(Geom_Curve), the three unguarded alias-form sites
  OCCTGeomFillProfilerAddCurve: GeomFill_Profiler::AddCurve(null) SIGNAL (uncatchable, ...)
  OCCTGeomFillAppSurf: GeomFill_SectionGenerator::AddCurve(null) SIGNAL (uncatchable, ...)
  OCCTGeomFillSectionPlacement: GeomFill_SectionPlacement ctor(null section) SIGNAL (uncatchable, ...)

For contrast -- ... GeomFill_LocationDraft::SetCurve path: new GeomAdaptor_Curve(null) Standard_Failure (catchable)

PART 3 -- the fix (guard + call), same three sites, run against the same kernel
  #644: Surface.appSurf's `curves.count >= 2` guard, count=1 returned normally
  OCCTGeomFillProfilerAddCurve, guarded          returned normally
  OCCTGeomFillAppSurf's curveRefs loop, guarded  returned normally
  OCCTGeomFillSectionPlacement, guarded          returned normally

5 uncatchable (SIGSEGV), 1 catchable, 5 returned normally
```

Exit code of the driver itself is 0 either way (each case runs in a forked child), which is why
`WIFSIGNALED` on the child, not the process exit code, is what the table reads.

The Swift-level "before" evidence for #644 (which the public API genuinely reaches, unlike #710's
three sites) was additionally taken from a separate process, per this repo's own policy for an
uncatchable crash: `Sources/OCCTTest/main.swift` was temporarily repointed at
`Surface.appSurf(curves:)` for curve counts 0-3 and run as `.build/debug/OCCTTest <count>`,
restored before commit, no diff left behind (same method #705 used):

| count | before | after |
|---|---|---|
| 0 | SIGSEGV, exit 139 | `nil`, exit 0 |
| 1 | SIGSEGV, exit 139 | `nil`, exit 0 |
| 2 | `AppSurfResult(..., isDone: true)`, exit 0 | unchanged |
| 3 | `AppSurfResult(..., isDone: true)`, exit 0 | unchanged |

## Related

#644, #710, #666/#711 (Cluster C census, where #710 was found), #656 (the census mandate: a handle
obtained through indirection), #618 (the four alias forms the checker already knows), #478/#556
(the two prior null-handle sweeps and the "can a null-handle wrapper exist" measurement this
reconfirms), #705 (the separate-process before/after methodology this reuses).

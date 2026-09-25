# #2746: `BRepCheck_Edge::InContext` raises an uncatchable SIGSEGV on an edge with no 3D curve

## What this establishes

1. **It reproduces**, on the pinned kernel `v4.0.0-kernel.1`, in the construction the issue names.
2. **The minimal construction** is a box edge whose 3D curve is nulled in place, checked against
   **one specific** owning face. The other owning face survives. The asymmetry is the whole
   mechanism, and it is why the crash reads as intermittent.
3. **The fault is a null `Handle(GeomAdaptor_Curve)` dereference inside
   `BRepCheck_Edge::InContext`**, not pcurve bookkeeping after `UpdateEdge`. `BRep_Builder` leaves
   the edge in a self-consistent state; `InContext` is what mishandles it.
4. **An edge that never had a curve, with zero representations, does not crash.** It is the edge
   that has pcurves but no valid 3D curve that does. Both of the ways to reach that state crash,
   so it is not about `UpdateEdge` either.
5. **No other `BRepCheck_*::InContext` overload shares the fault.** `BRepCheck_Vertex::InContext`,
   which is what #2747 would want, guards its 3D curve with `if (!C.IsNull())` and was measured
   clean on the same construction.
6. **The bridge does reach it**, contrary to the issue's premise, through `BRepCheck_Analyzer`,
   and a crafted `.brep` file survives a write/read round trip and still crashes the analyzer.

## Build

There is no checked-in `Libraries/` xcframework on this branch. `swift build` once, then:

```bash
Scripts/repro/2746-brepcheck-incontext-sigsegv/run.sh
```

`run.sh` finds the pinned asset SwiftPM resolved under `.build/artifacts`, compiles `probe.mm` at
`-g -O0` (so the SIGSEGV handler's backtrace names the faulting frame, lldb being unavailable
here), and runs each case in its own process. One process per case is not tidiness: a case that
reproduces the defect takes its process with it, because `OCC_CATCH_SIGNALS` is inert in this
build.

## The mechanism, read from the pinned source and confirmed by measurement

`BRep_Builder::UpdateEdge(edge, Handle(Geom_Curve)(), tol)` does not remove the edge's 3D curve
representation. `BRep_Builder.cxx`'s `UpdateCurves` finds the existing `BRep_Curve3D` and calls
`Curve3D(C)` on it with the null handle, so the representation stays in the list and still answers
`true` to `IsCurve3D()`. The probe measures exactly that: `curve3d=1 (null=1)`.

`BRepCheck_Edge::Minimum()` then walks the representations looking for a 3D reference:

```cpp
if (myCref.IsNull() && !cr->Curve3D().IsNull())
{
  myCref = cr;
}
```

`exist` becomes true, so no `BRepCheck_No3DCurve` is reported, but `myCref` stays null because the
curve is. Minimum's next block falls back to the first **curve-on-surface** representation, and
sets `myHCurve` from it:

```cpp
myHCurve = new Adaptor3d_CurveOnSurface(ACSref);
```

`myHCurve` is declared `occ::handle<Adaptor3d_Curve>`, so that assignment is legal and silent. It
is also the only case in which `myHCurve` is not a `GeomAdaptor_Curve`.

`InContext(face)` then reaches its "no pcurve found for this face" branch. For the face whose own
pcurve representation `Minimum()` adopted as `myCref`, the loop skips that representation by
identity (`cr != myCref`) and finds no other on that surface, so `pcurvefound` stays false. The
support is a plane, so control reaches the on-the-fly projection:

```cpp
// Dub - Normalement myHCurve est une GeomAdaptor_Curve
occ::handle<GeomAdaptor_Curve> Gac = occ::down_cast<GeomAdaptor_Curve>(myHCurve);
occ::handle<Geom_Curve>        C3d = Gac->Curve();
```

The comment is the bug report. The down_cast returns null, `Gac->Curve()` dereferences it, SIGSEGV.
`BRepCheck_Edge.cxx:488-489` in the pinned tree, and the same two lines at the same line numbers on
upstream `master` today.

Four independent measurements pin it to those two lines and nothing else:

- **The other owning face survives.** Its pcurve representation is not `myCref`, so `pcurvefound`
  becomes true and the projection branch is never entered.
- **`GeometricControls(false)` survives.** The projection block sits inside `if (myGctrl)`.
- **A non-planar support survives**, reporting `BRepCheck_NoCurveOnSurface`. The `P.IsNull()` test
  above the projection sends a cylinder down the other arm.
- **The down_cast itself**, built by hand in `downcast-corroboration` from the same two adaptor
  types with no `BRepCheck` involved: `GeomAdaptor_Curve` casts, `Adaptor3d_CurveOnSurface` gives
  null.

## The open questions in the issue, answered

**"A null `Handle(Geom_Curve)` dereference inside `BRepCheck_Edge::InContext`, or something about
the face's pcurve bookkeeping after `UpdateEdge`?"** The first, with one correction: the null
handle dereferenced is a `GeomAdaptor_Curve`, not a `Geom_Curve`, and it is null because a
`down_cast` failed rather than because a curve was missing. The pcurve bookkeeping is intact.
`removed-rep-edge-incontext` proves the point from the other side: drop the `Curve3D`
representation altogether, so `UpdateEdge` is never called and `Minimum()` does report
`No3DCurve`, and the same two lines still crash.

**"Does an edge that never had a curve, built fresh with zero representations, crash the same
way?"** No. `fresh-edge-zero-reps` builds one with `BRep_Builder::MakeEdge` and nothing else,
splices it into a planar face, and measures `Minimum: No3DCurve` then `InContext: NoError`,
surviving. With no representations at all there is no pcurve to fall back to, `myCref` stays null,
and `InContext`'s `if (!myCref.IsNull())` skips the whole face branch. **The precondition is a
non-degenerated edge with no valid 3D curve and at least one pcurve**, which is a narrower
population than "an edge with no 3D curve".

Degenerated edges are safe for a different reason: `Minimum()` guards the pcurve fallback with
`!Degenerated`. `guard-predicate` measures a cylinder, whose seam and degenerated edges are the
obvious false-positive risk, as clean.

**"Which other `BRepCheck_*::InContext` overloads share the shape?"** None.
`down_cast<GeomAdaptor_Curve>` appears exactly twice in the whole `BRepCheck` package, both in
`BRepCheck_Edge.cxx`, and the second is a fresh `new`. `BRepCheck_Vertex::InContext` reads a 3D
curve too but wraps it in `if (!C.IsNull())`, and was measured clean against both the nulled edge
and its owning face. `BRepCheck_Wire::InContext` was measured clean on the same face.
`BRepCheck_Face::InContext` touches no geometry and `BRepCheck_Solid::InContext` is empty.

**"Does it reproduce on OCCT `master`?"** The file was fetched from `master` and is byte-identical
to the pinned tree, so yes by inspection. The last eight commits to it are the 8.0.0 refactor, a
clang-tidy pass and unrelated thread-safety work; none touches these lines. No open upstream PR or
issue mentions `BRepCheck_Edge::InContext`.

## Reachability, which is where this diverges from the issue

The issue says no bridge function reaches `InContext`, because the `checkSubShape` helper calls
`Minimum()` only. That is true of `checkSubShape` and false of the bridge as a whole.
**`BRepCheck_Analyzer::Perform()` calls `BRepCheck_Edge::InContext(face)` itself**, once per edge
per face, and `BRepCheck_Analyzer` is constructed at 19 sites across six bridge `.mm` files as
counted here (#2750 recounted it as 20 when it came to guard them; that row is the current one).
`nulled-edge-analyzer` measures the crash through a plain `BRepCheck_Analyzer(box).IsValid()`, and
the backtrace runs through `BRepCheck_ParallelAnalyzer::operator()` and `OSD_Parallel::For`.

`Perform()` wraps each `InContext` call in `try { OCC_CATCH_SIGNALS ... } catch (Standard_Failure
const&)`. Neither half helps: `OCC_CATCH_SIGNALS` is inert in this build, and a null dereference is
a signal, not a `Standard_Failure`.

`brep-roundtrip-analyzer` closes the loop on whether this is only reachable by calling
`BRep_Builder` yourself, which the bridge never does. `BRepTools::Write` accepts the nulled shape,
`BRepTools::Read` accepts the file, and the reloaded shape still crashes the analyzer. Writing
drops the null 3D curve record rather than preserving it, so what comes back is the
dropped-representation state rather than the null-curve one, and that state crashes too. **A
`.brep` file is enough to take down a consumer's process through the shipped validity API.**

## What a bridge-side guard would test

Not "has a null `Curve3D` representation": that predicate is false for the shape that comes back
from the `.brep` round trip, which crashes anyway. The predicate that covers both crashing
constructions and neither safe one is a **non-degenerated edge whose `BRep_Tool::Curve` is null and
which has at least one curve-on-surface representation**. `guard-predicate` measures both
predicates against four shapes:

| shape | null `Curve3D` rep | pcurve-only edge | crashes |
|---|---|---|---|
| healthy box | false | false | no |
| box with the 3D curve nulled | true | true | yes |
| box with the `Curve3D` representation dropped | false | true | yes |
| cylinder (seam plus degenerated edges) | false | false | no |

The second predicate is the one to use, and it is the one #2750 installed: the shipped guard is
`occtShapeHasPCurveOnlyEdge` / `occtShapePCurveOnlyEdgeCount` in `OCCTBridge_Internal.h`, called
before every bridge `BRepCheck_Analyzer` construction. #2750 narrowed the predicate once more
along the way, to a non-degenerated **edge of a face**, since `Perform` reaches `InContext` only
from its `TopAbs_FACE` case. `okf/references/known-occt-bugs.md` carries the current statement of
the guard and the site count; what is below is this probe's own measurement, unchanged.

## Transcript

Measured on the pinned kernel `v4.0.0-kernel.1`, macOS arm64. Addresses are masked and the shell's
own "Segmentation fault" line removed, nothing else is edited.

```
xcframework: <resolved v4.0.0-kernel.1 asset>
compiling...

--------------------------------------------------------------------------
=== case: healthy-edge-incontext ===
  representations: total=3 curve3d=1 (null=0) pcurve=2
  Minimum: NoError
  InContext(face0): NoError
  InContext(face1): NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-incontext-face0 ===
  representations: total=3 curve3d=1 (null=1) pcurve=2
  Minimum: NoError
  calling InContext(face0)...

*** SIGSEGV (uncatchable in this build) ***
0   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_111segvHandlerEi + 100
1   libsystem_platform.dylib            0x................ _sigtramp + 56
2   occt_probe_2746                     0x................ _ZN14BRepCheck_Edge9InContextERK12TopoDS_Shape + 3480
3   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_123caseNulledEdgeInContextEb + 296
4   occt_probe_2746                     0x................ main + 220
5   dyld                                0x................ start + 6688
Scripts/repro/2746-brepcheck-incontext-sigsegv/[exit 139]

--------------------------------------------------------------------------
=== case: nulled-edge-incontext-face1 ===
  representations: total=3 curve3d=1 (null=1) pcurve=2
  Minimum: NoError
  calling InContext(face1)...
  InContext: NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-no-minimum ===
  calling InContext(face0) with no explicit Minimum() call...

*** SIGSEGV (uncatchable in this build) ***
0   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_111segvHandlerEi + 100
1   libsystem_platform.dylib            0x................ _sigtramp + 56
2   occt_probe_2746                     0x................ _ZN14BRepCheck_Edge9InContextERK12TopoDS_Shape + 3480
3   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_123caseNulledEdgeNoMinimumEv + 132
4   occt_probe_2746                     0x................ main + 300
5   dyld                                0x................ start + 6688
Scripts/repro/2746-brepcheck-incontext-sigsegv/[exit 139]

--------------------------------------------------------------------------
=== case: nulled-edge-gctrl-off ===
  Minimum: NoError
  calling InContext(face0) with GeometricControls(false)...
  InContext: NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-cylindrical-face ===
  representations: total=3 curve3d=1 (null=1) pcurve=2
  Minimum: NoError
  calling InContext(cylindrical face)...
  InContext: NoCurveOnSurface
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: removed-rep-edge-incontext ===
  representations: total=2 curve3d=0 (null=0) pcurve=2
  Minimum: No3DCurve
  calling InContext(face0)...

*** SIGSEGV (uncatchable in this build) ***
0   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_111segvHandlerEi + 100
1   libsystem_platform.dylib            0x................ _sigtramp + 56
2   occt_probe_2746                     0x................ _ZN14BRepCheck_Edge9InContextERK12TopoDS_Shape + 3480
3   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_127caseRemovedRepEdgeInContextEv + 344
4   occt_probe_2746                     0x................ main + 408
5   dyld                                0x................ start + 6688
Scripts/repro/2746-brepcheck-incontext-sigsegv/[exit 139]

--------------------------------------------------------------------------
=== case: fresh-edge-zero-reps ===
  representations: total=0 curve3d=0 (null=0) pcurve=0
  fresh edge is part of the face: yes
  Minimum: No3DCurve
  calling InContext(face)...
  InContext: NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-detached ===
  calling InContext(face of an unrelated box)...
  InContext: SubshapeNotInShape
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-vertex-incontext ===
  Minimum: NoError
  calling BRepCheck_Vertex::InContext(nulled edge)...
  InContext(edge): NoError
  calling BRepCheck_Vertex::InContext(face0)...
  InContext(face0): NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-wire-incontext ===
  Minimum: NoError
  calling BRepCheck_Wire::InContext(face0)...
  InContext(face0): NoError
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: healthy-edge-analyzer ===
  representations: total=3 curve3d=1 (null=0) pcurve=2
  calling BRepCheck_Analyzer(box).IsValid()...
  IsValid() = true
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: nulled-edge-analyzer ===
  representations: total=3 curve3d=1 (null=1) pcurve=2
  calling BRepCheck_Analyzer(box).IsValid()...

*** SIGSEGV (uncatchable in this build) ***
0   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_111segvHandlerEi + 100
1   libsystem_platform.dylib            0x................ _sigtramp + 56
2   occt_probe_2746                     0x................ _ZN14BRepCheck_Edge9InContextERK12TopoDS_Shape + 3480
3   occt_probe_2746                     0x................ _ZNK26BRepCheck_ParallelAnalyzerclEi + 6048
4   occt_probe_2746                     0x................ _ZN12OSD_Parallel3ForI26BRepCheck_ParallelAnalyzerEEviiRKT_b + 192
5   occt_probe_2746                     0x................ _ZN18BRepCheck_Analyzer7PerformEv + 500
6   occt_probe_2746                     0x................ _ZN18BRepCheck_AnalyzerC2ERK12TopoDS_Shapebbb + 108
7   occt_probe_2746                     0x................ _ZN18BRepCheck_AnalyzerC1ERK12TopoDS_Shapebbb + 72
8   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_112caseAnalyzerEb + 156
9   occt_probe_2746                     0x................ main + 596
10  dyld                                0x................ start + 6688
Scripts/repro/2746-brepcheck-incontext-sigsegv/[exit 139]

--------------------------------------------------------------------------
=== case: brep-roundtrip-analyzer ===
  BRepTools::Write accepted the nulled shape
  BRepTools::Read accepted the file
  reloaded shape has a null-3D-curve edge: no
  calling BRepCheck_Analyzer(reloaded).IsValid()...

*** SIGSEGV (uncatchable in this build) ***
0   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_111segvHandlerEi + 100
1   libsystem_platform.dylib            0x................ _sigtramp + 56
2   occt_probe_2746                     0x................ _ZN14BRepCheck_Edge9InContextERK12TopoDS_Shape + 3480
3   occt_probe_2746                     0x................ _ZNK26BRepCheck_ParallelAnalyzerclEi + 6048
4   occt_probe_2746                     0x................ _ZN12OSD_Parallel3ForI26BRepCheck_ParallelAnalyzerEEviiRKT_b + 192
5   occt_probe_2746                     0x................ _ZN18BRepCheck_Analyzer7PerformEv + 500
6   occt_probe_2746                     0x................ _ZN18BRepCheck_AnalyzerC2ERK12TopoDS_Shapebbb + 108
7   occt_probe_2746                     0x................ _ZN18BRepCheck_AnalyzerC1ERK12TopoDS_Shapebbb + 72
8   occt_probe_2746                     0x................ _ZN12_GLOBAL__N_125caseBrepRoundtripAnalyzerEv + 512
9   occt_probe_2746                     0x................ main + 676
10  dyld                                0x................ start + 6688
Scripts/repro/2746-brepcheck-incontext-sigsegv/[exit 139]

--------------------------------------------------------------------------
=== case: downcast-corroboration ===
  myHCurve built from a 3D curve      -> dynamic type GeomAdaptor_Curve, down_cast<GeomAdaptor_Curve> succeeds
  myHCurve built from a pcurve        -> dynamic type Adaptor3d_CurveOnSurface, down_cast<GeomAdaptor_Curve> IS NULL
  survived
[exit 0]

--------------------------------------------------------------------------
=== case: guard-predicate ===
  healthy box: hasNullCurve3DRepresentation = false
  nulled box:  hasNullCurve3DRepresentation = true
  box with the Curve3D representation dropped: hasNullCurve3DRepresentation = false
  cylinder (seam plus degenerated edges): hasNullCurve3DRepresentation = false

  the precondition predicate, which covers both crashing constructions:
  healthy box:                      hasPCurveOnlyEdge = false
  nulled-curve box:                 hasPCurveOnlyEdge = true
  dropped-representation box:       hasPCurveOnlyEdge = true
  cylinder (seam plus degenerated): hasPCurveOnlyEdge = false
  survived
[exit 0]
```

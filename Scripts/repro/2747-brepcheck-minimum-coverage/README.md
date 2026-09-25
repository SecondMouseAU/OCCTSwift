# #2747: what BRepCheck_Edge::Minimum() / BRepCheck_Vertex::Minimum() actually check

## Build

The pinned OCCT asset resolves under `.build/artifacts/<worktree-id>/OCCT/OCCT.xcframework` once
`swift build` has run at least once (there is no `Libraries/` xcframework checked in for this
fix). Substitute your own resolved path for `<xcframework>` below; on the machine this was
measured on it was
`.build/artifacts/agent-a94dbae3a0478815f/OCCT/OCCT.xcframework/macos-arm64`, resolving
`v4.0.0-kernel.1`.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"<xcframework>/Headers" \
  -L"<xcframework>" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2747-brepcheck-minimum-coverage/probe.mm -o /tmp/occt_probe_2747
/tmp/occt_probe_2747
```

## What it measures

`checkEdge(at:)` / `checkVertex(at:)` (`checkSubShape` in
`Sources/OCCTBridge/src/OCCTBridge_Healing_Fix.mm`) call `Minimum()` and never `InContext()`, so
what `Minimum()` alone can report is the entire contract of those two Swift methods. PR #2742's
probe (`Scripts/repro/2734-checksubshape-errorcount/probe.mm`) established that every
construction it tried reports `BRepCheck_NoError`. This probe reads
`BRepCheck_Edge.cxx`/`BRepCheck_Vertex.cxx`
(`Libraries/occt-src/src/ModelingAlgorithms/TKTopAlgo/BRepCheck/`, confirmed unpatched: no
`Scripts/patches/*.patch` touches either file) to find every status `Minimum()`'s own logic can
append, builds one construction per status, and measures what `Minimum()` actually reports.

Measured output (pinned kernel, v4.0.0-kernel.1):

```
=== EDGE ===
control: ordinary edge                                       isValid=true  firstError=NoError                  (statusCount=1)
No3DCurve: MakeEdge, no UpdateEdge call at all               isValid=false firstError=No3DCurve                (statusCount=1)
Multiple3DCurve: 2nd Curve3D rep appended directly           isValid=false firstError=Multiple3DCurve          (statusCount=1)
InvalidSameParameterFlag: SameRange=false, SameParameter=true isValid=false firstError=InvalidSameParameterFlag (statusCount=1)
InvalidRange: Range(edge, 5.0, 5.0), Last == First           isValid=false firstError=InvalidRange             (statusCount=1)
InvalidRange: Range(edge, 5.0, 0.0), Last < First            isValid=false firstError=InvalidRange             (statusCount=1)
InvalidDegeneratedFlag: BRep_TEdge::Degenerated(true) direct, curve kept isValid=false firstError=InvalidDegeneratedFlag   (statusCount=1)
re-confirm #2742: BRep_Builder::Degenerated(e, true), curve nulled by the call isValid=true  firstError=NoError                  (statusCount=1)

=== VERTEX ===
(BRepCheck_Vertex::Minimum() appends BRepCheck_NoError unconditionally; every row below is
expected to read NoError, and no vertex construction can change that outcome. Confirmed by
construction, not merely by source reading.)
ordinary vertex                                              isValid=true  firstError=NoError                  (statusCount=1)
negative-tolerance vertex                                    isValid=true  firstError=NoError                  (statusCount=1)
huge-coordinate, zero-tolerance vertex                       isValid=true  firstError=NoError                  (statusCount=1)
```

## Findings

1. **`BRepCheck_Edge::Minimum()` is not blind. It checks four things, all read directly from the
   `TopoDS_Edge`'s own `BRep_TEdge` data, none of them requiring a context shape:**
   - Exactly one 3D curve representation is present (`BRepCheck_No3DCurve` if zero,
     `BRepCheck_Multiple3DCurve` if more than one).
   - The `SameRange`/`SameParameter` flag pair is consistent: `SameParameter` true while
     `SameRange` is false is rejected (`BRepCheck_InvalidSameParameterFlag`).
   - The edge's own parameter range is ordered (`Last > First`), and consistent with the
     underlying curve's periodicity or domain (`BRepCheck_InvalidRange`).
   - The `Degenerated` flag is not set while a real 3D curve is still attached
     (`BRepCheck_InvalidDegeneratedFlag`), though this one is reachable only by mutating the
     `BRep_TEdge` directly: `BRep_Builder::Degenerated(edge, true)`, the only public route to
     setting the flag, nulls the 3D curve as a side effect (`BRep_Builder.cxx`), which removes the
     precondition (`myCref` non-null) the check itself requires. Every construction #2742 tried
     that forced `Degenerated` went through the builder and so could not trigger it; this is why
     that probe reported `NoError` for it.

2. **None of these four are reachable through OCCTSwift's own shape-construction API.** The
   bridge never calls `BRep_Builder::Degenerated`, `SameRange`, `Range` (edge parameter range), or
   appends a `BRep_CurveRepresentation` directly; `grep -rn "SameRange\|SameParameter\|Degenerated"
   Sources/OCCTBridge/src/*.mm` finds no construction site. A shape built end to end through
   `Shape`/`Wire`/`Edge` cannot reach any of these four states. They are realistic for
   **imported** geometry (an IGES/STEP edge can legitimately arrive with a missing 3D curve
   representation or an inconsistent `SameParameter` flag from an upstream tool), which is the
   one case `checkEdge(at:)` can actually help with.

3. **`BRepCheck_Vertex::Minimum()` has no conditional logic at all.** Its entire body is:
   ```cpp
   void BRepCheck_Vertex::Minimum()
   {
     if (!myMin)
     {
       ...
       lst.Append(BRepCheck_NoError);
       myMin = true;
     }
   }
   ```
   No status other than `BRepCheck_NoError` is reachable through it, for any vertex whatsoever.
   This is a structural invariant of the OCCT source, not a property of the three constructions
   measured here; the three are a confirmation, not the evidence. Every real vertex check
   (`InvalidPointOnCurve`, `InvalidPointOnCurveOnSurface`, `InvalidPointOnSurface`) lives in
   `BRepCheck_Vertex::InContext()`, which `checkSubShape` never calls.

4. **What `Minimum()` never checks, for either type, confirming the issue's own list**: geometric
   agreement between the edge's curve and its vertices, curve-to-surface deviation, closed-surface
   pcurve consistency, free-edge/multi-connexity against an owning solid, or (for a vertex)
   agreement between the vertex's point and any curve or surface it sits on. All of these are
   `InContext()`-only, and `InContext()` is blocked on #2746 (an uncatchable SIGSEGV on one of the
   constructions in #2742's probe).

Conclusion: `checkEdge(at:)`'s `isValid == true` means "this edge's own curve/flag bookkeeping is
internally consistent", not "this edge is geometrically valid". `checkVertex(at:)`'s
`isValid == true` carries no information at all: it is the function's only possible return.
`docs/reference/Shape-Measurement.md` and the doc comments on both methods in
`Sources/OCCTSwift/Shape+Topology.swift` are updated to say this.

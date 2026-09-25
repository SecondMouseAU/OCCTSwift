# #2734: checkSubShape never incremented errorCount

## Build

The pinned OCCT asset resolves under `.build/artifacts/<worktree-id>/OCCT/OCCT.xcframework` once
`swift build` has run at least once (there is no `Libraries/` xcframework checked in for this
fix). Substitute your own resolved path for `<xcframework>` below; on the machine this was measured
on it was `.build/artifacts/agent-a81c830d3ba26e0fe/OCCT/OCCT.xcframework/macos-arm64`, resolving
`v4.0.0-kernel.1`.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"<xcframework>/Headers" \
  -L"<xcframework>" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2734-checksubshape-errorcount/probe.mm -o /tmp/occt_probe_2734
/tmp/occt_probe_2734
```

## What it measures

`probe.mm` re-implements `checkSubShape`'s counting loop verbatim, both as it read before this fix
(never increments `errorCount`) and as it reads after (counts every non-`BRepCheck_NoError`
status, matching `OCCTCheckFace`/`OCCTCheckSolid`/`OCCTCheckShape` in
`OCCTBridge_Healing_Analysis.mm`), and runs both against `BRepCheck_Edge`/`Wire`/`Shell`/`Vertex`
on sub-shapes built to be genuinely invalid.

Measured output (pinned kernel, v4.0.0-kernel.1):

```
=== EDGE ===
valid edge:   isValid=true errorCount(buggy)=0 errorCount(fixed)=0 firstError=NoError
no-3D-curve edge: isValid=true errorCount(buggy)=0 errorCount(fixed)=0 firstError=NoError  <-- #2734

=== WIRE ===
disconnected wire: isValid=false errorCount(buggy)=0 errorCount(fixed)=1 firstError=NotConnected  (hadAnyStatus=true)

=== SHELL ===
empty shell: isValid=false errorCount(buggy)=0 errorCount(fixed)=1 firstError=EmptyShell  (hadAnyStatus=true)

=== VERTEX ===
ordinary vertex: isValid=true errorCount(buggy)=0 errorCount(fixed)=0 firstError=NoError  (hadAnyStatus=true)
negative-tolerance vertex: isValid=true errorCount(buggy)=0 errorCount(fixed)=0 firstError=NoError  (hadAnyStatus=true)
```

## Findings

1. **The bug is real and confirmed on genuinely invalid sub-shapes for WIRE and SHELL.** A
   disconnected wire and an empty shell both fault `BRepCheck_Wire::Minimum()` /
   `BRepCheck_Shell::Minimum()` (the only method `checkSubShape` calls): `isValid` correctly flips
   to `false`, but the pre-fix loop leaves `errorCount` at `0`, exactly the symptom #2734 reports.
   The fixed loop reports `errorCount == 1` and the correct `firstError`.

2. **The issue's own suggested EDGE repro (a 3D curve removed) does not fault
   `BRepCheck_Edge::Minimum()` in this OCCT build.** Tried, all reporting `BRepCheck_NoError`:
   - a standalone edge built fresh with no curve at all (zero representations)
   - a live box edge with its 3D curve removed via `BRep_Builder::UpdateEdge(edge,
     Handle(Geom_Curve)(), tol)`, both loose and still attached to the box's own faces
   - the same, with `GeometricControls(true)` set before `Minimum()`
   - the same, with the edge's parameter range shrunk to be inconsistent with its own vertices
     (`BRep_Builder::Range(edge, 0.0, 1.0, true)` on an edge whose vertices sit at parameters 0
     and 10)
   - a `Degenerated` flag forced `true` on an edge whose vertices are 10 units apart

   `InContext()`, which `checkSubShape` never calls, was also tried once (a box edge with its 3D
   curve removed, checked `InContext` of the owning face): it **crashed** (SIGSEGV) rather than
   reporting cleanly, consistent with CLAUDE.md's "OCC_CATCH_SIGNALS is inert in this build" note.
   That crash is not evidence of anything `checkSubShape` can reach (it never calls `InContext`);
   it only says a Minimum()-only checker is the safer contract, not an incomplete one.

3. **`BRepCheck_Vertex` similarly reports `NoError` for both an ordinary vertex and one built with
   a negative tolerance.** Its documented per-vertex faults (e.g. `InvalidPointOnCurve`) are raised
   by `InContext()`, which `checkSubShape` never calls either.

Conclusion: the `errorCount` fix in `checkSubShape` is correct and uniform across all four
callers (it is one shared helper), and is demonstrated by measurement on WIRE and SHELL. EDGE and
VERTEX could not be driven to a non-`NoError` status through the `Minimum()`-only path
`checkSubShape` uses, in this OCCT build, despite reasonable effort; this is a property of what
`BRepCheck_Edge`/`Vertex::Minimum()` check (largely nothing, without a context shape), not a
limitation of the fix. The regression test in
`Tests/OCCTTopologyTests/Issue2734CheckSubShapeErrorCountTests.swift` therefore covers `checkWire`
and `checkShell`.

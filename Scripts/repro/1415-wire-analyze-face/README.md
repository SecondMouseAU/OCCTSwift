# #1415: OCCTWireAnalyze's isClosed/hasSelfIntersection are always wrong

## Independently re-verified against the pinned kernel source/headers

- `ShapeAnalysis_Wire::Load(const TopoDS_Wire&)` (`ShapeAnalysis_Wire.cxx:134-138`): only ever sets
  `myWire = new ShapeExtend_WireData(wire);`. Never touches `myFace`. Confirmed by reading the
  function body directly.
- `ShapeAnalysis_Wire::IsReady()` (`ShapeAnalysis_Wire.lxx:27-30`): `return IsLoaded() &&
  !myFace.IsNull();`. Confirmed.
- `CheckClosed(prec)` (`ShapeAnalysis_Wire.cxx:470-476`) and `CheckSelfIntersection()`
  (`ShapeAnalysis_Wire.cxx:372-378`) both open with `if (!IsReady() || ...) return false;`.
  Confirmed.

## Live reproduction (`occt_1415_probe_before.mm`)

Exact replica of `OCCTWireAnalyze`'s pre-fix code path (declare a `TopoDS_Face face;`, never assign
it, `analyzer.Load(wire)`, no `SetFace`), run against the pinned `OCCT.xcframework` on the issue's
own definitively-open single-edge wire, `(0,0,0)` to `(10,0,0)`:

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  occt_1415_probe_before.mm -o /tmp/occt_1415_probe_before && /tmp/occt_1415_probe_before
```

```
wire.Closed() (TopoDS flag) = 0
IsReady()                   = 0
CheckClosed(tol)            = 0
bridge-computed isClosed    = 1   <-- for a wire that is NOT closed
CheckSelfIntersection()     = 0
```

Matches the issue's own reported transcript exactly. Confirmed live, not just traced.

## Ground-truthing the fix (`occt_1415_probe_after.mm`)

Two things were checked before picking a fix, not assumed:

1. **`BRepBuilderAPI_MakeFace(wire, true)` alone (the issue's first suggested option) does not fix
   `isClosed`, even when it succeeds.** `CheckClosed()`'s own header doc: "Returns: True if at
   least one check returned True [DONE]" — a `false` return is ambiguous between "genuinely closed"
   and "a sub-check FAILed outright" (no DONE bit, but no fixable problem identified either, e.g.
   endpoints genuinely far apart). Measured directly: an open two-edge polyline with endpoints ~11
   units apart, tolerance `1e-7`, *with* a real face set (`MakeFace` succeeds — it's planar), still
   has `CheckClosed(tol) == false`, so `!CheckClosed()` reads it as closed. So `isClosed` cannot be
   fixed by delegating to `CheckClosed()` at all, face or no face.
2. **`hasSelfIntersection` has no face-free alternative.** `CheckSelfIntersectingEdge`/
   `CheckIntersectingEdges` (`ShapeAnalysis_Wire.cxx:1269-1543`) both fetch each edge's *pcurve* via
   `ShapeAnalysis_Edge::PCurve(edge, myFace, ...)` and intersect those 2D curves — inherently
   projection-based, no 3D-only equivalent exists in this class. A face genuinely is required, and
   it has to be a face the wire's edges have (or can get) valid pcurves on, which is exactly what
   `BRepBuilderAPI_MakeFace(wire, /*OnlyPlane=*/true)` builds (already used for this exact purpose
   four times in `OCCTBridge_Healing_Blends.mm`: `OCCTWireFillet2D`, `OCCTWireFilletAll2D`, etc.).

## Fix implemented

- `hasSelfIntersection`: build a planar face via `BRepBuilderAPI_MakeFace(wire, true)` (matching
  established bridge precedent) and `SetFace` it on the analyzer when that succeeds. Only possible
  for an (approximately) planar wire; a non-planar wire leaves the analyzer without a face and
  `hasSelfIntersection` reports `false`, the same (undetectable, honest) limitation as before this
  fix for that case.
- `isClosed`: computed directly instead of via `ShapeAnalysis_Wire` at all —
  `TopoDS_Shape::Closed()` (the cheap flag `BRepBuilderAPI_MakeWire` sets when the wire's first and
  last vertices are literally the same `TopoDS_Vertex`) first, then a genuine 3D coincidence check
  on the wire's endpoints via `TopExp::Vertices` + `BRep_Tool::Pnt` (matching `OCCTWireVertices`'s
  own idiom in the same file group) for wires built by hand where the flag was never set. No face
  needed.

## Validation (`occt_1415_probe_after.mm`)

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  occt_1415_probe_after.mm -o /tmp/occt_1415_probe_after && /tmp/occt_1415_probe_after
```

All six cases correct, including the issue's own single-edge open-line reproducer:

| Case | isClosed | hasSelfIntersection |
|---|---|---|
| open single-edge line (the issue's own case) | 0 (correct) | 0 (correct) |
| closed planar rectangle | 1 (correct) | 0 (correct) |
| open planar polyline (L shape, endpoints far apart) | 0 (correct) | n/a |
| bowtie self-intersecting closed quad | 1 (correct) | 1 (correct) |
| circle wire | 1 (correct) | 0 (correct) |
| near-coincident-but-distinct-vertex endpoints, tol 1e-4 | 1 (correct) | n/a |

The bowtie case is the one that most directly proves the fix: before, both fields were wrong
(isClosed forced true regardless, hasSelfIntersection forced false regardless of the wire's real
self-intersection); after, both are correctly detected via the same real analyzer run.

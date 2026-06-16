---
title: Booleans
parent: Cookbook
nav_order: 1
---

# Booleans

Boolean operations combine two solids: **union** (fuse), **subtracting** (cut), and **intersection**
(common). In OCCTSwift they're methods on `Shape`, wrapping OCCT's `BRepAlgoAPI_Fuse` / `_Cut` /
`_Common`. Each is **fallible** (returns `Shape?`) — a degenerate or failed boolean yields `nil`.

OCCT C++ reference: [Boolean Operations user guide](https://dev.opencascade.org/doc/overview/html/specification__boolean_operations.html)
(`/open-cascade-sas/occt` on context7).

## The three operations

OCCT's one-liner `TopoDS_Shape S = BRepAlgoAPI_Fuse(A, B);` becomes — here a cube and a
cylinder passing through it:

```swift
guard let box = Shape.box(width: 10, height: 10, depth: 10),
      let cyl = Shape.cylinder(at: SIMD3(0, 0, -8), direction: SIMD3(0, 0, 1),
                               radius: 3, height: 16) else { return }

let fused = box.union(cyl)          // BRepAlgoAPI_Fuse   — A ∪ B  (box + protruding rod)
let cut = box.subtracting(cyl)      // BRepAlgoAPI_Cut    — A − B  (box with a through-hole)
let common = box.intersection(cyl)  // BRepAlgoAPI_Common — A ∩ B  (the rod stub inside the box)
```

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/booleans-union.glb" poster="images/booleans-union.png" camera-controls auto-rotate shadow-intensity="1" style="width:240px;height:220px;background:#f2f3f5;border-radius:6px"></model-viewer><br><code>union</code> (A ∪ B)</td>
<td align="center"><model-viewer src="models/booleans-cut.glb" poster="images/booleans-cut.png" camera-controls auto-rotate shadow-intensity="1" style="width:240px;height:220px;background:#f2f3f5;border-radius:6px"></model-viewer><br><code>subtracting</code> (A − B)</td>
<td align="center"><model-viewer src="models/booleans-common.glb" poster="images/booleans-common.png" camera-controls auto-rotate shadow-intensity="1" style="width:240px;height:220px;background:#f2f3f5;border-radius:6px"></model-viewer><br><code>intersection</code> (A ∩ B)</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. The static render shows until the 3D model loads. (Models exported straight from these snippets via `Exporter.writeGLTF`.)</sub>

Volumes confirm the result (note `volume` is `Double?` — `nil` for non-solids / failures):

```swift
guard let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10),
      let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) else { return }

a.union(b)?.volume        // 1500  (1000 + 1000 − 500 overlap)
a.intersection(b)?.volume // 500
a.subtracting(b)?.volume  // 500   (1000 − 500)
```

## Fuzzy value — tolerance for near-tangent faces

When operands share **near-coincident or near-tangent** faces, the exact boolean can produce
spurious slivers or fail. OCCT's fuzzy value (`SetFuzzyValue`) widens the intersection tolerance.
OCCT's C++ example sets `aFuzzyValue = 2.1e-5`; in OCCTSwift it's a parameter (default `0` = OCCT's
own default tolerance, negatives ignored):

```swift
// Two solids whose walls nearly coincide — a small fuzzy value lets them fuse cleanly.
let merged = outer.union(inner, fuzzyValue: 2.1e-5)
```

## Glue — coincident-face arguments

When you *know* the arguments share **coincident** faces (e.g. stacked blocks, consecutive loft
chunks sharing an end section), `glue` tells OCCT those faces touch instead of intersecting them —
a large robustness and speed win. Use it only when the faces really are coincident; gluing genuinely
interpenetrating solids gives a wrong result.

```swift
// Two unit cubes stacked along Z, sharing the face at z = 10.
guard let lower = Shape.box(origin: .zero, width: 10, height: 10, depth: 10),
      let upper = Shape.box(origin: SIMD3(0, 0, 10), width: 10, height: 10, depth: 10) else { return }

let stacked = lower.union(upper, glue: .shift)   // .off (default) / .shift / .full
// stacked.volume == 2000, a single shell
```

`BooleanGlue`: `.off` (default), `.shift` (`BOPAlgo_GlueShift` — shared faces, otherwise disjoint),
`.full` (`BOPAlgo_GlueFull` — all arguments coincident; fastest, strictest).

## Timeout — never hang on a pathological operand

A self-intersecting / inside-out operand can make a boolean **spin indefinitely**. Every boolean is
**wall-clock bounded** and returns `nil` at the deadline instead of hanging (default
`Shape.defaultBooleanTimeout` = 120 s; pass `0` to disable):

```swift
// Returns nil within ~5 s if the cut can't complete, rather than blocking forever.
let result = blank.subtracting(toolThatMightBeBad, timeout: 5)

// Opt out (unbounded, prior behaviour) for a known-heavy but valid boolean:
let heavy = assembly.union(part, timeout: 0)
```

The parameters compose: `a.subtracting(b, fuzzyValue: 1e-4, glue: .shift, timeout: 30)`.

## Validate an operand before a boolean

`isValidSolid` is a **topology** check — it does **not** catch global self-intersection (overlapping
faces of one solid), which is exactly what poisons a boolean. Screen operands with
`isSelfIntersecting(timeout:)` (returns `true` / `false` / `nil` = indeterminate). It's accurate but
**expensive** (seconds on B-spline solids), so it's opt-in:

```swift
switch solid.isSelfIntersecting(timeout: 30) {
case false: break    // clean — safe to use
case true:  return   // reject — would poison the boolean
case nil:   break    // indeterminate (timed out) — treat as unknown, decide per use case
}
```

### Recipe: trust a loft result before cutting with it

A `loft(ruled: false)` can return a self-intersecting solid that still reports
`isValidSolid == true` (see [issue #206](https://github.com/gsdali/OCCTSwift/issues/206)). Validate
at the source — fix a reversed orientation, then reject self-intersection:

```swift
guard let raw = Shape.loft(profiles: sections, solid: true, ruled: false),
      let solid = raw.orientedForward(),           // fix inward-facing (negative-volume) result
      solid.isSelfIntersecting() == false           // reject self-intersecting overshoot
else {
    // fall back (e.g. ruled: true, or a simpler profile correspondence)
    return
}
let part = stock.subtracting(solid)                 // now safe
```

## See also

- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts (B-Rep topology, handles): [`occt-concepts.md`](../occt-concepts.md)
- History recording across booleans: `unionWithFullHistory` / `subtractedWithFullHistory` (CHANGELOG v1.0.2).

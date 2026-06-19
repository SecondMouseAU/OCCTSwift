---
title: Healing & Validity
parent: Cookbook
nav_order: 6
---

# Healing & Validity

Imported CAD (STEP/IGES/STL) and the results of heavy modelling can carry defects: tiny edges,
gaps between faces, reversed orientation, self-intersections. OCCTSwift gives you a layered set of
**checks** to find problems and **repair** operations to fix them.

## Is it valid?

The cheapest check is topological validity:

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
box.isValid          // Bool — topology well-formed?
box.isValidSolid     // Bool — a closed, properly-oriented solid? (topology only)
```

`isValidSolid` is a **topology** check — it doesn't catch self-intersections. For that, run the
geometry-level check (it's bounded by a wall-clock timeout and returns `nil` if it can't decide in
time — don't treat `nil` as "clean"):

```swift
switch box.isSelfIntersecting(timeout: 30) {
case .some(true):  print("self-intersects")
case .some(false): print("clean")
case .none:        print("indeterminate (timed out)")
}
```

For a defect inventory rather than a yes/no, `analyze(tolerance:)` returns counts:

```swift
if let report = box.analyze(tolerance: 1e-3) {
    print(report.smallEdgeCount, report.gapCount,
          report.selfIntersectionCount, report.freeEdgeCount,
          report.hasInvalidTopology)
}
```

`analyzeValidity(geometryChecks:)` is a thorough single-Bool verdict (topology + optional geometry).

## Orientation: forward-facing solids

A solid built by `sweep`/`loft`/`revolve` can come out **inward-oriented** (its faces point the
wrong way), which breaks downstream booleans and `volume`. `signedVolume` reveals it — negative means
reversed — and `orientedForward()` fixes it:

```swift
let solid = Shape.sweep(profile: section, along: path)!
if solid.signedVolume < 0 {
    // faces point inward — flip them
}
let forward = solid.orientedForward()!   // outward-oriented; positive volume
```

`volume` returns the **absolute** value (or `nil` if invalid); `signedVolume` keeps the sign, so it
doubles as an orientation probe.

## Repairing defects

Several repair passes, from general to specific:

```swift
let healed   = shape.healed()                          // general-purpose fix-up
let fixed    = shape.fixed(tolerance: 1e-3)            // ShapeFix with per-component control
let solidsOnly = shape.fixed(tolerance: 1e-3, fixSolid: true,
                             fixShell: true, fixFace: true, fixWire: true)
let unified  = shape.unified()                         // merge co-planar faces / co-curve edges
let upgraded = shape.upgraded(tolerance: 1e-3)         // sew + make-solid + heal pipeline
```

- **`healed()`** — quick, general clean-up. Reach for this first.
- **`fixed(tolerance:…)`** — `ShapeFix_Shape` with per-component flags; raise `tolerance` to match the
  precision of imported data (e.g. `1e-3`, not the default `1e-6`).
- **`unified()`** — `ShapeUpgrade_UnifySameDomain`; the standard **post-boolean** cleanup that merges
  the redundant faces/edges a boolean leaves behind.

## Sewing faces into a shell

Disconnected faces (e.g. from a surface model or a mesh conversion) become a watertight shell by
**sewing** — matching up coincident edges within a tolerance:

```swift
// sew a list of faces into one shell
let shell = Shape.sew(shapes: faces, tolerance: 1e-6)

// or sew two shapes together
let joined = faceA.sewn(with: faceB, tolerance: 1e-6)

// or self-sew the disconnected faces already inside one shape
let stitched = shell?.sewn(tolerance: 1e-6)
```

Tolerance matters: too tight and coincident edges aren't matched (gaps remain); too loose and distinct
edges get merged. Match it to the data's precision.

## Finding and closing gaps

`freeBounds` reports the open edges of a shell — a watertight solid has none (returns `nil`):

```swift
if let bounds = shape.freeBounds(sewingTolerance: 1e-6) {
    print("open loops:", bounds.openCount, "closed loops:", bounds.closedCount)
    // there are gaps — try to close them:
    if let (closed, fixedCount) = shape.fixedFreeBounds(sewingTolerance: 1e-6,
                                                        closingTolerance: 1e-4) {
        print("closed \(fixedCount) gap(s)")
        _ = closed
    }
}
```

## A typical import-cleanup pipeline

```swift
let raw = try Shape.load(from: stepURL)              // imported geometry
guard raw.isValid else {
    let fixed = raw.fixed(tolerance: 1e-3)?           // repair
                   .orientedForward()                 // ensure outward solid
    // re-check, then proceed…
    return
}
```

## See also

- [Meshing & Export](meshing-and-export.md) — robust STL import sews/heals automatically.
- [Booleans](booleans.md) — `unified()` is the standard post-boolean cleanup.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts: [`occt-concepts.md`](../occt-concepts.md)

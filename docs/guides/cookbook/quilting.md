---
title: Quilting Faces
nav_order: 1
parent: Cookbook
---

# Quilting Faces

Quilting is the process of **joining faces that already share exact edges** into a single connected shell. Unlike sewing, quilting does **not** use a tolerance — it only merges edges that are already topologically identical (coincident vertices, coincident edges).

Use quilting when:
- You have faces from a CAD operation that should form a closed shell but are currently separate
- The faces already share exact edges (no tolerance needed)
- You need the full history mapping (`quiltWithFullHistory`)

For near-coincident faces that need a tolerance to merge, use [`sewn(tolerance:)`](../reference/Shape-Healing.md#sewntolerance) (which wraps `BRepBuilderAPI_Sewing`) instead.

---

## Basic Quilting

```swift
public static func quilt(_ shapes: [Shape]) -> Shape?
```

### Example: Quilting a Box from Six Faces

```swift
import OCCTSwift

// Create the six faces of a 10×10×10 box
let top    = Face.makePlane(width: 10, height: 10, origin: .zero, normal: SIMD3(0, 0, 1))
let bottom = Face.makePlane(width: 10, height: 10, origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, -1))
let left   = Face.makePlane(width: 10, height: 10, origin: .zero, normal: SIMD3(-1, 0, 0))
let right  = Face.makePlane(width: 10, height: 10, origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0))
let front  = Face.makePlane(width: 10, height: 10, origin: .zero, normal: SIMD3(0, -1, 0))
let back   = Face.makePlane(width: 10, height: 10, origin: SIMD3(0, 10, 0), normal: SIMD3(0, 1, 0))

guard let shell = Shape.quilt([top, bottom, left, right, front, back]) else {
    fatalError("Quilting failed — faces don't share edges perfectly")
}

// Verify we got a closed shell
assert(shell.isValid)
assert(shell.shells.count == 1)
```

---

## Quilting with Full History

```swift
public static func quiltWithFullHistory(_ shapes: [Shape]) -> (result: Shape, history: ShapeHistoryRef)?
```

Returns both the quilted shell **and** a `ShapeHistoryRef` that lets you query how each input face maps to the output.

### Example: Quilting with History Tracking

```swift
import OCCTSwift

let box = Shape.box(width: 10, height: 10, depth: 10)!
let faces = box.subShapes(ofType: .face)

guard let (shell, history) = Shape.quiltWithFullHistory(faces) else {
    fatalError("Quilting failed")
}

// Verify every input face is present in the result (not deleted)
for face in faces {
    let record = history.record(of: face)
    // The face should be Modified (present in output), not Deleted
    assert(!record.isDeleted, "Face \(face) was deleted during quilting")
    assert(record.isModified || record.isGenerated, "Face \(face) missing from result")
}
```

---

## Key Differences: Quilting vs Sewing

| Aspect | `Shape.quilt(_:)` | `Shape.sewn(tolerance:)` |
|--------|-------------------|---------------------------|
| **OCCT Class** | `BRepTools_Quilt` | `BRepBuilderAPI_Sewing` |
| **Tolerance** | None (exact edges only) | User-specified tolerance |
| **Use Case** | Faces already share exact edges | Near-coincident faces needing tolerance |
| **History** | `quiltWithFullHistory(_:)` | `sewnWithFullHistory(tolerance:)` |
| **Speed** | Faster (exact match) | Slower (tolerance search) |
| **Robustness** | Fails if edges don't match exactly | Merges near-coincident edges |

---

## Common Patterns

### Pattern: Building a Box from Faces

```swift
func boxFromFaces(width: Double, height: Double, depth: Double) -> Shape? {
    let halfW = width / 2, halfH = height / 2, halfD = depth / 2
    let origin = SIMD3(-halfW, -halfH, -halfD)
    
    let faces = [
        Face.makePlane(width: width, height: depth, origin: origin, normal: SIMD3(0, 0, -1)), // bottom
        Face.makePlane(width: width, height: depth, origin: SIMD3(-halfW, -halfH, halfD), normal: SIMD3(0, 0, 1)),  // top
        Face.makePlane(width: width, height: height, origin: SIMD3(-halfW, -halfH, -halfD), normal: SIMD3(-1, 0, 0)), // left
        Face.makePlane(width: width, height: height, origin: SIMD3(halfW, -halfH, -halfD), normal: SIMD3(1, 0, 0)),   // right
        Face.makePlane(width: depth, height: height, origin: SIMD3(-halfW, -halfH, -halfD), normal: SIMD3(0, -1, 0)), // front
        Face.makePlane(width: depth, height: height, origin: SIMD3(-halfW, halfH, -halfD), normal: SIMD3(0, 1, 0)),   // back
    ].compactMap { $0 }
    
    return Shape.quilt(faces)
}
```

### Pattern: Validating a Quilt Result

```swift
func validateQuilt(_ shell: Shape, expectedFaces: Int) -> Bool {
    guard shell.isValid,
          shell.shells.count == 1,
          shell.faces().count == expectedFaces else {
        return false
    }
    return true
}
```

---

## Troubleshooting

### Quilting Returns `nil`

| Cause | Fix |
|-------|-----|
| Faces don't share edges exactly | Use `sewn(tolerance:)` instead, or fix the input geometry |
| Faces have gaps between edges | Check face boundaries with `face.bounds()` |
| Faces have reversed orientation | Ensure adjacent faces have consistent orientation |
| Non-manifold edges (3+ faces sharing one edge) | Quilting requires manifold topology |

### Debugging Tips

```swift
// Check if faces share edges
for face in faces {
    let edges = face.edges()
    print("Face has \(edges.count) edges")
    for edge in edges {
        print("  Edge: \(edge.bounds)")
    }
}

// Verify faces are planar
for face in faces {
    guard let surface = face.surface() else { continue }
    print("Face surface type: \(surface)")
}
```

---

## Related

- [Sewing (sewn(tolerance:))](../reference/Shape-Healing.md#sewntolerance) — for near-coincident faces
- [Healing with History](healing-and-validity.md) — `healedWithFullHistory()`, `sewnWithFullHistory(tolerance:)`
- [API Reference: Shape.quilt](https://github.com/SecondMouseAU/OCCTSwift/blob/main/docs/API_REFERENCE.md) — Swift→OCCT mapping table
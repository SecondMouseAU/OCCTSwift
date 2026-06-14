// StressTestFixtures.swift
// Shared fixtures and helpers for OCCTSwift stress tests.
// No @Suite or @Test — only factory functions and assertion helpers.

import Foundation
import Testing
import OCCTSwift

// MARK: - Shape Fixtures

/// Fresh 10×10×10 box centered at origin.
func standardBox() -> Shape {
    Shape.box(width: 10, height: 10, depth: 10)!
}

/// Fresh cylinder r=5, h=10.
func standardCylinder() -> Shape {
    Shape.cylinder(radius: 5, height: 10)!
}

/// Fresh sphere r=5.
func standardSphere() -> Shape {
    Shape.sphere(radius: 5)!
}

/// Fresh cone r1=5, r2=2, h=10.
func standardCone() -> Shape {
    Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)!
}

/// Fresh torus R=10, r=3.
func standardTorus() -> Shape {
    Shape.torus(majorRadius: 10, minorRadius: 3)!
}

/// Box with r=1 fillet on all edges.
func filletedBox() -> Shape {
    let box = standardBox()
    return box.filleted(radius: 1.0) ?? box
}

/// 50×50×5 plate with r=3 through-hole at center.
func drilledPlate() -> Shape {
    let plate = Shape.box(width: 50, height: 50, depth: 5)!
    return plate.drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), radius: 3, depth: 0) ?? plate
}

/// Compound of box + offset cylinder.
func standardCompound() -> Shape {
    let box = standardBox()
    let cyl = standardCylinder()
    return box.union(with: cyl) ?? box
}

// MARK: - Wire Fixtures

/// 10×10 rectangle wire.
func standardWire() -> Wire {
    Wire.rectangle(width: 10, height: 10)!
}

// MARK: - Curve Fixtures

/// Circle curve in XY plane, r=5.
func standardCurve3D() -> Curve3D {
    Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
}

/// Circle curve in 2D, r=5.
func standardCurve2D() -> Curve2D {
    Curve2D.circle(center: SIMD2(0, 0), radius: 5)!
}

/// Interpolated 5-point cubic BSpline.
func standardBSplineCurve() -> Curve3D {
    Curve3D.interpolate(points: [
        SIMD3(0, 0, 0), SIMD3(3, 4, 0), SIMD3(8, 3, 0),
        SIMD3(12, 6, 0), SIMD3(15, 0, 0)
    ])!
}

// MARK: - Surface Fixtures

/// Plane through origin with Z-up normal.
func standardSurface() -> Surface {
    Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
}

/// 4×4 Bezier surface patch.
func standardBezierSurface() -> Surface {
    let poles: [[SIMD3<Double>]] = [
        [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0), SIMD3(15, 0, 0)],
        [SIMD3(0, 5, 0), SIMD3(5, 5, 2), SIMD3(10, 5, 2), SIMD3(15, 5, 0)],
        [SIMD3(0, 10, 0), SIMD3(5, 10, 2), SIMD3(10, 10, 2), SIMD3(15, 10, 0)],
        [SIMD3(0, 15, 0), SIMD3(5, 15, 0), SIMD3(10, 15, 0), SIMD3(15, 15, 0)]
    ]
    return Surface.bezier(poles: poles)!
}

// MARK: - Document Fixtures

/// XDE document with one box.
func standardDocument() -> Document {
    let doc = Document.create()!
    let box = standardBox()
    doc.addShape(box)
    return doc
}

// MARK: - File Helpers

/// Temp file URL with the given extension and a unique name.
func tempURL(_ ext: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("occt-stress-\(UUID().uuidString).\(ext)")
}

/// Remove a temp file, ignoring errors.
func cleanupTemp(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - All standard shape fixtures for matrix tests

/// All standard shape fixtures as (name, shape) pairs.
func allStandardShapes() -> [(String, Shape)] {
    var shapes: [(String, Shape)] = [
        ("box", standardBox()),
        ("cylinder", standardCylinder()),
        ("sphere", standardSphere()),
        ("cone", standardCone()),
        ("torus", standardTorus()),
        ("filletedBox", filletedBox()),
        ("drilledPlate", drilledPlate()),
        ("compound", standardCompound()),
    ]
    // Open shell (box shelled with -2mm thickness)
    if let shelled = standardBox().shelled(thickness: -2.0) {
        shapes.append(("openShell", shelled))
    }
    // Lofted solid
    if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
       let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
       let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2) {
        let loft = ThruSectionsBuilder(isSolid: true, isRuled: false)
        loft.addWire(s1)
        loft.addWire(s2)
        if loft.build(), let shape = loft.shape {
            shapes.append(("loftedSolid", shape))
        }
    }
    return shapes
}

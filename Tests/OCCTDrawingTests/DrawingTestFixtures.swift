// DrawingTestFixtures.swift
// Shared fixtures for OCCTDrawingTests.
// No @Suite or @Test: only shared helpers.

import simd

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// Ground-truth perpendicular basis constants shared by `Issue881DrawingPerpendicularBasisTests`
/// and `Issue1193CuttingPlaneDirectionTests`. Derived from OCCT's `gp_Ax2(gp_Pnt(0,0,0),
/// gp_Dir(nearDegenerate))` constructor measured against the pinned xcframework.
enum PerpendicularBasisGroundTruth {
    /// 15° in radians — chosen so the viewDirection is off-axis enough to exercise the
    /// fallback branch but not so extreme that numeric noise dominates.
    static let deg15 = 15.0 * Double.pi / 180.0
    
    /// A near-degenerate viewDirection 15° off the Z axis, with X/Y components in a 3:4
    /// ratio (0.6/0.8) to avoid any axis-aligned symmetry that might mask a basis bug.
    static let nearDegenerate = SIMD3<Double>(
        sin(deg15) * 0.6, sin(deg15) * 0.8, cos(deg15))
    
    /// OCCT's `gp_Ax2` `XDirection()` for the above viewDirection.
    static let expectedRight = SIMD3<Double>(
        0.0, 0.9777876596251666, -0.20959793101254465)
    
    /// OCCT's `gp_Ax2` `YDirection()` for the above viewDirection.
    static let expectedUp = SIMD3<Double>(
        -0.987868702146798, 0.03254876181607849, 0.1518420410263285)
}

/// Shared DXF group-code formatting helpers for golden-output tests.
///
/// These mirror `DXFExporter.swift`'s internal `pair(_:)` and `entities()` formatting
/// exactly so tests can assert precise coordinates by substring containment rather than
/// parsing the whole DXF text.
enum DXFTestFormat {
    /// Formats a double to the fixed precision used in DXF output.
    static func fmt(_ v: Double) -> String { String(format: "%.6f", v) }
    
    /// A single DXF group code / value pair (e.g. "10\n1.234567\n").
    static func pair(_ code: Int, _ value: String) -> String { "\(code)\n\(value)\n" }
    
    /// The full coordinate block for a `LINE` entity (group codes 10,20,30,11,21,31).
    static func lineCoordinateBlock(from a: SIMD2<Double>, to b: SIMD2<Double>) -> String {
        pair(10, fmt(a.x)) + pair(20, fmt(a.y)) + pair(30, fmt(0.0))
            + pair(11, fmt(b.x)) + pair(21, fmt(b.y)) + pair(31, fmt(0.0))
    }
    
    /// A complete `LINE` entity block including header, layer, and coordinates.
    static func lineEntity(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String) -> String {
        pair(0, "LINE") + pair(8, layer) + lineCoordinateBlock(from: a, to: b)
    }
    
    /// The coordinate + height + text block for a `TEXT` entity (group codes 10,20,30,40,1,50).
    static func textEntity(at p: SIMD2<Double>, label: String, height: Double = 3.5, rotationDeg: Double = 0) -> String {
        pair(10, fmt(p.x)) + pair(20, fmt(p.y)) + pair(30, fmt(0.0))
            + pair(40, fmt(height)) + pair(1, label) + pair(50, fmt(rotationDeg))
    }
}

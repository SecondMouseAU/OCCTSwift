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

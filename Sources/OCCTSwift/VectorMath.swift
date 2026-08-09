import Foundation
import simd
import OCCTBridge

/// 2D vector math utilities wrapping gp_XY.
public enum Vector2DMath {
    /// Length of a 2D vector.
    public static func modulus(_ v: SIMD2<Double>) -> Double { OCCTXYModulus(v.x, v.y) }
    /// 2D cross product (scalar).
    public static func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { OCCTXYCrossed(a.x, a.y, b.x, b.y) }
    /// 2D dot product.
    public static func dot(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { OCCTXYDot(a.x, a.y, b.x, b.y) }
    /// Normalize a 2D vector.
    public static func normalize(_ v: SIMD2<Double>) -> SIMD2<Double>? {
        var rx = 0.0, ry = 0.0
        guard OCCTXYNormalize(v.x, v.y, &rx, &ry) else { return nil }
        return SIMD2(rx, ry)
    }
}

/// 3D vector math utilities wrapping gp_XYZ.
public enum Vector3DMath {
    /// Length of a 3D vector.
    public static func modulus(_ v: SIMD3<Double>) -> Double { OCCTXYZModulus(v.x, v.y, v.z) }
    /// 3D cross product.
    public static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        var rx = 0.0, ry = 0.0, rz = 0.0
        OCCTXYZCrossed(a.x, a.y, a.z, b.x, b.y, b.z, &rx, &ry, &rz)
        return SIMD3(rx, ry, rz)
    }
    /// 3D dot product.
    public static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { OCCTXYZDot(a.x, a.y, a.z, b.x, b.y, b.z) }
    /// Scalar triple product a . (b x c).
    public static func dotCross(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) -> Double {
        OCCTXYZDotCross(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z)
    }
    /// Normalize a 3D vector.
    public static func normalize(_ v: SIMD3<Double>) -> SIMD3<Double>? {
        var rx = 0.0, ry = 0.0, rz = 0.0
        guard OCCTXYZNormalize(v.x, v.y, v.z, &rx, &ry, &rz) else { return nil }
        return SIMD3(rx, ry, rz)
    }
}

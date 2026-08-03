import Foundation
import simd
import OCCTBridge

/// Analytic quadric-quadric intersection.
public enum QuadricIntersection {
    /// Intersect a cylinder (Z-axis, given radius) with a sphere. Returns curve count, or nil on failure.
    public static func cylinderSphere(cylinderRadius: Double,
                                       sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                       tolerance: Double = 1e-6) -> Int? {
        let n = Int(OCCTIntAnaCylinderSphere(cylinderRadius,
                                               sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                               sphereRadius, tolerance))
        return n >= 0 ? n : nil
    }

    /// Check if cylinder and sphere surfaces are identical.
    public static func cylinderSphereIdentical(cylinderRadius: Double,
                                                sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                                tolerance: Double = 1e-6) -> Bool {
        OCCTIntAnaCylinderSphereIdentical(cylinderRadius,
                                            sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                            sphereRadius, tolerance)
    }
}

extension QuadricIntersection {
    /// Intersect a cone (Z-axis, given semi-angle and ref radius) with a sphere.
    /// Returns curve count, or nil on error. Returns -2 encoded as nil for identical.
    public static func coneSphere(semiAngle: Double, refRadius: Double,
                                   sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                   tolerance: Double = 1e-6) -> Int? {
        let n = Int(OCCTIntAnaConeSphere(semiAngle, refRadius,
                                          sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                          sphereRadius, tolerance))
        return n >= 0 ? n : nil
    }

    /// Sample points along a cone-sphere intersection curve.
    ///
    /// - Parameter sampleCount: Desired number of samples, honoured within `1...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    public static func coneSpherePoints(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6,
                                         curveIndex: Int, sampleCount: Int) -> [SIMD3<Double>] {
        guard let sampleCount = Sampling.requested(sampleCount, atLeast: 1) else { return [] }
        var xs = [Double](repeating: 0, count: sampleCount)
        var ys = [Double](repeating: 0, count: sampleCount)
        var zs = [Double](repeating: 0, count: sampleCount)
        let actual = Int(OCCTIntAnaConeSpherePoints(semiAngle, refRadius,
                                                      sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                                      sphereRadius, tolerance,
                                                      Int32(curveIndex), Int32(sampleCount),
                                                      &xs, &ys, &zs))
        return (0..<actual).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Check if a cone-sphere intersection curve is open.
    public static func coneSphereIsOpen(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6, curveIndex: Int) -> Bool {
        OCCTIntAnaConeSphereIsOpen(semiAngle, refRadius,
                                    sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                    sphereRadius, tolerance, Int32(curveIndex))
    }

    /// Get the domain of a cone-sphere intersection curve.
    public static func coneSphereDomain(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6, curveIndex: Int) -> ClosedRange<Double> {
        var first = 0.0, last = 0.0
        OCCTIntAnaConeSphereGetDomain(semiAngle, refRadius,
                                       sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                       sphereRadius, tolerance, Int32(curveIndex),
                                       &first, &last)
        return first...last
    }
}

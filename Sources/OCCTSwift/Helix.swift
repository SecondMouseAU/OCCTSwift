import Foundation
import OCCTBridge
import simd

/// Helix curve construction using OCCT HelixGeom classes (rc4).
public enum Helix {

    /// Result of a helix build operation.
    public struct BuildResult: Sendable {
        public let curve: Curve3D
        public let toleranceReached: Double
    }

    /// Build a helix curve approximated as BSpline.
    /// - Parameters:
    ///   - origin: Center point of the helix base
    ///   - direction: Axis direction of the helix
    ///   - xDirection: X direction for the starting position
    ///   - parameterRange: Parameter range (t1...t2)
    ///   - pitch: Helix pitch (distance per revolution)
    ///   - radius: Starting radius
    ///   - taperAngle: Taper angle in radians (0 for constant radius)
    ///   - isClockwise: Whether the helix winds clockwise
    ///   - tolerance: Approximation tolerance
    /// - Returns: The built helix curve with tolerance info, or nil on failure
    public static func build(
        origin: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        xDirection: SIMD3<Double> = SIMD3(1, 0, 0),
        parameterRange: ClosedRange<Double>,
        pitch: Double,
        radius: Double,
        taperAngle: Double = 0,
        isClockwise: Bool = false,
        tolerance: Double = 0.001
    ) -> BuildResult? {
        var tolReached = 0.0
        guard
            let ref = OCCTHelixBuild(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                xDirection.x, xDirection.y, xDirection.z,
                parameterRange.lowerBound, parameterRange.upperBound,
                pitch, radius, taperAngle, isClockwise,
                tolerance, &tolReached
            )
        else { return nil }
        return BuildResult(curve: Curve3D(handle: ref), toleranceReached: tolReached)
    }

    /// Build a helix coil (closed-loop helix, no position needed).
    public static func buildCoil(
        parameterRange: ClosedRange<Double>,
        pitch: Double,
        radius: Double,
        taperAngle: Double = 0,
        isClockwise: Bool = false,
        tolerance: Double = 0.001
    ) -> BuildResult? {
        var tolReached = 0.0
        guard
            let ref = OCCTHelixCoilBuild(
                parameterRange.lowerBound, parameterRange.upperBound,
                pitch, radius, taperAngle, isClockwise,
                tolerance, &tolReached
            )
        else { return nil }
        return BuildResult(curve: Curve3D(handle: ref), toleranceReached: tolReached)
    }

    /// Evaluate a helix curve at parameter u.
    public static func evaluate(
        parameterRange: ClosedRange<Double>,
        pitch: Double, radius: Double,
        taperAngle: Double = 0, isClockwise: Bool = false,
        at u: Double
    ) -> SIMD3<Double> {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        OCCTHelixCurveEval(
            parameterRange.lowerBound, parameterRange.upperBound,
            pitch, radius, taperAngle, isClockwise, u, &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate helix D1 (point + tangent) at parameter u.
    public static func evaluateD1(
        parameterRange: ClosedRange<Double>,
        pitch: Double, radius: Double,
        taperAngle: Double = 0, isClockwise: Bool = false,
        at u: Double
    ) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var vx = 0.0
        var vy = 0.0
        var vz = 0.0
        OCCTHelixCurveD1(
            parameterRange.lowerBound, parameterRange.upperBound,
            pitch, radius, taperAngle, isClockwise, u,
            &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate helix D2 (point + 1st + 2nd derivative) at parameter u.
    public static func evaluateD2(
        parameterRange: ClosedRange<Double>,
        pitch: Double, radius: Double,
        taperAngle: Double = 0, isClockwise: Bool = false,
        at u: Double
    ) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var v1x = 0.0
        var v1y = 0.0
        var v1z = 0.0
        var v2x = 0.0
        var v2y = 0.0
        var v2z = 0.0
        OCCTHelixCurveD2(
            parameterRange.lowerBound, parameterRange.upperBound,
            pitch, radius, taperAngle, isClockwise, u,
            &px, &py, &pz, &v1x, &v1y, &v1z, &v2x, &v2y, &v2z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z), SIMD3(v2x, v2y, v2z))
    }

    /// Approximate a helix directly to a BSpline curve.
    public static func approximateToBSpline(
        parameterRange: ClosedRange<Double>,
        pitch: Double, radius: Double,
        taperAngle: Double = 0, isClockwise: Bool = false,
        tolerance: Double = 0.001
    ) -> (curve: Curve3D, maxError: Double)? {
        var maxError = 0.0
        guard
            let ref = OCCTHelixApproxToBSpline(
                parameterRange.lowerBound, parameterRange.upperBound,
                pitch, radius, taperAngle, isClockwise,
                tolerance, &maxError
            )
        else { return nil }
        return (Curve3D(handle: ref), maxError)
    }
}

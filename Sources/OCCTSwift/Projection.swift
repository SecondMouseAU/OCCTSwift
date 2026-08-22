import Foundation
import OCCTBridge
import simd

/// Multi-result projection of a point onto a 3D curve.
public final class ProjectionOnCurve: @unchecked Sendable {
    private let ref: OCCTProjOnCurveRef

    /// Create a projection of a point onto a curve.
    public init?(curve: Curve3D, point: SIMD3<Double>) {
        guard let r = OCCTProjOnCurveCreate(curve.handle, point.x, point.y, point.z) else {
            return nil
        }
        self.ref = r
    }

    deinit { OCCTProjOnCurveRelease(ref) }

    /// Number of projection results.
    public var count: Int { Int(OCCTProjOnCurveNbPoints(ref)) }

    /// Get the i-th projection point (0-based index).
    public func point(at index: Int) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTProjOnCurvePoint(ref, Int32(index + 1), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the parameter of the i-th projection (0-based).
    public func parameter(at index: Int) -> Double {
        OCCTProjOnCurveParameter(ref, Int32(index + 1))
    }

    /// Get the distance of the i-th projection (0-based).
    public func distance(at index: Int) -> Double {
        OCCTProjOnCurveDistance(ref, Int32(index + 1))
    }

    /// Minimum distance across all projections.
    public var lowerDistance: Double { OCCTProjOnCurveLowerDistance(ref) }

    /// Parameter of the nearest projection.
    public var lowerParameter: Double { OCCTProjOnCurveLowerParam(ref) }
}

/// Multi-result projection of a point onto a surface.
public final class ProjectionOnSurface: @unchecked Sendable {
    private let ref: OCCTProjOnSurfRef

    /// Create a projection of a point onto a surface.
    public init?(surface: Surface, point: SIMD3<Double>) {
        guard let r = OCCTProjOnSurfCreate(surface.handle, point.x, point.y, point.z) else {
            return nil
        }
        self.ref = r
    }

    deinit { OCCTProjOnSurfRelease(ref) }

    /// Number of projection results.
    public var count: Int { Int(OCCTProjOnSurfNbPoints(ref)) }

    /// Get the i-th projection point (0-based index).
    public func point(at index: Int) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTProjOnSurfPoint(ref, Int32(index + 1), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the (u,v) parameters of the i-th projection (0-based).
    public func parameters(at index: Int) -> (u: Double, v: Double) {
        var u = 0.0
        var v = 0.0
        OCCTProjOnSurfParameters(ref, Int32(index + 1), &u, &v)
        return (u, v)
    }

    /// Get the distance of the i-th projection (0-based).
    public func distance(at index: Int) -> Double {
        OCCTProjOnSurfDistance(ref, Int32(index + 1))
    }

    /// Minimum distance across all projections.
    public var lowerDistance: Double { OCCTProjOnSurfLowerDistance(ref) }

    /// (u,v) parameters of the nearest projection.
    public var lowerParameters: (u: Double, v: Double) {
        var u = 0.0
        var v = 0.0
        OCCTProjOnSurfLowerParams(ref, &u, &v)
        return (u, v)
    }
}

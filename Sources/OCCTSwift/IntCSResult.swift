import Foundation
import simd
import OCCTBridge

/// Full multi-result curve-surface intersection using GeomAPI_IntCS.
public final class IntCSResult: @unchecked Sendable {
    private let ref: OCCTIntCSRef

    /// Compute intersections between a curve and a surface.
    public init?(curve: Curve3D, surface: Surface) {
        guard let r = OCCTIntCSCreate(curve.handle, surface.handle) else { return nil }
        self.ref = r
    }

    deinit { OCCTIntCSRelease(ref) }

    /// Number of intersection points.
    public var pointCount: Int { Int(OCCTIntCSNbPoints(ref)) }

    /// Number of intersection segments.
    public var segmentCount: Int { Int(OCCTIntCSNbSegments(ref)) }

    /// Intersection point result.
    public struct IntersectionPoint: Sendable {
        public let point: SIMD3<Double>
        public let curveParam: Double
        public let surfaceU: Double
        public let surfaceV: Double
    }

    /// Get the i-th intersection point (0-based).
    public func point(at index: Int) -> IntersectionPoint {
        var x = 0.0, y = 0.0, z = 0.0, w = 0.0, u = 0.0, v = 0.0
        OCCTIntCSPoint(ref, Int32(index + 1), &x, &y, &z, &w, &u, &v)
        return IntersectionPoint(point: SIMD3(x, y, z), curveParam: w, surfaceU: u, surfaceV: v)
    }
}

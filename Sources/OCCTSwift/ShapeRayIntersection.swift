import Foundation
import simd
import OCCTBridge

/// Iterator for line/curve–shape intersection results.
public final class ShapeRayIntersection: @unchecked Sendable {
    let handle: OCCTCurveSurfaceInterRef

    /// A single intersection hit.
    public struct Hit {
        public let x: Double, y: Double, z: Double
        public let u: Double, v: Double
        public let w: Double
    }

    /// Create intersection of a line with a shape.
    public init?(shape: Shape, originX: Double, originY: Double, originZ: Double,
                 dirX: Double, dirY: Double, dirZ: Double, tolerance: Double = 1e-6) {
        guard let h = OCCTCurveSurfaceInterCreateLine(
            shape.handle, originX, originY, originZ, dirX, dirY, dirZ, tolerance) else { return nil }
        self.handle = h
    }

    /// Create intersection of a curve with a shape.
    public init?(shape: Shape, curve: Curve3D, tolerance: Double = 1e-6) {
        guard let h = OCCTCurveSurfaceInterCreateCurve(shape.handle, curve.handle, tolerance) else { return nil }
        self.handle = h
    }

    deinit { OCCTCurveSurfaceInterRelease(handle) }

    /// Check if more results are available.
    public var hasMore: Bool { OCCTCurveSurfaceInterMore(handle) }

    /// Advance to next result.
    public func next() { OCCTCurveSurfaceInterNext(handle) }

    /// Get current hit data.
    public var currentHit: Hit {
        let h = OCCTCurveSurfaceInterHit(handle)
        return Hit(x: h.x, y: h.y, z: h.z, u: h.u, v: h.v, w: h.w)
    }

    /// Get face at current hit.
    public var currentFace: Face? {
        guard let f = OCCTCurveSurfaceInterFace(handle) else { return nil }
        return Face(handle: f)
    }

    /// Collect all hits.
    public func allHits() -> [Hit] {
        var hits: [Hit] = []
        while hasMore {
            hits.append(currentHit)
            next()
        }
        return hits
    }
}

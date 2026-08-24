import Foundation
import OCCTBridge
import simd

/// Bounding sphere for spatial queries.
public final class BoundingSphere: @unchecked Sendable {
    private let ref: OCCTBndSphereRef

    public init(center: SIMD3<Double>, radius: Double) {
        ref = OCCTBndSphereCreate(center.x, center.y, center.z, radius)
    }

    deinit { OCCTBndSphereRelease(ref) }

    public var radius: Double { OCCTBndSphereRadius(ref) }

    public var center: SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTBndSphereCenter(ref, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Distance from sphere center to point.
    public func distance(to point: SIMD3<Double>) -> Double {
        OCCTBndSphereDistance(ref, point.x, point.y, point.z)
    }

    /// Check if point is outside sphere.
    public func isOutside(_ point: SIMD3<Double>) -> Bool {
        OCCTBndSphereIsOut(ref, point.x, point.y, point.z)
    }

    /// Check if another sphere is disjoint.
    public func isOutside(_ other: BoundingSphere) -> Bool {
        OCCTBndSphereIsOutSphere(ref, other.ref)
    }

    /// Merge (expand to contain) another sphere.
    public func add(_ other: BoundingSphere) {
        OCCTBndSphereAdd(ref, other.ref)
    }
}

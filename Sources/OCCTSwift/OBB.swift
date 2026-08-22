import Foundation
import OCCTBridge
import simd

/// Oriented bounding box in 3D space.
public final class OBB: @unchecked Sendable {
    let handle: OCCTOBBRef

    init(handle: OCCTOBBRef) { self.handle = handle }

    deinit { OCCTOBBRelease(handle) }

    /// Create an OBB from center, axes, and half-sizes.
    public init(
        center: SIMD3<Double>, xDir: SIMD3<Double>, yDir: SIMD3<Double>, zDir: SIMD3<Double>,
        hx: Double, hy: Double, hz: Double
    ) {
        handle = OCCTOBBCreate(
            center.x, center.y, center.z,
            xDir.x, xDir.y, xDir.z,
            yDir.x, yDir.y, yDir.z,
            zDir.x, zDir.y, zDir.z,
            hx, hy, hz)
    }

    /// Create an OBB from a shape's bounding box.
    public static func fromShape(_ shape: Shape) -> OBB? {
        guard let ref = OCCTOBBCreateFromShape(shape.handle) else { return nil }
        return OBB(handle: ref)
    }

    /// Whether the OBB is void (empty).
    public var isVoid: Bool { OCCTOBBIsVoid(handle) }

    /// Center of the OBB.
    public var center: SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTOBBGetCenter(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Half-sizes of the OBB along its local axes.
    public var halfSizes: SIMD3<Double> {
        var hx = 0.0
        var hy = 0.0
        var hz = 0.0
        OCCTOBBGetHalfSizes(handle, &hx, &hy, &hz)
        return SIMD3(hx, hy, hz)
    }

    /// Check if a point is outside the OBB.
    public func isOut(point: SIMD3<Double>) -> Bool {
        OCCTOBBIsOutPoint(handle, point.x, point.y, point.z)
    }

    /// Check if another OBB is outside (no overlap).
    public func isOut(_ other: OBB) -> Bool {
        OCCTOBBIsOutOBB(handle, other.handle)
    }

    /// Enlarge the OBB by a gap value on all sides.
    public func enlarge(by gap: Double) {
        OCCTOBBEnlarge(handle, gap)
    }

    /// Square extent (diagonal squared).
    public var squareExtent: Double { OCCTOBBSquareExtent(handle) }
}

import Foundation
import OCCTBridge
import simd

/// A 2D axis placement backed by Geom2d_AxisPlacement.
///
/// Represents a coordinate system defined by an origin point and a direction vector.
public final class AxisPlacement2D: @unchecked Sendable {
    internal let handle: OCCTAxisPlacement2DRef

    internal init(handle: OCCTAxisPlacement2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTAxisPlacement2DRelease(handle)
    }

    // MARK: - Creation

    /// Create a 2D axis placement from origin and direction.
    public init?(origin: SIMD2<Double>, direction: SIMD2<Double>) {
        guard
            let h = OCCTAxisPlacement2DCreate(
                origin.x, origin.y,
                direction.x, direction.y)
        else { return nil }
        self.handle = h
    }

    // MARK: - Properties

    /// The origin of the axis.
    public var origin: SIMD2<Double> {
        var x: Double = 0
        var y: Double = 0
        OCCTAxisPlacement2DGetOrigin(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// The direction of the axis.
    public var direction: SIMD2<Double> {
        var x: Double = 0
        var y: Double = 0
        OCCTAxisPlacement2DGetDirection(handle, &x, &y)
        return SIMD2(x, y)
    }

    // MARK: - Operations

    /// Create a reversed axis (opposite direction, same origin).
    public func reversed() -> AxisPlacement2D? {
        guard let h = OCCTAxisPlacement2DReversed(handle) else { return nil }
        return AxisPlacement2D(handle: h)
    }

    /// Angle between this axis and another (radians).
    public func angle(to other: AxisPlacement2D) -> Double {
        OCCTAxisPlacement2DAngle(handle, other.handle)
    }
}

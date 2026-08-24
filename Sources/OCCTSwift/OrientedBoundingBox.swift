import Foundation
import OCCTBridge
import simd

/// An oriented (rotated) bounding box that fits tightly around a shape.
public struct OrientedBoundingBox: Sendable {
    /// Center of the bounding box.
    public var center: SIMD3<Double>
    /// X-axis direction of the box.
    public var xDirection: SIMD3<Double>
    /// Y-axis direction of the box.
    public var yDirection: SIMD3<Double>
    /// Z-axis direction of the box.
    public var zDirection: SIMD3<Double>
    /// Half-dimensions along each axis.
    public var halfSizes: SIMD3<Double>

    /// Volume of the bounding box.
    public var volume: Double { 8.0 * halfSizes.x * halfSizes.y * halfSizes.z }

    /// Full dimensions of the bounding box.
    public var dimensions: SIMD3<Double> { 2.0 * halfSizes }
}

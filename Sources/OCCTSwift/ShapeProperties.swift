import OCCTBridge
import OCCTPlatform

/// Mass and geometric properties of a shape.
public struct ShapeProperties: Sendable, Equatable {
    /// Volume in cubic units.
    public var volume: Double

    /// Surface area in square units.
    public var surfaceArea: Double

    /// Mass (volume × density).
    public var mass: Double

    /// Center of mass location.
    public var centerOfMass: SIMD3<Double>

    /// Moment of inertia tensor (3x3 matrix).
    public var momentOfInertia: Matrix3x3D

    public init(
        volume: Double,
        surfaceArea: Double,
        mass: Double,
        centerOfMass: SIMD3<Double>,
        momentOfInertia: Matrix3x3D
    ) {
        self.volume = volume
        self.surfaceArea = surfaceArea
        self.mass = mass
        self.centerOfMass = centerOfMass
        self.momentOfInertia = momentOfInertia
    }
}

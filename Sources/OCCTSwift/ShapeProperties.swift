import Foundation
import OCCTBridge
import simd

/// Mass and geometric properties of a shape
public struct ShapeProperties: Sendable, Equatable {
    /// Volume in cubic units
    public var volume: Double

    /// Surface area in square units
    public var surfaceArea: Double

    /// Mass (volume × density)
    public var mass: Double

    /// Center of mass location
    public var centerOfMass: SIMD3<Double>

    /// Moment of inertia tensor (3x3 matrix)
    public var momentOfInertia: simd_double3x3

    public init(
        volume: Double,
        surfaceArea: Double,
        mass: Double,
        centerOfMass: SIMD3<Double>,
        momentOfInertia: simd_double3x3
    ) {
        self.volume = volume
        self.surfaceArea = surfaceArea
        self.mass = mass
        self.centerOfMass = centerOfMass
        self.momentOfInertia = momentOfInertia
    }
}

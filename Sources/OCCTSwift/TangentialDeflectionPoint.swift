import Foundation
import OCCTBridge
import simd

/// A sampled point from tangential deflection.
public struct TangentialDeflectionPoint {
    public let parameter: Double
    public let x: Double, y: Double, z: Double
}

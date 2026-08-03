import Foundation
import simd
import OCCTBridge

/// Coordinate system for mesh I/O.
public enum CoordinateSystem: Int32, Sendable {
    case zUp = 0
    case yUp = 1
}

/// Convert a 3D point between coordinate systems with unit scaling.
public func convertCoordinateSystem(x: Double, y: Double, z: Double,
                                     from inputSystem: CoordinateSystem,
                                     inputUnit: Double,
                                     to outputSystem: CoordinateSystem,
                                     outputUnit: Double) -> SIMD3<Double> {
    let r = OCCTCoordSystemConvert(x, y, z, inputSystem.rawValue, inputUnit,
                                    outputSystem.rawValue, outputUnit)
    return SIMD3(r.x, r.y, r.z)
}

/// Get the up direction for a coordinate system.
public func coordinateSystemUpDirection(_ system: CoordinateSystem) -> SIMD3<Double> {
    let r = OCCTCoordSystemUpDirection(system.rawValue)
    return SIMD3(r.x, r.y, r.z)
}

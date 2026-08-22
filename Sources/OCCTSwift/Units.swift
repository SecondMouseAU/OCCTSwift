import Foundation
import OCCTBridge
import simd

/// Unit conversion utilities wrapping OCCT UnitsAPI.
public enum Units: Sendable {
    /// Convert a value between any two units (e.g., "mm" to "m", "deg" to "rad").
    public static func convert(_ value: Double, from fromUnit: String, to toUnit: String) -> Double
    {
        OCCTUnitsAnyToAny(value, fromUnit, toUnit)
    }

    /// Convert a value from any unit to SI base unit.
    public static func toSI(_ value: Double, from unit: String) -> Double {
        OCCTUnitsAnyToSI(value, unit)
    }

    /// Convert a value from SI base unit to any unit.
    public static func fromSI(_ value: Double, to unit: String) -> Double {
        OCCTUnitsAnyFromSI(value, unit)
    }

    /// Convert a value from any unit to local system.
    public static func toLocalSystem(_ value: Double, from unit: String) -> Double {
        OCCTUnitsAnyToLS(value, unit)
    }

    /// Convert a value from local system to any unit.
    public static func fromLocalSystem(_ value: Double, to unit: String) -> Double {
        OCCTUnitsAnyFromLS(value, unit)
    }

    /// Unit system type.
    public enum SystemType: Int32, Sendable {
        case defaultSystem = 0
        case si = 1
        case mdtv = 2
    }

    /// Set the local unit system.
    public static func setLocalSystem(_ system: SystemType) {
        OCCTUnitsSetLocalSystem(system.rawValue)
    }

    /// Get the current local unit system.
    public static var localSystem: SystemType {
        SystemType(rawValue: OCCTUnitsGetLocalSystem()) ?? .defaultSystem
    }
}

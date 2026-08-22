import Foundation
import OCCTBridge
import simd

/// Length unit types matching OCCT UnitsMethods_LengthUnit enum.
public enum OCCTLengthUnit: Int32, Sendable {
    case undefined = 0
    case inch = 1
    case millimeter = 2
    case foot = 4
    case mile = 5
    case meter = 6
    case kilometer = 7
    case mil = 8
    case micron = 9
    case centimeter = 10
    case microinch = 11
}

/// Utility for unit conversions using OCCT UnitsMethods.
public enum UnitsConversion {

    /// Get the length factor for an IGES unit code (in millimeters).
    public static func lengthFactor(igesUnit: Int) -> Double {
        OCCTUnitsGetLengthFactor(Int32(igesUnit))
    }

    /// Get the scale factor to convert between two length units.
    public static func lengthUnitScale(from: OCCTLengthUnit, to: OCCTLengthUnit) -> Double {
        OCCTUnitsGetLengthUnitScale(from.rawValue, to.rawValue)
    }

    /// Get the string name for a length unit.
    public static func dumpLengthUnit(_ unit: OCCTLengthUnit) -> String? {
        guard let cStr = OCCTUnitsDumpLengthUnit(unit.rawValue) else { return nil }
        return String(cString: cStr)
    }
}

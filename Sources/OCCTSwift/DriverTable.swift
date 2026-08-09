import Foundation
import simd
import OCCTBridge

/// Presentation driver table (global singleton for OCAF presentation drivers).
public enum DriverTable: Sendable {
    /// Initialize the global driver table with standard drivers.
    public static func initStandard() {
        OCCTDriverTableInitStandard()
    }

    /// Check if the global driver table exists.
    public static var exists: Bool {
        OCCTDriverTableExists()
    }

    /// Clear all drivers from the global table.
    public static func clear() {
        OCCTDriverTableClear()
    }
}

/// Global function driver registry.
public enum FunctionDriverTable {

    /// Check if a function driver with the given GUID is registered.
    public static func hasDriver(guid: String) -> Bool {
        OCCTFunctionDriverTableHasDriver(guid)
    }

    /// Clear all registered function drivers.
    public static func clear() {
        OCCTFunctionDriverTableClear()
    }
}

import Foundation
import OCCTBridge
import simd

/// Presentation driver table (global singleton for OCAF presentation drivers).
public enum DriverTable: Sendable {
    /// Initialize the global driver table with standard drivers.
    public static func initStandard() {
        OCCTDriverTableInitStandard()
    }

    /// Always `true`: querying this lazily creates and populates the global
    /// driver table if it does not already exist.
    ///
    /// This mirrors `TPrsStd_DriverTable::Get()` exactly, whose own header
    /// doc says "Returns the static table. If it does not exist, creates it
    /// and fills it with standard drivers." There is no OCCT API that reports
    /// whether the table has been created without also creating it, so this
    /// property can never observe (or produce) a "not yet created" state:
    /// reading it is itself the side effect. Use it to guarantee the table is
    /// present before relying on it, not to test whether some earlier code
    /// already initialized one.
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

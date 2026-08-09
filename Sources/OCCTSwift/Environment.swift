import Foundation
import simd
import OCCTBridge

/// Environment variable access.
public enum Environment {

    /// Get the value of an environment variable.
    public static func get(_ name: String) -> String? {
        guard let ptr = OCCTEnvironmentGet(name) else { return nil }
        defer { OCCTEnvironmentFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Set an environment variable.
    @discardableResult
    public static func set(_ name: String, value: String) -> Bool {
        OCCTEnvironmentSet(name, value)
    }

    /// Remove an environment variable.
    public static func remove(_ name: String) {
        OCCTEnvironmentRemove(name)
    }
}

import Foundation
import simd
import OCCTBridge

/// Process information utilities.
public enum ProcessInfo {

    /// Get current process ID.
    public static var processId: Int { Int(OCCTProcessId()) }

    /// Get current username.
    public static var userName: String? {
        guard let ptr = OCCTProcessUserName() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get executable path.
    public static var executablePath: String? {
        guard let ptr = OCCTProcessExecutablePath() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get executable folder.
    public static var executableFolder: String? {
        guard let ptr = OCCTProcessExecutableFolder() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }
}

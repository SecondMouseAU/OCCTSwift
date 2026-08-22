import Foundation
import OCCTBridge
import simd

/// System host information.
public enum HostInfo {
    /// Get the hostname.
    public static var hostName: String? {
        guard let ptr = OCCTHostName() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Get the OS version string.
    public static var systemVersion: String? {
        guard let ptr = OCCTSystemVersion() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Get the internet address.
    public static var internetAddress: String? {
        guard let ptr = OCCTInternetAddress() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }
}

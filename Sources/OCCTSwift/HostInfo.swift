import Foundation
import OCCTBridge
import simd

// The platform C library, named because this file uses it directly (free, sin, cos, sqrt and
// the like). `import Foundation` happens to re-export it on Apple platforms, so these were in
// scope by accident rather than by declaration; FoundationEssentials does not, which is how
// #2761 found them. Naming it here is correct independently of that work.
#if canImport(Darwin)
    import Darwin
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(Glibc)
    import Glibc
#endif

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

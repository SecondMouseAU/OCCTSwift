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

/// Disk/volume information utilities.
public enum DiskInfo {

    /// Get disk total size in KB for the given path.
    public static func size(path: String = "/") -> Int64 {
        OCCTDiskSize(path)
    }

    /// Get disk free space in KB for the given path.
    public static func freeSpace(path: String = "/") -> Int64 {
        OCCTDiskFree(path)
    }

    /// Check if a disk path is valid/accessible.
    public static func isValid(path: String) -> Bool {
        OCCTDiskIsValid(path)
    }

    /// Get the disk/volume name for the given path.
    public static func name(path: String = "/") -> String? {
        guard let cstr = OCCTDiskName(path) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

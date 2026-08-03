import Foundation
import simd
import OCCTBridge

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

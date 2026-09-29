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

/// Directory operations using OSD_Directory.
public enum DirectoryUtils {
    /// Check if a directory exists.
    public static func exists(_ path: String) -> Bool {
        OCCTDirectoryExists(path)
    }

    /// Create a directory.
    ///
    /// Returns true on success.
    @discardableResult
    public static func create(_ path: String) -> Bool {
        OCCTDirectoryCreate(path)
    }

    /// Build a temporary directory.
    ///
    /// Returns the path.
    public static func buildTemporary() -> String? {
        guard let ptr = OCCTDirectoryBuildTemporary() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Remove a directory.
    ///
    /// Returns true on success.
    @discardableResult
    public static func remove(_ path: String) -> Bool {
        OCCTDirectoryRemove(path)
    }
}

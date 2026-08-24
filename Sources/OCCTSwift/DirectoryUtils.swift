import Foundation
import OCCTBridge
import simd

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

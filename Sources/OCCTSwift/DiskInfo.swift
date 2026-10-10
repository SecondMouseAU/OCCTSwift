import OCCTBridge
import OCCTPlatform

/// Disk/volume information utilities.
///
/// **Unavailable on WASI.** wasi-libc has no `statvfs` and a guest has no volume to describe, so
/// `OSD_Disk` cannot describe any path there: ``isValid(path:)`` is `false` for every path,
/// including `/`, ``size(path:)`` and ``freeSpace(path:)`` are `0`, and ``name(path:)`` is the
/// empty string. See
/// [the wasm consumer guide](../../docs/guides/wasm-consumer-setup.md#present-but-unavailable-on-wasm).
///
/// ```swift
/// if DiskInfo.isValid(path: "/") {
///     print("free: \(DiskInfo.freeSpace()) KB")
/// } else {
///     print("no volume information")  // always the case on WASI
/// }
/// ```
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
    ///
    /// Always `false` on WASI.
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

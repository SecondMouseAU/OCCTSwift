import OCCTBridge
import OCCTPlatform

/// Disk/volume information utilities.
///
/// **Unavailable in this build.** `OSD_Disk` was deleted in OCCT 8.1 and the upstream `IR` kernel has
/// no replacement, so every member is marked unavailable. The text below describes the 8.0.x
/// behaviour.
///
/// **Unavailable on WASI.** wasi-libc has no `statvfs` and a guest has no volume to describe, so
/// `OSD_Disk` cannot describe any path there: ``isValid(path:)`` is `false` for every path,
/// including `/`, ``size(path:)`` and ``freeSpace(path:)`` are `0`, and ``name(path:)`` is the
/// empty string. See
/// [the wasm consumer guide](../../docs/guides/wasm-consumer-setup.md#present-but-unavailable-on-wasm).
///
/// ```swift no-typecheck: DiskInfo is unavailable against the upstream IR kernel (OSD_Disk deleted in OCCT 8.1)
/// if DiskInfo.isValid(path: "/") {
///     print("free: \(DiskInfo.freeSpace()) KB")
/// } else {
///     print("no volume information")  // always the case on WASI
/// }
/// ```
public enum DiskInfo {

    /// Get disk total size in KB for the given path.
    ///
    /// Unavailable in this build: OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement.
    @available(
        *, unavailable,
        message: "OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement."
    )
    public static func size(path: String = "/") -> Int64 {
        fatalError("unavailable")
    }

    /// Get disk free space in KB for the given path.
    ///
    /// Unavailable in this build: OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement.
    @available(
        *, unavailable,
        message: "OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement."
    )
    public static func freeSpace(path: String = "/") -> Int64 {
        fatalError("unavailable")
    }

    /// Check if a disk path is valid/accessible.
    ///
    /// Unavailable in this build: OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement.
    @available(
        *, unavailable,
        message: "OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement."
    )
    public static func isValid(path: String) -> Bool {
        fatalError("unavailable")
    }

    /// Get the disk/volume name for the given path.
    ///
    /// Unavailable in this build: OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement.
    @available(
        *, unavailable,
        message: "OSD_Disk was deleted in OCCT 8.1 and the upstream IR kernel has no replacement."
    )
    public static func name(path: String = "/") -> String? {
        fatalError("unavailable")
    }
}

import OCCTBridge
import OCCTPlatform

/// Process memory information utility.
///
/// A counter the host cannot supply reads `-1` (`-1.0` in MiB), OCCT's own "unavailable" value.
/// Treat a negative figure as "no measurement" and never as a size.
///
/// **Unavailable on WASI.** `wasm32-wasip1` has no process-memory facility (no `/proc`, no
/// `mach_task_basic_info`) and OCCT's `OSD_MemInfo` has no implementation for it, so on that
/// target every figure is unavailable: ``heapUsage``, ``workingSet`` and ``heapUsageMiB`` read
/// `-1`, `-1`, `-1.0`, and ``infoString`` is the empty string. The API stays present so code that
/// compiles for Apple compiles for wasm; see
/// [the wasm consumer guide](../../docs/guides/wasm-consumer-setup.md#present-but-unavailable-on-wasm).
///
/// ```swift
/// let heap = MemInfo.heapUsage
/// if heap >= 0 {
///     print("heap: \(heap / 1_048_576) MiB")
/// } else {
///     print("heap usage unavailable on this target")  // always the case on WASI
/// }
/// ```
public enum MemInfo {

    /// Heap usage in bytes, or `-1` when the host cannot report it (always on WASI).
    public static var heapUsage: Int64 { OCCTMemInfoHeapUsage() }

    /// Working set in bytes, or `-1` when the host cannot report it (always on WASI).
    public static var workingSet: Int64 { OCCTMemInfoWorkingSet() }

    /// Heap usage in precise MiB, or `-1.0` when the host cannot report it (always on WASI).
    public static var heapUsageMiB: Double { OCCTMemInfoHeapUsageMiB() }

    /// Full memory info as a formatted string.
    ///
    /// Contains a `Heap memory` line where the host reports heap usage. On WASI it is the empty
    /// string, not `nil`: there is nothing to print.
    public static var infoString: String? {
        guard let ptr = OCCTMemInfoString() else { return nil }
        defer { OCCTMemInfoFreeString(ptr) }
        return String(cString: ptr)
    }
}

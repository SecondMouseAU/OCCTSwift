import Foundation
import simd
import OCCTBridge

/// Process memory information utility.
public enum MemInfo {

    /// Heap usage in bytes.
    public static var heapUsage: Int64 { OCCTMemInfoHeapUsage() }

    /// Working set in bytes.
    public static var workingSet: Int64 { OCCTMemInfoWorkingSet() }

    /// Heap usage in precise MiB.
    public static var heapUsageMiB: Double { OCCTMemInfoHeapUsageMiB() }

    /// Full memory info as a formatted string.
    public static var infoString: String? {
        guard let ptr = OCCTMemInfoString() else { return nil }
        defer { OCCTMemInfoFreeString(ptr) }
        return String(cString: ptr)
    }
}

import Foundation
import OCCTBridge
import simd

/// CPU time measurement utilities.
public enum CPUTime {

    /// Get process CPU time (user + system) in seconds.
    public static func processCPU() -> (user: Double, system: Double) {
        var u = 0.0
        var s = 0.0
        OCCTGetProcessCPU(&u, &s)
        return (u, s)
    }

    /// Get current thread CPU time in seconds.
    public static func threadCPU() -> (user: Double, system: Double) {
        var u = 0.0
        var s = 0.0
        OCCTGetThreadCPU(&u, &s)
        return (u, s)
    }
}

import Foundation
import simd
import OCCTBridge

/// High-resolution wall-clock timer.
public final class Timer: @unchecked Sendable {
    let handle: OCCTTimerRef

    public init() {
        handle = OCCTTimerCreate()
    }

    deinit {
        OCCTTimerRelease(handle)
    }

    /// Start the timer.
    public func start() {
        OCCTTimerStart(handle)
    }

    /// Stop the timer.
    public func stop() {
        OCCTTimerStop(handle)
    }

    /// Reset the timer to zero.
    public func reset() {
        OCCTTimerReset(handle)
    }

    /// Elapsed wall-clock time in seconds.
    public var elapsedTime: Double {
        OCCTTimerElapsedTime(handle)
    }

    /// Current wall-clock time in seconds (static).
    public static var wallClockTime: Double {
        OCCTTimerGetWallClockTime()
    }
}

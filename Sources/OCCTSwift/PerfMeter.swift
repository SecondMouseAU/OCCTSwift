import Foundation
import simd
import OCCTBridge

/// Performance measurement timer.
public final class PerfMeter: @unchecked Sendable {
    private let ref: OCCTPerfMeterRef

    public init(name: String) {
        ref = OCCTPerfMeterCreate(name)
    }

    deinit { OCCTPerfMeterRelease(ref) }

    public func start() { OCCTPerfMeterStart(ref) }
    public func stop() { OCCTPerfMeterStop(ref) }
    public var elapsed: Double { OCCTPerfMeterElapsed(ref) }
}

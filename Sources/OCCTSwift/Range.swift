import Foundation
import OCCTBridge
import simd

/// A 1D interval [min, max] with void state.
public final class Range: @unchecked Sendable {
    let handle: OCCTRangeRef

    init(handle: OCCTRangeRef) { self.handle = handle }

    deinit { OCCTRangeRelease(handle) }

    /// Create a range [min, max].
    public init(min: Double, max: Double) {
        handle = OCCTRangeCreate(min, max)
    }

    /// Create a void (empty) range.
    public init() {
        handle = OCCTRangeCreateVoid()
    }

    /// Whether the range is void.
    public var isVoid: Bool { OCCTRangeIsVoid(handle) }

    /// Get bounds as (first, last). Returns nil if void.
    public var bounds: (first: Double, last: Double)? {
        var first = 0.0
        var last = 0.0
        guard OCCTRangeGetBounds(handle, &first, &last) else { return nil }
        return (first, last)
    }

    /// Delta (max - min).
    public var delta: Double { OCCTRangeDelta(handle) }

    /// Check if value is in range.
    public func contains(_ value: Double) -> Bool { OCCTRangeContains(handle, value) }

    /// Extend range to include a value.
    public func add(_ value: Double) { OCCTRangeAddValue(handle, value) }

    /// Extend range to include another range.
    public func add(_ other: Range) { OCCTRangeAddRange(handle, other.handle) }

    /// Intersect with another range.
    public func common(_ other: Range) { OCCTRangeCommon(handle, other.handle) }

    /// Enlarge both boundaries.
    public func enlarge(by delta: Double) { OCCTRangeEnlarge(handle, delta) }

    /// Trim lower boundary.
    public func trimFrom(_ lower: Double) { OCCTRangeTrimFrom(handle, lower) }

    /// Trim upper boundary.
    public func trimTo(_ upper: Double) { OCCTRangeTrimTo(handle, upper) }
}

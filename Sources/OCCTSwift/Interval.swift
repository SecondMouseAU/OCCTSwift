import Foundation
import OCCTBridge
import simd

/// A real interval [start, end] with optional start/end tolerances.
///
/// `@unchecked Sendable` reflects that `handle` is a plain bridge handle, not that concurrent use
/// of one instance is safe, it isn't: `setStart`/`setEnd`/`fuseAtStart`/`fuseAtEnd`/`cutAtStart`/
/// `cutAtEnd` all mutate the same underlying `Intrv_Interval`-backed handle in place with no lock.
/// This is not the "Likely true - value type" issue #1162 originally guessed: an `Interval` is a
/// reference to shared, mutable OCCT state, not a Swift value type. Serialize access to a shared
/// instance with `OCCTSerial.withLock { }`.
public final class Interval: @unchecked Sendable {
    public let handle: OCCTIntrvIntervalRef

    /// Create an interval with bounds and optional tolerances.
    public init(start: Double, end: Double, tolStart: Float = 0, tolEnd: Float = 0) {
        handle = OCCTIntrvIntervalCreate(start, end, tolStart, tolEnd)
    }

    deinit {
        OCCTIntrvIntervalRelease(handle)
    }

    /// Interval bounds.
    public struct Bounds: Sendable {
        public let start: Double
        public let end: Double
        public let tolStart: Float
        public let tolEnd: Float
    }

    /// Get interval bounds and tolerances.
    public var bounds: Bounds {
        let b = OCCTIntrvIntervalBounds(handle)
        return Bounds(start: b.start, end: b.end, tolStart: b.tolStart, tolEnd: b.tolEnd)
    }

    /// True if the interval is probably empty (start + tolStart > end - tolEnd).
    public var isProbablyEmpty: Bool {
        OCCTIntrvIntervalIsProbablyEmpty(handle)
    }

    /// Position of this interval relative to another.
    ///
    /// Returns Intrv_Position enum value (0=Before, ..., 12=After).
    public func position(relativeTo other: Interval) -> Int {
        Int(OCCTIntrvIntervalPosition(handle, other.handle))
    }

    /// True if this interval is entirely before the other.
    public func isBefore(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsBefore(handle, other.handle)
    }

    /// True if this interval is entirely after the other.
    public func isAfter(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsAfter(handle, other.handle)
    }

    /// True if this interval is entirely inside the other.
    public func isInside(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsInside(handle, other.handle)
    }

    /// True if this interval entirely encloses the other.
    public func isEnclosing(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsEnclosing(handle, other.handle)
    }

    /// True if this interval has the same bounds as the other.
    public func isSimilar(to other: Interval) -> Bool {
        OCCTIntrvIntervalIsSimilar(handle, other.handle)
    }

    /// Set the start bound.
    public func setStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalSetStart(handle, start, tolerance)
    }

    /// Set the end bound.
    public func setEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalSetEnd(handle, end, tolerance)
    }

    /// Extend start bound outward (fuse).
    public func fuseAtStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalFuseAtStart(handle, start, tolerance)
    }

    /// Extend end bound outward (fuse).
    public func fuseAtEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalFuseAtEnd(handle, end, tolerance)
    }

    /// Cut (trim) start bound inward.
    public func cutAtStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalCutAtStart(handle, start, tolerance)
    }

    /// Cut (trim) end bound inward.
    public func cutAtEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalCutAtEnd(handle, end, tolerance)
    }
}

/// A sorted sequence of non-overlapping intervals with set-theoretic operations.
///
/// `@unchecked Sendable` reflects that `handle` is a plain bridge handle, not that concurrent use
/// of one instance is safe, it isn't: `unite`/`subtract`/`intersect`/`xUnite` all mutate the same
/// underlying handle in place with no lock, same shape as ``Interval``. Serialize access to a
/// shared instance with `OCCTSerial.withLock { }`.
public final class IntervalSet: @unchecked Sendable {
    public let handle: OCCTIntrvIntervalsRef

    /// Create an interval set containing a single interval.
    public init(start: Double, end: Double) {
        handle = OCCTIntrvIntervalsCreate(start, end)
    }

    /// Create an empty interval set.
    public init() {
        handle = OCCTIntrvIntervalsCreateEmpty()
    }

    deinit {
        OCCTIntrvIntervalsRelease(handle)
    }

    /// Number of intervals in the set.
    public var count: Int {
        Int(OCCTIntrvIntervalsCount(handle))
    }

    /// Get bounds of interval at index (0-based).
    public func bounds(at index: Int) -> Interval.Bounds {
        let b = OCCTIntrvIntervalsValue(handle, Int32(index + 1))  // 1-based in OCCT
        return Interval.Bounds(start: b.start, end: b.end, tolStart: b.tolStart, tolEnd: b.tolEnd)
    }

    /// Add an interval (union).
    public func unite(start: Double, end: Double) {
        OCCTIntrvIntervalsUnite(handle, start, end)
    }

    /// Subtract an interval.
    public func subtract(start: Double, end: Double) {
        OCCTIntrvIntervalsSubtract(handle, start, end)
    }

    /// Intersect with an interval.
    public func intersect(start: Double, end: Double) {
        OCCTIntrvIntervalsIntersect(handle, start, end)
    }

    /// Symmetric difference (exclusive union) with an interval.
    public func xUnite(start: Double, end: Double) {
        OCCTIntrvIntervalsXUnite(handle, start, end)
    }
}

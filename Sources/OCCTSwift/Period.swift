import Foundation
import OCCTBridge

/// Time period (interval) wrapping OCCT Quantity_Period.
/// Represents a duration in days, hours, minutes, seconds, milliseconds, and microseconds.
public struct Period: Sendable, Equatable, Comparable {
    /// Internal seconds representation
    internal let sec: Int32
    /// Internal microseconds representation
    internal let usec: Int32

    internal init(sec: Int32, usec: Int32) {
        self.sec = sec
        self.usec = usec
    }

    /// Create a period from days, hours, minutes, seconds, and optional ms/us
    public init?(
        days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0,
        milliseconds: Int = 0, microseconds: Int = 0
    ) {
        var s: Int32 = 0
        var u: Int32 = 0
        guard
            OCCTPeriodCreate(
                Int32(days), Int32(hours), Int32(minutes), Int32(seconds),
                Int32(milliseconds), Int32(microseconds), &s, &u)
        else { return nil }
        self.sec = s
        self.usec = u
    }

    /// Create a period from total seconds and optional microseconds
    public init?(totalSeconds: Int, microseconds: Int = 0) {
        var s: Int32 = 0
        var u: Int32 = 0
        guard OCCTPeriodCreateFromSeconds(Int32(totalSeconds), Int32(microseconds), &s, &u) else {
            return nil
        }
        self.sec = s
        self.usec = u
    }

    /// Decomposed components of this period
    public var components:
        (days: Int, hours: Int, minutes: Int, seconds: Int, milliseconds: Int, microseconds: Int)
    {
        let c = OCCTPeriodValues(sec, usec)
        return (
            Int(c.days), Int(c.hours), Int(c.minutes), Int(c.seconds),
            Int(c.milliseconds), Int(c.microseconds)
        )
    }

    /// Total seconds (integer part)
    public var totalSeconds: Int {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTPeriodTotalSeconds(sec, usec, &s, &u)
        return Int(s)
    }

    /// Total microseconds remainder
    public var totalMicroseconds: Int {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTPeriodTotalSeconds(sec, usec, &s, &u)
        return Int(u)
    }

    /// Add two periods
    public static func + (lhs: Period, rhs: Period) -> Period {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTPeriodAdd(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)
        return Period(sec: s, usec: u)
    }

    /// Subtract two periods
    public static func - (lhs: Period, rhs: Period) -> Period {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTPeriodSubtract(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)
        return Period(sec: s, usec: u)
    }

    /// Check if period values are valid
    public static func isValid(
        days: Int = 0, hours: Int = 0, minutes: Int = 0,
        seconds: Int = 0, milliseconds: Int = 0, microseconds: Int = 0
    ) -> Bool {
        OCCTPeriodIsValid(
            Int32(days), Int32(hours), Int32(minutes), Int32(seconds),
            Int32(milliseconds), Int32(microseconds))
    }

    /// Check if total seconds value is valid
    public static func isValid(totalSeconds: Int, microseconds: Int = 0) -> Bool {
        OCCTPeriodIsValidSeconds(Int32(totalSeconds), Int32(microseconds))
    }

    // MARK: - Equatable & Comparable

    public static func == (lhs: Period, rhs: Period) -> Bool {
        OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) == 0
    }

    public static func < (lhs: Period, rhs: Period) -> Bool {
        OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) < 0
    }
}

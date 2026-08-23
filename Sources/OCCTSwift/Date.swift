import Foundation
import OCCTBridge

/// Date/time wrapping OCCT Quantity_Date.
///
/// Represents a date from January 1, 1979 onward with microsecond precision.
public struct OCCTDate: Sendable, Equatable, Comparable {
    /// Internal seconds from epoch (Jan 1, 1979).
    internal let sec: Int32
    /// Internal microseconds.
    internal let usec: Int32

    internal init(sec: Int32, usec: Int32) {
        self.sec = sec
        self.usec = usec
    }

    /// Create a date from components (year must be >= 1979).
    public init?(
        month: Int, day: Int, year: Int, hour: Int = 0, minute: Int = 0,
        second: Int = 0, millisecond: Int = 0, microsecond: Int = 0
    ) {
        var s: Int32 = 0
        var u: Int32 = 0
        guard
            OCCTDateCreate(
                Int32(month), Int32(day), Int32(year),
                Int32(hour), Int32(minute), Int32(second),
                Int32(millisecond), Int32(microsecond), &s, &u)
        else { return nil }
        self.sec = s
        self.usec = u
    }

    /// Default date (Jan 1, 1979 00:00:00).
    public static var epoch: OCCTDate {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTDateDefault(&s, &u)
        return OCCTDate(sec: s, usec: u)
    }

    /// Decomposed date components.
    public var components:
        (
            month: Int, day: Int, year: Int, hour: Int, minute: Int,
            second: Int, millisecond: Int, microsecond: Int
        )
    {
        let c = OCCTDateValues(sec, usec)
        return (
            Int(c.month), Int(c.day), Int(c.year), Int(c.hour), Int(c.minute),
            Int(c.second), Int(c.millisecond), Int(c.microsecond)
        )
    }

    public var month: Int { components.month }
    public var day: Int { components.day }
    public var year: Int { components.year }
    public var hour: Int { components.hour }
    public var minute: Int { components.minute }
    public var second: Int { components.second }
    public var millisecond: Int { components.millisecond }
    public var microsecond: Int { components.microsecond }

    /// Add a period to this date.
    public func adding(_ period: Period) -> OCCTDate {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTDateAddPeriod(sec, usec, period.sec, period.usec, &s, &u)
        return OCCTDate(sec: s, usec: u)
    }

    /// Subtract a period from this date.
    public func subtracting(_ period: Period) -> OCCTDate? {
        var s: Int32 = 0
        var u: Int32 = 0
        guard OCCTDateSubtractPeriod(sec, usec, period.sec, period.usec, &s, &u) else { return nil }
        return OCCTDate(sec: s, usec: u)
    }

    /// Difference between this date and another (absolute value).
    public func difference(to other: OCCTDate) -> Period {
        var s: Int32 = 0
        var u: Int32 = 0
        OCCTDateDifference(sec, usec, other.sec, other.usec, &s, &u)
        return Period(sec: s, usec: u)
    }

    /// Add period operator.
    public static func + (date: OCCTDate, period: Period) -> OCCTDate {
        date.adding(period)
    }

    /// Subtract period operator.
    public static func - (date: OCCTDate, period: Period) -> OCCTDate? {
        date.subtracting(period)
    }

    /// Check if date values are valid.
    public static func isValid(
        month: Int, day: Int, year: Int, hour: Int = 0,
        minute: Int = 0, second: Int = 0,
        millisecond: Int = 0, microsecond: Int = 0
    ) -> Bool {
        OCCTDateIsValid(
            Int32(month), Int32(day), Int32(year),
            Int32(hour), Int32(minute), Int32(second),
            Int32(millisecond), Int32(microsecond))
    }

    /// Check if a year is a leap year.
    public static func isLeap(year: Int) -> Bool {
        OCCTDateIsLeap(Int32(year))
    }

    // MARK: - Equatable & Comparable

    public static func == (lhs: OCCTDate, rhs: OCCTDate) -> Bool {
        OCCTDateCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) == 0
    }

    public static func < (lhs: OCCTDate, rhs: OCCTDate) -> Bool {
        OCCTDateCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) < 0
    }
}

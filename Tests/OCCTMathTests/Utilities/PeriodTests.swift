import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

@Suite("Period Tests")
struct PeriodTests {
    // Values below were probed on the pinned kernel (Quantity_Period via the bridge) and are
    // exact integers, so the comparisons are exact. #2983 re-sweep: every test requires its
    // fixture (a nil Period used to skip the whole body) and pins the whole result.

    @Test func createFromComponents() throws {
        let p = try #require(Period(days: 1, hours: 2, minutes: 30, seconds: 15))
        let c = p.components
        #expect(c.days == 1)
        #expect(c.hours == 2)
        #expect(c.minutes == 30)
        #expect(c.seconds == 15)
        #expect(c.milliseconds == 0)
        #expect(c.microseconds == 0)
        // 86400 + 2 * 3600 + 30 * 60 + 15
        #expect(p.totalSeconds == 95415)
        #expect(p.totalMicroseconds == 0)
    }

    @Test func createFromSeconds() throws {
        let p = try #require(Period(totalSeconds: 3661, microseconds: 500))
        #expect(p.totalSeconds == 3661)
        #expect(p.totalMicroseconds == 500)
        let c = p.components
        #expect(c.days == 0)
        #expect(c.hours == 1)
        #expect(c.minutes == 1)
        #expect(c.seconds == 1)
        #expect(c.milliseconds == 0)
        #expect(c.microseconds == 500)
    }

    @Test func addPeriods() throws {
        let p1 = try #require(Period(hours: 1))
        let p2 = try #require(Period(minutes: 30))
        let sum = p1 + p2
        let c = sum.components
        #expect(c.hours == 1)
        #expect(c.minutes == 30)
        #expect(sum.totalSeconds == 5400)

        // A sum that carries minutes into hours: 1h45m + 30m = 2h15m.
        let q = try #require(Period(hours: 1, minutes: 45))
        let carried = q + p2
        let cc = carried.components
        #expect(cc.hours == 2)
        #expect(cc.minutes == 15)
        #expect(carried.totalSeconds == 8100)
    }

    @Test func subtractPeriods() throws {
        let p1 = try #require(Period(hours: 2))
        let p2 = try #require(Period(minutes: 30))
        let diff = p1 - p2
        let c = diff.components
        #expect(c.hours == 1)
        #expect(c.minutes == 30)
        #expect(diff.totalSeconds == 5400)
        // Subtraction is not addition: the operands must not be swapped or summed.
        #expect(diff != p1 + p2)
    }

    @Test func equality() throws {
        let a = try #require(Period(hours: 1, minutes: 30))
        let b = try #require(Period(totalSeconds: 5400))
        #expect(a == b)
        // Controls: a different second and a different microsecond must compare unequal.
        let c = try #require(Period(totalSeconds: 5401))
        let d = try #require(Period(totalSeconds: 5400, microseconds: 1))
        #expect(a != c)
        #expect(a != d)
    }

    @Test func comparison() throws {
        let p1 = try #require(Period(hours: 1))
        let p2 = try #require(Period(hours: 2))
        #expect(p1 < p2)
        #expect(p2 > p1)
        // Controls requiring the opposite answer: the order is not a constant.
        #expect(!(p2 < p1))
        #expect(!(p1 > p2))
        #expect(!(p1 < p1))
        // The microsecond field decides when the seconds tie.
        let s0 = try #require(Period(totalSeconds: 10))
        let s1 = try #require(Period(totalSeconds: 10, microseconds: 1))
        #expect(s0 < s1)
        #expect(!(s1 < s0))
    }

    @Test func isValidComponents() {
        #expect(Period.isValid(days: 1, hours: 2, minutes: 30))
        #expect(!Period.isValid(days: -1))
    }

    @Test func isValidSeconds() {
        #expect(Period.isValid(totalSeconds: 100))
        #expect(!Period.isValid(totalSeconds: -1))
    }

    @Test func withMilliseconds() throws {
        let p = try #require(Period(seconds: 1, milliseconds: 500, microseconds: 250))
        let c = p.components
        #expect(c.seconds == 1)
        #expect(c.milliseconds == 500)
        #expect(c.microseconds == 250)
        #expect(c.days == 0)
        #expect(c.hours == 0)
        #expect(c.minutes == 0)
        // 500 ms + 250 us = 500250 us carried in the sub-second part.
        #expect(p.totalSeconds == 1)
        #expect(p.totalMicroseconds == 500_250)
    }

    @Test func zeroPeriod() throws {
        let p = try #require(Period(totalSeconds: 0))
        #expect(p.totalSeconds == 0)
        #expect(p.totalMicroseconds == 0)
        let c = p.components
        #expect(c.days == 0 && c.hours == 0 && c.minutes == 0)
        #expect(c.seconds == 0 && c.milliseconds == 0 && c.microseconds == 0)
        // Zero is the additive identity and is smaller than any positive period.
        let one = try #require(Period(totalSeconds: 1))
        #expect(p + one == one)
        #expect(p < one)
    }
}

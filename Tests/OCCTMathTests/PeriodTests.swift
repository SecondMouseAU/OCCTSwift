import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

@Suite("Period Tests")
struct PeriodTests {
    @Test func createFromComponents() {
        if let p = Period(days: 1, hours: 2, minutes: 30, seconds: 15) {
            let c = p.components
            #expect(c.days == 1)
            #expect(c.hours == 2)
            #expect(c.minutes == 30)
            #expect(c.seconds == 15)
        }
    }

    @Test func createFromSeconds() {
        if let p = Period(totalSeconds: 3661, microseconds: 500) {
            #expect(p.totalSeconds == 3661)
            #expect(p.totalMicroseconds == 500)
        }
    }

    @Test func addPeriods() {
        if let p1 = Period(hours: 1), let p2 = Period(minutes: 30) {
            let sum = p1 + p2
            let c = sum.components
            #expect(c.hours == 1)
            #expect(c.minutes == 30)
        }
    }

    @Test func subtractPeriods() {
        if let p1 = Period(hours: 2), let p2 = Period(minutes: 30) {
            let diff = p1 - p2
            let c = diff.components
            #expect(c.hours == 1)
            #expect(c.minutes == 30)
        }
    }

    @Test func equality() {
        let p1 = Period(hours: 1, minutes: 30)
        let p2 = Period(totalSeconds: 5400)
        if let a = p1, let b = p2 {
            #expect(a == b)
        }
    }

    @Test func comparison() {
        if let p1 = Period(hours: 1), let p2 = Period(hours: 2) {
            #expect(p1 < p2)
            #expect(p2 > p1)
        }
    }

    @Test func isValidComponents() {
        #expect(Period.isValid(days: 1, hours: 2, minutes: 30))
        #expect(!Period.isValid(days: -1))
    }

    @Test func isValidSeconds() {
        #expect(Period.isValid(totalSeconds: 100))
        #expect(!Period.isValid(totalSeconds: -1))
    }

    @Test func withMilliseconds() {
        if let p = Period(seconds: 1, milliseconds: 500, microseconds: 250) {
            let c = p.components
            #expect(c.seconds == 1)
            #expect(c.milliseconds == 500)
            #expect(c.microseconds == 250)
        }
    }

    @Test func zeroPeriod() {
        if let p = Period(totalSeconds: 0) {
            #expect(p.totalSeconds == 0)
            #expect(p.totalMicroseconds == 0)
        }
    }
}


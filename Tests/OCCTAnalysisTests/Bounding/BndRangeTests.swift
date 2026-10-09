import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bnd Range Tests")
struct BndRangeTests {

    @Test func createAndQuery() {
        let r = Range(min: 1.0, max: 5.0)
        #expect(!r.isVoid)
        if let b = r.bounds {
            #expect(abs(b.first - 1.0) < 1e-10)
            #expect(abs(b.last - 5.0) < 1e-10)
        }
        #expect(abs(r.delta - 4.0) < 1e-10)
    }

    @Test func contains() {
        let r = Range(min: 1.0, max: 5.0)
        #expect(r.contains(3.0))
        #expect(!r.contains(6.0))
    }

    @Test func addValue() {
        let r = Range(min: 2.0, max: 4.0)
        r.add(6.0)
        if let b = r.bounds {
            #expect(abs(b.last - 6.0) < 1e-10)
        }
    }

    @Test func common() {
        let r1 = Range(min: 1.0, max: 5.0)
        let r2 = Range(min: 3.0, max: 7.0)
        r1.common(r2)
        if let b = r1.bounds {
            #expect(abs(b.first - 3.0) < 1e-10)
            #expect(abs(b.last - 5.0) < 1e-10)
        }
    }

    @Test func trimFromTo() {
        let r = Range(min: 0.0, max: 10.0)
        r.trimFrom(3.0)
        r.trimTo(7.0)
        if let b = r.bounds {
            #expect(abs(b.first - 3.0) < 1e-10)
            #expect(abs(b.last - 7.0) < 1e-10)
        }
    }

    @Test func voidRange() {
        let r = Range()
        #expect(r.isVoid)
    }
}

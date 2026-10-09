import Foundation
import Testing
import simd

@testable import OCCTSwift

// Expected values are Bnd_Range's own answers for the same calls, measured by
// Scripts/repro/766-bnd-range/probe.mm (transcript.txt beside it). `bounds` is `try #require`d
// rather than read under `if let`: a nil there used to skip the assertions and pass
// (#1837-#1842).
@Suite("Bnd Range Tests")
struct BndRangeTests {

    @Test func createAndQuery() throws {
        let r = Range(min: 1.0, max: 5.0)
        #expect(!r.isVoid)
        let b = try #require(r.bounds)
        #expect(abs(b.first - 1.0) < 1e-10)
        #expect(abs(b.last - 5.0) < 1e-10)
        #expect(abs(r.delta - 4.0) < 1e-10)
    }

    @Test func contains() {
        let r = Range(min: 1.0, max: 5.0)
        #expect(r.contains(3.0))
        #expect(!r.contains(6.0))
    }

    @Test func addValue() throws {
        let r = Range(min: 2.0, max: 4.0)
        r.add(6.0)
        let b = try #require(r.bounds)
        // Adding a value above the range moves the upper bound and leaves the lower one.
        #expect(abs(b.first - 2.0) < 1e-10)
        #expect(abs(b.last - 6.0) < 1e-10)
    }

    @Test func common() throws {
        let r1 = Range(min: 1.0, max: 5.0)
        let r2 = Range(min: 3.0, max: 7.0)
        r1.common(r2)
        let b = try #require(r1.bounds)
        #expect(abs(b.first - 3.0) < 1e-10)
        #expect(abs(b.last - 5.0) < 1e-10)
    }

    @Test func trimFromTo() throws {
        let r = Range(min: 0.0, max: 10.0)
        r.trimFrom(3.0)
        r.trimTo(7.0)
        let b = try #require(r.bounds)
        #expect(abs(b.first - 3.0) < 1e-10)
        #expect(abs(b.last - 7.0) < 1e-10)
    }

    @Test func voidRange() {
        let r = Range()
        #expect(r.isVoid)
        // A void Bnd_Range has no bounds to report.
        #expect(r.bounds == nil)
    }
}

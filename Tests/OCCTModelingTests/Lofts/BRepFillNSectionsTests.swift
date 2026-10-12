import Testing

@testable import OCCTSwift

@Suite("BRepFill_NSections")
struct BRepFillNSectionsTests {
    @Test("create from wires")
    func createFromWires() {
        if let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let w2 = Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3),
            let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2)
        {
            if let nsec = NSections.create(wires: [s1, s2]) {
                #expect(nsec.lawCount > 0)
                #expect(!nsec.isVertex)
            }
        }
    }

    // #3332: the old test read `let _ = nsec.isConstant; #expect(true)`. The query cannot be made
    // to discriminate, and it says why here instead of asserting nothing: BRepFill_NSections
    // overrides `IsConstant()` and `IsVertex()` as constant `false`
    // (BRepFill_NSections.cxx: `bool BRepFill_NSections::IsConstant() const { return false; }`),
    // so two coaxial radius-5 circles, whose section genuinely is constant, answer false exactly
    // as a 5 -> 3 taper does. What is pinned: that answer for both, and the law count, which is
    // 1 for two wires and also 1 for three (measured: one law, a single piecewise surface over
    // all the sections, not one law per gap).
    @Test("isConstant query")
    func isConstantQuery() throws {
        let w1 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 5))
        let w3 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let s1 = try #require(Shape.fromWire(w1))
        let s2 = try #require(Shape.fromWire(w2))
        let s3 = try #require(Shape.fromWire(w3))

        let same = try #require(NSections.create(wires: [s1, s2]))
        #expect(!same.isConstant)
        #expect(!same.isVertex)
        #expect(same.lawCount == 1)

        let taper = try #require(NSections.create(wires: [s1, s3]))
        #expect(!taper.isConstant)
        #expect(!taper.isVertex)
        #expect(taper.lawCount == 1)

        let three = try #require(NSections.create(wires: [s1, s2, s3]))
        #expect(three.lawCount == 1)
    }
}

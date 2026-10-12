import Foundation
import Testing

@testable import OCCTSwift

@Suite("BRepFill CompatibleWires Tests")
struct BRepFillCompatibleWiresTests {
    private func perimeter(_ wire: Wire) -> Double {
        wire.edges().map { $0.length }.reduce(0, +)
    }

    // #3332: the old test asserted `result != nil` and `count >= 2`, which the two input wires
    // returned unchanged satisfy. Making wires compatible means giving them the SAME number of
    // edges without changing their geometry: a 4-edge rectangle and a 1-edge circle come back as
    // two 5-edge wires (the circle is cut into the rectangle's four plus its seam; measured on the
    // pinned kernel), with each wire's perimeter unchanged. Two rectangles that already agree
    // stay 4 and 4.
    @Test("Make two wires compatible for lofting")
    func normalizeWires() throws {
        let square = try #require(Wire.rectangle(width: 10, height: 10))
        let larger = try #require(Wire.rectangle(width: 15, height: 15))
        let same = try #require(Shape.compatibleWires([square, larger]))
        #expect(same.count == 2)
        #expect(same.map { $0.edges().count } == [4, 4])
        #expect(abs(perimeter(same[0]) - 40) < 1e-6)
        #expect(abs(perimeter(same[1]) - 60) < 1e-6)

        let circle = try #require(Wire.circle(radius: 5))
        #expect(circle.edges().count == 1)
        let mixed = try #require(Shape.compatibleWires([square, circle]))
        #expect(mixed.count == 2)
        #expect(mixed.map { $0.edges().count } == [5, 5])
        #expect(abs(perimeter(mixed[0]) - 40) < 1e-6)
        #expect(abs(perimeter(mixed[1]) - 2 * Double.pi * 5) < 1e-6)

        // Fewer than two wires is refused.
        #expect(Shape.compatibleWires([square]) == nil)
    }
}

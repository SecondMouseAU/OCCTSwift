import Foundation
import Testing

@testable import OCCTSwift

@Suite("BRepFill Draft Tests")
struct BRepFillDraftTests {
    @Test("Draft surface from rectangular wire")
    func draftFromRect() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let result = try #require(
            Shape.draft(
                wire: wire,
                direction: SIMD3(0, 0, 1),
                angle: 0.1,
                length: 20))
        #expect(result.isValid)
        // Four trapezoids, each flaring by sin(0.1) per unit of the 20 mm slant: the parallel
        // sides are 10 and 10 + 2 * 20 * sin(0.1), so each is 20 * (10 + 20 sin 0.1) and the
        // shell is 959.7334666... (measured on kernel.6).
        #expect(result.faces().count == 4)
        let expected = 4.0 * 20.0 * (10.0 + 20.0 * sin(0.1))
        #expect(abs((result.surfaceArea ?? -1) - expected) < 1e-6)
        // The top is 20 cos(0.1) up and has flared to half-width 5 + 20 sin(0.1).
        let bounds = try #require(result.boundingBox)
        #expect(abs(bounds.max.z - 20.0 * cos(0.1)) < 1e-5)
        #expect(abs(bounds.max.x - (5.0 + 20.0 * sin(0.1))) < 1e-5)
        // A zero angle is the straight wall: 4 * 10 * 20 = 800, a control for the flare.
        let straight = try #require(
            Shape.draft(wire: wire, direction: SIMD3(0, 0, 1), angle: 0.0, length: 20))
        #expect(abs((straight.surfaceArea ?? -1) - 800.0) < 1e-6)
    }
}

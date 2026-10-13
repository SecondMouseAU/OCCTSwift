import Foundation
import Testing

@testable import OCCTSwift

@Suite("Draft from Shape")
struct DraftTests {
    @Test("Draft a circle wire")
    func draftCircle() throws {
        let circle = try #require(Wire.circle(radius: 5))
        let wireShape = try #require(Shape.fromWire(circle))
        let drafted = try #require(
            wireShape.draft(direction: SIMD3(0, 0, 1), angle: 0.1, length: 10))
        #expect(drafted.isValid)
        // A cone frustum: base radius 5, slant 10 at 0.1 rad, so the top radius is
        // 5 + 10 sin(0.1) and the lateral area pi * (r1 + r2) * 10 = 345.5228... (kernel.6).
        #expect(drafted.faces().count == 1)
        let top = 5.0 + 10.0 * sin(0.1)
        let expected = Double.pi * (5.0 + top) * 10.0
        #expect(abs((drafted.surfaceArea ?? -1) - expected) < 1e-6)
        let bounds = try #require(drafted.boundingBox)
        #expect(abs(bounds.max.x - top) < 1e-5)
        #expect(abs(bounds.max.z - 10.0 * cos(0.1)) < 1e-5)
        // The zero-angle control is the cylinder, 2 pi * 5 * 10.
        let straight = try #require(
            wireShape.draft(direction: SIMD3(0, 0, 1), angle: 0.0, length: 10))
        #expect(abs((straight.surfaceArea ?? -1) - 2.0 * Double.pi * 50.0) < 1e-6)
    }
}

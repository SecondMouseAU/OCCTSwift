import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are BRepBuilderAPI_Sewing's own answers on the same inputs, from
// Scripts/repro/766-healing-sewing/probe.mm (transcript.txt beside it).
// Before #766 these force-unwrapped inside `#expect` and asserted only non-nil and valid.
/// A face on a wire, or a recorded failure.
private func planarFace(_ wire: Wire?) throws -> Shape {
    let w = try #require(wire)
    return try #require(Shape.face(from: w))
}

@Suite("Sewing Tests")
struct SewingTests {
    @Test("Sew two shapes together")
    func sewTwoShapes() throws {
        // Kernel: a compound of the two faces, 5 free edges (4 rectangle sides + the circle).
        let face1 = try planarFace(Wire.rectangle(width: 10, height: 10))
        let face2 = try planarFace(Wire.circle(radius: 5))
        let sewn = try #require(Shape.sew(face1, with: face2, tolerance: 1e-6))
        #expect(sewn.isValid)
        #expect(sewn.faces().count == 2)
    }

    @Test("Sew array of faces")
    func sewMultipleFaces() throws {
        let faces = [
            try planarFace(Wire.rectangle(width: 10, height: 10)),
            try planarFace(Wire.circle(radius: 5)),
            try planarFace(Wire.rectangle(width: 8, height: 8)),
        ]
        let sewn = try #require(Shape.sew(shapes: faces, tolerance: 1e-6))
        #expect(sewn.isValid)
        #expect(sewn.faces().count == 3)
    }

    @Test("Instance method sewn(with:)")
    func instanceMethodSewn() throws {
        let face1 = try planarFace(Wire.rectangle(width: 10, height: 10))
        let face2 = try planarFace(Wire.circle(radius: 5))
        let sewn = try #require(face1.sewn(with: face2))
        #expect(sewn.isValid)
        #expect(sewn.faces().count == 2)
    }
}

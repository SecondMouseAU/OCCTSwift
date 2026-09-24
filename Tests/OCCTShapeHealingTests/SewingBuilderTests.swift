import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are BRepBuilderAPI_Sewing's own answers on the same inputs, from
// Scripts/repro/766-healing-sewing/probe.mm (transcript.txt beside it).
// Before #766 every test here was nested in `if let` (silently green on a nil builder) and the
// statistics test asserted `>= 0` three times, true of every Int.
@Suite("Sewing Builder Tests")
struct SewingBuilderTests {
    @Test func createSewing() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        // Kernel: SewedShape() is null before Perform().
        #expect(sewing.result == nil)
    }

    @Test func sewBoxFaces() throws {
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.subShapes(ofType: .face) { sewing.add(face) }
        sewing.perform()
        let result = try #require(sewing.result)
        #expect(result.isValid)
        #expect(result.shapeType == .shell)
        #expect(result.faces().count == 6)
    }

    @Test func sewingStatistics() throws {
        // Five of the box's six faces: the kernel reports the missing face's 4 edges as free.
        let sewing = try #require(SewingBuilder(tolerance: 1e-6))
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.subShapes(ofType: .face).prefix(5) { sewing.add(face) }
        sewing.perform()
        #expect(sewing.nbFreeEdges == 4)
        #expect(sewing.nbContigousEdges == 0)
        #expect(sewing.nbDegeneratedShapes == 0)
    }
}

import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_Tools Tests")
struct BOPAlgoToolsTests {
    @Test("EdgesToWires from rectangle edges")
    func edgesToWires() throws {
        // #766: every step used to sit in a nested `if let`, so a fixture that failed to build
        // skipped all the assertions, and the count was only `>= 1`. The fixtures are now
        // `try #require`, and the kernel's answer is pinned (Scripts/repro/766-modeling-bopalgo-
        // tools): BOPAlgo_Tools::EdgesToWires on the four edges of the 10 x 10 rectangle gives
        // exactly 1 wire.
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0)))
        let edge3 = try #require(Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0)))
        let edge4 = try #require(Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0)))
        let c = try #require(Shape.compound([edge1, edge2, edge3, edge4]))
        let r = try #require(c.edgesToWires())
        let wires = r.subShapes(ofType: .wire)
        #expect(wires.count >= 1)
        #expect(wires.count == 1)
    }

    @Test("WiresToFaces from edge compound via EdgesToWires")
    func wiresToFaces() throws {
        // First convert edges to wires, then wires to faces
        // #766: as above; the kernel's WiresToFaces on that wire gives exactly 1 face of area 100
        // (Scripts/repro/766-modeling-bopalgo-tools).
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0)))
        let edge3 = try #require(Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0)))
        let edge4 = try #require(Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0)))
        let c = try #require(Shape.compound([edge1, edge2, edge3, edge4]))
        let w = try #require(c.edgesToWires())
        let r = try #require(w.wiresToFaces())
        let faces = r.subShapes(ofType: .face)
        #expect(faces.count >= 1)
        #expect(faces.count == 1)
        let face = try #require(faces.first)
        let area = try #require(face.surfaceArea)
        #expect(abs(area - 100) < 1e-6)
    }
}

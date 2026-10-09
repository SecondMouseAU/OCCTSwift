import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeExtend_Explorer

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
// Before #766 every test returned early, silently green, on a failed fixture, and the counts sat
// inside `if let`; the edge count was `> 0`. Kernel: 2 solids, 12 faces, 12 edges, predominant SOLID.
@Suite("ShapeExtend Explorer")
struct ShapeExtendExplorerTests {
    private func twoBoxes() throws -> Shape {
        let box1 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let box2 = try #require(Shape.box(width: 3, height: 3, depth: 3))
        return try #require(Shape.compound([box1, box2]))
    }

    @Test("Sorted compound - extract solids")
    func sortedCompoundSolids() throws {
        let solids = try #require(try twoBoxes().sortedCompound(type: .solid))
        #expect(solids.subShapes(ofType: .solid).count == 2)
    }

    @Test("Sorted compound - extract faces")
    func sortedCompoundFaces() throws {
        let faces = try #require(try twoBoxes().sortedCompound(type: .face))
        #expect(faces.subShapes(ofType: .face).count == 12)
    }

    @Test("Sorted compound - extract edges")
    func sortedCompoundEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let compound = try #require(Shape.compound([box]))
        let edges = try #require(compound.sortedCompound(type: .edge))
        #expect(edges.subShapes(ofType: .edge).count == 12)
    }

    @Test("Predominant shape type")
    func predominantType() throws {
        #expect(try twoBoxes().predominantShapeType() == .solid)
    }
}

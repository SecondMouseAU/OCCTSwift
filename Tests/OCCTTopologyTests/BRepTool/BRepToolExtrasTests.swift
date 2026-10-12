import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// A box with `from` replaced by `to` in its BREP text, for flags that have no setter.
///
/// An edge
/// record reads `tolerance sameParameter sameRange degenerated`; a face record starts with its
/// NaturalRestriction flag.
private func boxWithEdited(_ from: String, _ to: String) -> Shape? {
    guard let box = Shape.box(width: 10, height: 10, depth: 10), let brep = box.toBREPString()
    else { return nil }
    let edited = brep.replacingOccurrences(of: from, with: to)
    guard edited != brep else { return nil }
    return Shape.fromBREPString(edited)
}

@Suite("BRep_Tool_Extras")
struct BRepToolExtrasTests {
    @Test func edgeSameParameter() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { $0.edgeSameParameter })

        // The flag cleared in the BREP text reads false on every edge, so the true above is a
        // reading and not a constant.
        let cleared = try #require(boxWithEdited("Ed\n 1e-07 1 1 0", "Ed\n 1e-07 0 1 0"))
        let clearedEdges = cleared.subShapes(ofType: .edge)
        #expect(clearedEdges.count == 12)
        #expect(clearedEdges.allSatisfy { !$0.edgeSameParameter })
    }

    @Test func edgeSameRange() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { $0.edgeSameRange })

        let cleared = try #require(boxWithEdited("Ed\n 1e-07 1 1 0", "Ed\n 1e-07 1 0 0"))
        let clearedEdges = cleared.subShapes(ofType: .edge)
        #expect(clearedEdges.count == 12)
        #expect(clearedEdges.allSatisfy { !$0.edgeSameRange })
    }

    @Test func faceNaturalRestriction() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        #expect(faces.allSatisfy { !$0.faceNaturalRestriction })

        // The first number of a face record is the flag; set, every face reads true.
        let flagged = try #require(boxWithEdited("Fa\n0  1e-07", "Fa\n1  1e-07"))
        let flaggedFaces = flagged.subShapes(ofType: .face)
        #expect(flaggedFaces.count == 6)
        #expect(flaggedFaces.allSatisfy { $0.faceNaturalRestriction })
    }

    @Test func edgeIsGeometric() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { $0.edgeIsGeometric })

        // cleanGeometry strips the 3D curves, after which no edge is geometric.
        let stripped = try #require(Shape.box(width: 10, height: 10, depth: 10))
        stripped.cleanGeometry()
        let strippedEdges = stripped.subShapes(ofType: .edge)
        #expect(strippedEdges.count == 12)
        #expect(strippedEdges.allSatisfy { !$0.edgeIsGeometric })
    }

    @Test func faceIsGeometric() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        #expect(faces.allSatisfy { $0.faceIsGeometric })

        // cleanGeometry also drops the surfaces, after which no face is geometric.
        let stripped = try #require(Shape.box(width: 10, height: 10, depth: 10))
        stripped.cleanGeometry()
        let strippedFaces = stripped.subShapes(ofType: .face)
        #expect(strippedFaces.count == 6)
        #expect(strippedFaces.allSatisfy { !$0.faceIsGeometric })
    }
}

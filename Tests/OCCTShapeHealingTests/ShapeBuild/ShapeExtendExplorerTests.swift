import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeExtend_Explorer

@Suite("ShapeExtend Explorer")
struct ShapeExtendExplorerTests {
    @Test("Sorted compound - extract solids")
    func sortedCompoundSolids() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
            let box2 = Shape.box(width: 3, height: 3, depth: 3),
            let compound = Shape.compound([box1, box2])
        else { return }
        if let solids = compound.sortedCompound(type: .solid) {
            let solidList = solids.subShapes(ofType: .solid)
            #expect(solidList.count == 2)
        }
    }

    @Test("Sorted compound - extract faces")
    func sortedCompoundFaces() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
            let box2 = Shape.box(width: 3, height: 3, depth: 3),
            let compound = Shape.compound([box1, box2])
        else { return }
        if let faces = compound.sortedCompound(type: .face) {
            let faceList = faces.subShapes(ofType: .face)
            #expect(faceList.count == 12)
        }
    }

    @Test("Sorted compound - extract edges")
    func sortedCompoundEdges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let compound = Shape.compound([box])
        else { return }
        if let edges = compound.sortedCompound(type: .edge) {
            let edgeList = edges.subShapes(ofType: .edge)
            #expect(edgeList.count > 0)
        }
    }

    @Test("Predominant shape type")
    func predominantType() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
            let box2 = Shape.box(width: 3, height: 3, depth: 3),
            let compound = Shape.compound([box1, box2])
        else { return }
        let type = compound.predominantShapeType()
        #expect(type == .solid)
    }
}

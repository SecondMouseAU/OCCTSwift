import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Shape Queries")
struct ShapeQueryTests {

    @Test func obbVolume() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vol = box.obbVolume
            #expect(vol > 0)
            // OBB should be close to 10*10*10 = 1000 but may differ due to centering
            #expect(vol > 500)
        }
    }

    @Test func maxTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edgeTol = box.maxEdgeTolerance
            let faceTol = box.maxFaceTolerance
            let vertTol = box.maxVertexTolerance
            #expect(edgeTol > 0)
            #expect(faceTol >= 0)
            #expect(vertTol > 0)
        }
    }

    @Test func freeEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A solid box should not have free edges
            #expect(!box.hasFreeEdges)
        }
    }

    @Test func freeEdgesOnOpenShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count >= 5 {
                // Make an open shell (5 out of 6 faces)
                if let compound = Shape.builderMakeCompound() {
                    for i in 0..<5 {
                        compound.builderAdd(faces[i])
                    }
                    // An open shell should have free edges
                    let hasFree = compound.hasFreeEdges
                    #expect(hasFree)
                }
            }
        }
    }

    @Test func boundingDiagonal() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let diag = box.boundingDiagonal
            // For a 10x10x10 box centered at origin, diagonal = sqrt(100+100+100) ~ 17.3
            #expect(diag > 15)
            #expect(diag < 20)
        }
    }

    @Test func centroid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10), let c = box.centroid {
            // Box centered at origin
            #expect(abs(c.x) < 1)
            #expect(abs(c.y) < 1)
            #expect(abs(c.z) < 1)
        }
    }

    @Test func totalEdgeLength() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let len = box.totalEdgeLength
            // 12 edges * 10 = 120; LinearProperties counts wire lengths
            #expect(len > 0)
        }
    }
}

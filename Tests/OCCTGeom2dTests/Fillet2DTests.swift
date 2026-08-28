import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.42.0: 2D Fillet/Chamfer

@Suite("2D Fillet and Chamfer")
struct Fillet2DTests {
    @Test("Fillet single vertex of rectangular face")
    func filletSingleVertex() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [0], radii: [3.0])
        #expect(result != nil)
        if let result {
            // Original rectangle has 4 edges, fillet adds 1 arc replacing corner
            let edges = result.edgeCount
            #expect(edges == 5)
        }
    }

    @Test("Fillet multiple vertices")
    func filletMultipleVertices() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [2.0, 2.0, 2.0, 2.0])
        #expect(result != nil)
        if let result {
            // 4 original edges + 4 fillet arcs = 8 edges
            let edges = result.edgeCount
            #expect(edges == 8)
        }
    }

    @Test("Fillet with zero count returns nil")
    func filletEmptyReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [], radii: [])
        #expect(result == nil)
    }

    @Test("Chamfer between adjacent edges")
    func chamferAdjacentEdges() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1)], distances: [2.0])
        #expect(result != nil)
        if let result {
            // 4 edges + 1 chamfer = 5 edges
            let edges = result.edgeCount
            #expect(edges == 5)
        }
    }

    @Test("Chamfer mismatched arrays returns nil")
    func chamferMismatchedReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1)], distances: [])
        #expect(result == nil)
    }
}

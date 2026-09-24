import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.42.0: 2D Fillet/Chamfer

@Suite("2D Fillet and Chamfer")
struct Fillet2DTests {
    @Test("Fillet single vertex of rectangular face")
    func filletSingleVertex() throws {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = try #require(face.fillet2D(vertexIndices: [0], radii: [3.0]))
        // Original rectangle has 4 edges, fillet adds 1 arc replacing corner
        #expect(result.edgeCount == 5)
        // #1979: the edge count passed a fillet of any radius. A radius-3 round removes 9 - 9pi/4
        // (BRepFilletAPI_MakeFillet2d; Scripts/repro/766-geom2d-extrema-fillet2d/).
        let area = try #require(result.surfaceArea)
        #expect(abs(area - 398.068583471) < 1e-6)
    }

    @Test("Fillet multiple vertices")
    func filletMultipleVertices() throws {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = try #require(
            face.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [2.0, 2.0, 2.0, 2.0]))
        // 4 original edges + 4 fillet arcs = 8 edges, each corner losing 4 - pi.
        #expect(result.edgeCount == 8)
        let area = try #require(result.surfaceArea)
        #expect(abs(area - 396.566370614) < 1e-6)
    }

    @Test("Fillet with zero count returns nil")
    func filletEmptyReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.fillet2D(vertexIndices: [], radii: [])
        #expect(result == nil)
    }

    @Test("Chamfer between adjacent edges")
    func chamferAdjacentEdges() throws {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = try #require(face.chamfer2D(edgePairs: [(0, 1)], distances: [2.0]))
        // 4 edges + 1 chamfer = 5 edges, cutting off a triangle of area 2.
        #expect(result.edgeCount == 5)
        let area = try #require(result.surfaceArea)
        #expect(abs(area - 398) < 1e-6)
    }

    @Test("Chamfer mismatched arrays returns nil")
    func chamferMismatchedReturnsNil() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let result = face.chamfer2D(edgePairs: [(0, 1)], distances: [])
        #expect(result == nil)
    }
}

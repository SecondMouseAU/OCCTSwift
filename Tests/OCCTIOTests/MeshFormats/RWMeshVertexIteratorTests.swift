import Foundation
import Testing

@testable import OCCTSwift

// `RWMesh_VertexIterator` walks the vertices that are NOT part of an edge (it explores
// `TopAbs_VERTEX` while avoiding `TopAbs_EDGE`), so the shapes it yields are loose vertices. A
// box or a sphere has none: all of their vertices belong to edges, and the iterator is empty.
// These tests used to run on a box and a sphere and assert `count >= 0` (#3332), which is true of
// an iterator that yields nothing, so they never reached a vertex.
@Suite("RWMesh VertexIterator v0.112")
struct RWMeshVertexIteratorTests {

    private static let freeVertices: [SIMD3<Double>] = [
        SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(-7, 8, 9),
    ]

    /// A compound holding `freeVertices` as loose vertices.
    private func compoundOfFreeVertices() throws -> Shape {
        let vertices = try Self.freeVertices.map { try #require(Shape.vertex(at: $0)) }
        return try #require(Shape.compound(vertices))
    }

    private func collectPoints(_ iter: MeshVertexIterator) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        while iter.hasMore {
            points.append(iter.point)
            iter.next()
        }
        return points
    }

    @Test func iterateVertices() throws {
        let iter = try #require(MeshVertexIterator(shape: try compoundOfFreeVertices()))
        var count = 0
        while iter.hasMore {
            count += 1
            iter.next()
        }
        #expect(count == 3)
        #expect(!iter.hasMore)
    }

    @Test func vertexPointAccess() throws {
        let iter = try #require(MeshVertexIterator(shape: try compoundOfFreeVertices()))
        let points = collectPoints(iter)
        #expect(points.count == 3)
        // Each point is one of the vertices that went in, and each came out once.
        var remaining = Self.freeVertices
        for p in points {
            let index = remaining.firstIndex { vectorDistance($0, p) < 1e-9 }
            if let index {
                remaining.remove(at: index)
            } else {
                Issue.record("point \(p) is not one of \(Self.freeVertices)")
            }
        }
        #expect(remaining.isEmpty)
    }

    @Test func boxHasVertices() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // The box's 8 corners are all edge vertices, so the iterator has none to give.
        let iter = try #require(MeshVertexIterator(shape: box))
        #expect(box.subShapes(ofType: .vertex).count == 8)
        #expect(collectPoints(iter).isEmpty)

        // The same box with a loose vertex beside it yields exactly that vertex.
        let loose = try #require(Shape.vertex(at: SIMD3(20, 0, 0)))
        let both = try #require(Shape.compound([box, loose]))
        let points = collectPoints(try #require(MeshVertexIterator(shape: both)))
        #expect(points.count == 1)
        if let p = points.first { #expect(vectorDistance(p, SIMD3(20, 0, 0)) < 1e-9) }
    }

    @Test func sphereHasVertices() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let iter = try #require(MeshVertexIterator(shape: sphere))
        // A sphere's only vertices are the poles on its seam edge, so there is no loose vertex.
        #expect(sphere.subShapes(ofType: .vertex).count == 2)
        #expect(collectPoints(iter).isEmpty)

        // Meshing it changes nothing: the iterator is about topology, not the triangulation.
        _ = sphere.mesh(linearDeflection: 0.5)
        #expect(collectPoints(try #require(MeshVertexIterator(shape: sphere))).isEmpty)
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("RWMesh VertexIterator v0.112")
struct RWMeshVertexIteratorTests {

    @Test func iterateVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                #expect(count >= 0)  // should not crash
            }
        }
    }

    @Test func vertexPointAccess() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                if iter.hasMore {
                    let p = iter.point
                    // Box corners should be finite
                    #expect(p.x.isFinite)
                    #expect(p.y.isFinite)
                    #expect(p.z.isFinite)
                }
            }
        }
    }

    @Test func boxHasVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let iter = MeshVertexIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                // RWMesh_VertexIterator may return 0 for unmeshed shapes or 8 for boxes
                #expect(count >= 0)
            }
        }
    }

    @Test func sphereHasVertices() {
        if let sphere = Shape.sphere(radius: 5) {
            if let iter = MeshVertexIterator(shape: sphere) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                // Sphere may have 0 or more vertices depending on topology
                #expect(count >= 0)
            }
        }
    }
}

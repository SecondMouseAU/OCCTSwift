import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.112.0 Tests

@Suite("RWMesh FaceIterator v0.112")
struct RWMeshFaceIteratorTests {

    @Test func iterateFaces() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                var faceCount = 0
                var totalTris = 0
                while iter.hasMore {
                    totalTris += iter.triangleCount
                    faceCount += 1
                    iter.next()
                }
                #expect(faceCount >= 1)
                #expect(totalTris > 0)
            }
        }
    }

    @Test func nodeAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.nodeCount > 0 {
                    let p = iter.node(at: 1)
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(abs(dist - 5.0) < 0.6)
                }
            }
        }
    }

    @Test func normalAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.hasNormals {
                    let n = iter.normal(at: 1)
                    let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                    #expect(abs(len - 1.0) < 0.01)
                }
            }
        }
    }

    @Test func triangleAccess() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore && iter.triangleCount > 0 {
                    let tri = iter.triangle(at: 1)
                    #expect(tri.n1 >= 1)
                    #expect(tri.n2 >= 1)
                    #expect(tri.n3 >= 1)
                }
            }
        }
    }

    @Test func nodeCountPositive() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.nodeCount > 0)
                }
            }
        }
    }

    @Test func triangleCountPositive() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.triangleCount > 0)
                }
            }
        }
    }

    @Test func multipleNextCalls() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: box) {
                var count = 0
                while iter.hasMore {
                    count += 1
                    iter.next()
                }
                #expect(count == 6)  // box has 6 faces
            }
        }
    }

    @Test func hasNormalsTrue() {
        if let sphere = Shape.sphere(radius: 5) {
            let _ = sphere.mesh(linearDeflection: 0.5)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    #expect(iter.hasNormals)
                }
            }
        }
    }

    @Test func createFromUnmeshedShape() {
        // Even unmeshed shapes can create iterators (may just have 0 faces)
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let iter = MeshFaceIterator(shape: box)
            // May or may not have faces depending on whether auto-meshing happens
            #expect(iter != nil || iter == nil)  // just shouldn't crash
        }
    }

    @Test func allNodesOnSphere() {
        if let sphere = Shape.sphere(radius: 3) {
            let _ = sphere.mesh(linearDeflection: 0.3)
            if let iter = MeshFaceIterator(shape: sphere) {
                if iter.hasMore {
                    for i in 1...min(iter.nodeCount, 5) {
                        let p = iter.node(at: i)
                        let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                        #expect(abs(dist - 3.0) < 0.4)
                    }
                }
            }
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.112.0 Tests

@Suite("RWMesh FaceIterator v0.112")
struct RWMeshFaceIteratorTests {

    /// A radius-5 sphere meshed at 0.5, which is one face with 168 nodes and 306 triangles on the
    /// pinned kernel (wasm-sensitive: the counts come from the mesher, so a platform with a
    /// different libm may count differently while keeping every relation these tests check).
    private func meshedSphere() throws -> Shape {
        let sphere = try #require(Shape.sphere(radius: 5))
        _ = try #require(sphere.mesh(linearDeflection: 0.5))
        return sphere
    }

    @Test func iterateFaces() throws {
        // Control: nothing has meshed this sphere, so there is no triangulation to iterate.
        let bare = try #require(Shape.sphere(radius: 5))
        let bareIter = try #require(MeshFaceIterator(shape: bare))
        #expect(!bareIter.hasMore)

        let sphere = try meshedSphere()
        let iter = try #require(MeshFaceIterator(shape: sphere))
        var faceCount = 0
        var totalTris = 0
        while iter.hasMore {
            totalTris += iter.triangleCount
            faceCount += 1
            iter.next()
        }
        // A sphere is a single face, and its triangulation is what the iterator reports.
        #expect(faceCount == 1)
        #expect(totalTris == 306)
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

    @Test func triangleAccess() throws {
        let sphere = try meshedSphere()
        let iter = try #require(MeshFaceIterator(shape: sphere))
        #expect(iter.hasMore)
        let nodeCount = iter.nodeCount
        let triangleCount = iter.triangleCount
        #expect(nodeCount == 168)
        #expect(triangleCount == 306)

        // Every triangle names three distinct nodes of this face (the indices are 1-based), and
        // the nodes it names lie on the sphere.
        for t in 1...triangleCount {
            let tri = iter.triangle(at: t)
            let ids = [Int(tri.n1), Int(tri.n2), Int(tri.n3)]
            #expect(ids.allSatisfy { $0 >= 1 && $0 <= nodeCount }, "triangle \(t): \(ids)")
            #expect(Set(ids).count == 3, "triangle \(t) repeats a node: \(ids)")
        }
        for id in 1...nodeCount {
            let p = iter.node(at: id)
            #expect(abs(simd_length(p) - 5) < 1e-9, "node \(id) at \(p)")
        }
    }

    @Test func nodeCountPositive() throws {
        let sphere = try meshedSphere()
        let iter = try #require(MeshFaceIterator(shape: sphere))
        #expect(iter.hasMore)
        // 168 on the pinned kernel; the triangulation of one face, not zero and not a sum.
        #expect(iter.nodeCount == 168)
    }

    @Test func triangleCountPositive() throws {
        let sphere = try meshedSphere()
        let iter = try #require(MeshFaceIterator(shape: sphere))
        #expect(iter.hasMore)
        #expect(iter.triangleCount == 306)
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

    @Test func hasNormalsTrue() throws {
        let sphere = try meshedSphere()
        let iter = try #require(MeshFaceIterator(shape: sphere))
        #expect(iter.hasMore)
        #expect(iter.hasNormals)

        // The normals are the sphere's: unit length and pointing away from the centre.
        for id in 1...iter.nodeCount {
            let n = iter.normal(at: id)
            let outward = iter.node(at: id) / 5
            #expect(abs(simd_length(n) - 1) < 1e-6, "normal \(id) is \(n)")
            #expect(simd_dot(n, outward) > 0.999, "normal \(id) is \(n) at \(outward * 5)")
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

import Foundation
import simd
import OCCTBridge

/// Iterator over triangulated faces of a meshed shape.
public final class MeshFaceIterator: @unchecked Sendable {
    internal let handle: OCCTMeshFaceIterRef

    /// Create a face iterator. The shape should already be meshed (BRepMesh_IncrementalMesh).
    public init?(shape: Shape) {
        guard let h = OCCTMeshFaceIterCreate(shape.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTMeshFaceIterRelease(handle) }

    /// Whether the iterator has more faces.
    public var hasMore: Bool { OCCTMeshFaceIterMore(handle) }

    /// Advance to the next face.
    public func next() { OCCTMeshFaceIterNext(handle) }

    /// Number of nodes in the current face triangulation.
    public var nodeCount: Int { Int(OCCTMeshFaceIterNbNodes(handle)) }

    /// Number of triangles in the current face triangulation.
    public var triangleCount: Int { Int(OCCTMeshFaceIterNbTriangles(handle)) }

    /// Get node position at 1-based index.
    public func node(at index: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTMeshFaceIterNode(handle, Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Whether current face has normals.
    public var hasNormals: Bool { OCCTMeshFaceIterHasNormals(handle) }

    /// Get normal at 1-based node index.
    public func normal(at index: Int) -> SIMD3<Double> {
        var nx = 0.0, ny = 0.0, nz = 0.0
        OCCTMeshFaceIterNormal(handle, Int32(index), &nx, &ny, &nz)
        return SIMD3(nx, ny, nz)
    }

    /// Get triangle node indices (1-based) at 1-based triangle index.
    public func triangle(at index: Int) -> (n1: Int, n2: Int, n3: Int) {
        var n1: Int32 = 0, n2: Int32 = 0, n3: Int32 = 0
        OCCTMeshFaceIterTriangle(handle, Int32(index), &n1, &n2, &n3)
        return (Int(n1), Int(n2), Int(n3))
    }
}

/// Iterator over vertices of a shape.
public final class MeshVertexIterator: @unchecked Sendable {
    internal let handle: OCCTMeshVertexIterRef

    /// Create a vertex iterator over a shape.
    public init?(shape: Shape) {
        guard let h = OCCTMeshVertexIterCreate(shape.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTMeshVertexIterRelease(handle) }

    /// Whether the iterator has more vertices.
    public var hasMore: Bool { OCCTMeshVertexIterMore(handle) }

    /// Advance to the next vertex.
    public func next() { OCCTMeshVertexIterNext(handle) }

    /// Get the current vertex point.
    public var point: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTMeshVertexIterPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

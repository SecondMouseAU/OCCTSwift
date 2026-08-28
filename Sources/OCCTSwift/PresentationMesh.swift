import Foundation
import OCCTBridge
import simd

/// Interleaved triangle mesh data suitable for Metal vertex buffers.
///
/// Vertices and normals are stored per-vertex. Indices define triangles
/// (3 indices per triangle).
public struct ShadedMeshData: Sendable {
    /// Per-vertex positions.
    public let vertices: [SIMD3<Float>]

    /// Per-vertex normals (same count as vertices).
    public let normals: [SIMD3<Float>]

    /// Triangle indices (3 per triangle, referencing into vertices/normals).
    public let indices: [UInt32]

    /// Number of triangles.
    public var triangleCount: Int { indices.count / 3 }
}

/// Edge wireframe data suitable for Metal line rendering.
///
/// Vertices are 3D positions. `segmentStarts` marks where each edge polyline
/// begins in the vertex array. Segment `i` spans vertices from
/// `segmentStarts[i]` to `segmentStarts[i+1] - 1` (or end of array for the last).
public struct EdgeMeshData: Sendable {
    /// All edge polyline vertices.
    public let vertices: [SIMD3<Float>]

    /// Index where each edge polyline begins.
    public let segmentStarts: [Int]

    /// Number of edge segments.
    public var segmentCount: Int { segmentStarts.count }
}

/// Deinterleaves a populated `OCCTShadedMeshData` buffer into a ``ShadedMeshData``,
/// then frees the buffer.
///
/// Shared by every ``Shape`` overload that populates an `OCCTShadedMeshData` (currently
/// `shadedMesh(deflection:)` and `shadedMesh(drawer:)`), so a future change to this
/// extraction (e.g. a winding or normal-sign correction) only needs to be made once (#1224).
///
/// - Parameter data: An already-populated bridge struct. Consumed and freed by this call.
/// - Returns: The deinterleaved shaded mesh data.
private func buildShadedMeshData(from data: inout OCCTShadedMeshData) -> ShadedMeshData {
    defer { OCCTShadedMeshDataFree(&data) }

    let vertCount = Int(data.vertexCount)
    let triCount = Int(data.triangleCount)

    // Deinterleave positions and normals from the packed buffer
    var positions = [SIMD3<Float>]()
    var normals = [SIMD3<Float>]()
    positions.reserveCapacity(vertCount)
    normals.reserveCapacity(vertCount)

    for i in 0..<vertCount {
        let base = i * 6
        positions.append(
            SIMD3(
                data.vertices[base],
                data.vertices[base + 1],
                data.vertices[base + 2]))
        normals.append(
            SIMD3(
                data.vertices[base + 3],
                data.vertices[base + 4],
                data.vertices[base + 5]))
    }

    // Copy indices
    var indices = [UInt32]()
    indices.reserveCapacity(triCount * 3)
    for i in 0..<(triCount * 3) {
        indices.append(UInt32(data.indices[i]))
    }

    return ShadedMeshData(vertices: positions, normals: normals, indices: indices)
}

/// Deinterleaves a populated `OCCTEdgeMeshData` buffer into an ``EdgeMeshData``,
/// then frees the buffer.
///
/// Shared by every ``Shape`` overload that populates an `OCCTEdgeMeshData` (currently
/// `edgeMesh(deflection:)` and `edgeMesh(drawer:)`), so a future change to this
/// extraction only needs to be made once (#1224).
///
/// - Parameter data: An already-populated bridge struct. Consumed and freed by this call.
/// - Returns: The deinterleaved edge mesh data.
private func buildEdgeMeshData(from data: inout OCCTEdgeMeshData) -> EdgeMeshData {
    defer { OCCTEdgeMeshDataFree(&data) }

    let vertCount = Int(data.vertexCount)
    let segCount = Int(data.segmentCount)

    var positions = [SIMD3<Float>]()
    positions.reserveCapacity(vertCount)
    for i in 0..<vertCount {
        let base = i * 3
        positions.append(
            SIMD3(
                data.vertices[base],
                data.vertices[base + 1],
                data.vertices[base + 2]))
    }

    var starts = [Int]()
    starts.reserveCapacity(segCount)
    for i in 0..<segCount {
        starts.append(Int(data.segmentStarts[i]))
    }

    return EdgeMeshData(vertices: positions, segmentStarts: starts)
}

extension Shape {
    /// Extract a triangulated mesh from the shape for shaded rendering.
    ///
    /// - Parameter deflection: Tessellation chord deviation. Smaller values produce
    ///   finer meshes. Default is 0.1.
    /// - Returns: Shaded mesh data, or `nil` if tessellation fails.
    public func shadedMesh(deflection: Double = 0.1) -> ShadedMeshData? {
        var data = OCCTShadedMeshData()
        guard OCCTShapeGetShadedMesh(handle, deflection, &data) else {
            return nil
        }
        return buildShadedMeshData(from: &data)
    }

    /// Extract edge wireframe polylines from the shape.
    ///
    /// - Parameter deflection: Tessellation chord deviation. Default is 0.1.
    /// - Returns: Edge mesh data, or `nil` if extraction fails.
    public func edgeMesh(deflection: Double = 0.1) -> EdgeMeshData? {
        var data = OCCTEdgeMeshData()
        guard OCCTShapeGetEdgeMesh(handle, deflection, &data) else {
            return nil
        }
        return buildEdgeMeshData(from: &data)
    }

    /// Extract a triangulated mesh using a ``DisplayDrawer`` for tessellation control.
    ///
    /// The drawer's deflection type, deviation coefficient/angle, and other
    /// tessellation parameters are used instead of a fixed deflection value.
    ///
    /// - Parameter drawer: The display drawer controlling tessellation quality.
    /// - Returns: Shaded mesh data, or `nil` if tessellation fails.
    public func shadedMesh(drawer: DisplayDrawer) -> ShadedMeshData? {
        var data = OCCTShadedMeshData()
        guard OCCTShapeGetShadedMeshWithDrawer(handle, drawer.handle, &data) else {
            return nil
        }
        return buildShadedMeshData(from: &data)
    }

    /// Extract edge wireframe polylines using a ``DisplayDrawer`` for tessellation control.
    ///
    /// - Parameter drawer: The display drawer controlling tessellation quality.
    /// - Returns: Edge mesh data, or `nil` if extraction fails.
    public func edgeMesh(drawer: DisplayDrawer) -> EdgeMeshData? {
        var data = OCCTEdgeMeshData()
        guard OCCTShapeGetEdgeMeshWithDrawer(handle, drawer.handle, &data) else {
            return nil
        }
        return buildEdgeMeshData(from: &data)
    }
}

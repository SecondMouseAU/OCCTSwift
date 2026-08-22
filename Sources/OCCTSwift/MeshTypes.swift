import Foundation
import OCCTBridge
import simd

/// A 2D polygon (sequence of 2D points).
public final class Polygon2D: @unchecked Sendable {
    let handle: OCCTPolyPolygon2DRef

    init(handle: OCCTPolyPolygon2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTPolyPolygon2DRelease(handle)
    }

    /// Create a 2D polygon from points.
    public static func create(points: [SIMD2<Double>]) -> Polygon2D? {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 2)
        for p in points {
            flat.append(p.x)
            flat.append(p.y)
        }
        guard
            let ref = flat.withUnsafeBufferPointer({ buf in
                OCCTPolyPolygon2DCreate(buf.baseAddress!, Int32(points.count))
            })
        else { return nil }
        return Polygon2D(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int {
        Int(OCCTPolyPolygon2DNbNodes(handle))
    }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD2<Double>? {
        var x: Double = 0
        var y: Double = 0
        guard OCCTPolyPolygon2DNode(handle, Int32(index), &x, &y) else { return nil }
        return SIMD2(x, y)
    }

    /// All nodes.
    public func nodes() -> [SIMD2<Double>] {
        (0..<nodeCount).compactMap { node(at: $0) }
    }

    /// Deflection value.
    public var deflection: Double {
        get { OCCTPolyPolygon2DDeflection(handle) }
        set { OCCTPolyPolygon2DSetDeflection(handle, newValue) }
    }

    /// Create a deep copy of this polygon (`Poly_Polygon2D::Copy()`).
    public func copy() -> Polygon2D? {
        guard let ref = OCCTPolyPolygon2DCopy(handle) else { return nil }
        return Polygon2D(handle: ref)
    }
}

/// A `Poly_Triangulation` — a 3D mesh defined by node positions and triangle vertex indices.
///
/// Used as input to `BRepGraph.createTriangulationRep(_:)` when populating the cached
/// mesh tier of a graph (`BRepGraph_MeshCache`). Triangle indices are 0-based on the Swift
/// boundary; the bridge handles the OCCT 1-based conversion internally.
public final class Triangulation: @unchecked Sendable {
    let handle: OCCTPolyTriangulationRef

    init(handle: OCCTPolyTriangulationRef) {
        self.handle = handle
    }

    deinit {
        OCCTPolyTriangulationRelease(handle)
    }

    /// Create a triangulation from nodes and triangle vertex indices.
    /// - Parameter nodes: sequence of node positions.
    /// - Parameter triangles: triangle vertex indices, 0-based, three per triangle.
    /// - Returns: nil if any index is out of range or the inputs are empty.
    public static func create(nodes: [SIMD3<Double>], triangles: [Int]) -> Triangulation? {
        guard !nodes.isEmpty, triangles.count > 0, triangles.count % 3 == 0 else { return nil }
        for idx in triangles where idx < 0 || idx >= nodes.count { return nil }
        var flatNodes = [Double]()
        flatNodes.reserveCapacity(nodes.count * 3)
        for n in nodes {
            flatNodes.append(n.x)
            flatNodes.append(n.y)
            flatNodes.append(n.z)
        }
        let triInts = triangles.map { Int32($0) }
        guard
            let ref = flatNodes.withUnsafeBufferPointer({ nodeBuf in
                triInts.withUnsafeBufferPointer { triBuf in
                    OCCTPolyTriangulationCreate(
                        nodeBuf.baseAddress!, Int32(nodes.count),
                        triBuf.baseAddress!, Int32(triangles.count / 3))
                }
            })
        else { return nil }
        return Triangulation(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int { Int(OCCTPolyTriangulationNbNodes(handle)) }

    /// Number of triangles.
    public var triangleCount: Int { Int(OCCTPolyTriangulationNbTriangles(handle)) }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        guard OCCTPolyTriangulationNode(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get triangle's three node indices at the given triangle index (0-based; returns 0-based vertex indices).
    public func triangle(at index: Int) -> (Int, Int, Int)? {
        var n1: Int32 = 0
        var n2: Int32 = 0
        var n3: Int32 = 0
        guard OCCTPolyTriangulationTriangle(handle, Int32(index), &n1, &n2, &n3) else { return nil }
        return (Int(n1), Int(n2), Int(n3))
    }

    /// Deflection value.
    public var deflection: Double {
        get { OCCTPolyTriangulationDeflection(handle) }
        set { OCCTPolyTriangulationSetDeflection(handle, newValue) }
    }
}

/// A 3D polygon (sequence of 3D points with optional parameters).
public final class Polygon3D: @unchecked Sendable {
    let handle: OCCTPolyPolygon3DRef

    init(handle: OCCTPolyPolygon3DRef) {
        self.handle = handle
    }

    deinit {
        OCCTPolyPolygon3DRelease(handle)
    }

    /// Create a 3D polygon from points.
    public static func create(points: [SIMD3<Double>]) -> Polygon3D? {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        guard
            let ref = flat.withUnsafeBufferPointer({ buf in
                OCCTPolyPolygon3DCreate(buf.baseAddress!, Int32(points.count))
            })
        else { return nil }
        return Polygon3D(handle: ref)
    }

    /// Create a 3D polygon from points with parameters.
    public static func create(points: [SIMD3<Double>], parameters: [Double]) -> Polygon3D? {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        guard
            let ref = flat.withUnsafeBufferPointer({ ptsBuf in
                parameters.withUnsafeBufferPointer { paramBuf in
                    OCCTPolyPolygon3DCreateWithParams(
                        ptsBuf.baseAddress!, Int32(points.count), paramBuf.baseAddress!)
                }
            })
        else { return nil }
        return Polygon3D(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int {
        Int(OCCTPolyPolygon3DNbNodes(handle))
    }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        guard OCCTPolyPolygon3DNode(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// All nodes.
    public func nodes() -> [SIMD3<Double>] {
        (0..<nodeCount).compactMap { node(at: $0) }
    }

    /// Whether this polygon has parameters.
    public var hasParameters: Bool {
        OCCTPolyPolygon3DHasParameters(handle)
    }

    /// Get parameter at index (0-based).
    public func parameter(at index: Int) -> Double {
        OCCTPolyPolygon3DParameter(handle, Int32(index))
    }

    /// Deflection value.
    public var deflection: Double {
        get { OCCTPolyPolygon3DDeflection(handle) }
        set { OCCTPolyPolygon3DSetDeflection(handle, newValue) }
    }
}

/// A polygon defined as indices into a shared triangulation.
public final class PolygonOnTriangulation: @unchecked Sendable {
    let handle: OCCTPolyPolygonOnTriRef

    init(handle: OCCTPolyPolygonOnTriRef) {
        self.handle = handle
    }

    deinit {
        OCCTPolyPolygonOnTriRelease(handle)
    }

    /// Create from node indices.
    public static func create(nodeIndices: [Int32]) -> PolygonOnTriangulation? {
        guard
            let ref = nodeIndices.withUnsafeBufferPointer({ buf in
                OCCTPolyPolygonOnTriCreate(buf.baseAddress!, Int32(nodeIndices.count))
            })
        else { return nil }
        return PolygonOnTriangulation(handle: ref)
    }

    /// Create from node indices with parameters.
    public static func create(nodeIndices: [Int32], parameters: [Double]) -> PolygonOnTriangulation?
    {
        guard
            let ref = nodeIndices.withUnsafeBufferPointer({ idxBuf in
                parameters.withUnsafeBufferPointer { paramBuf in
                    OCCTPolyPolygonOnTriCreateWithParams(
                        idxBuf.baseAddress!, Int32(nodeIndices.count), paramBuf.baseAddress!)
                }
            })
        else { return nil }
        return PolygonOnTriangulation(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int {
        Int(OCCTPolyPolygonOnTriNbNodes(handle))
    }

    /// Get node index at position (0-based).
    public func nodeIndex(at position: Int) -> Int {
        Int(OCCTPolyPolygonOnTriNode(handle, Int32(position)))
    }

    /// Whether this polygon has parameters.
    public var hasParameters: Bool {
        OCCTPolyPolygonOnTriHasParameters(handle)
    }

    /// Get parameter at index (0-based).
    public func parameter(at index: Int) -> Double {
        OCCTPolyPolygonOnTriParameter(handle, Int32(index))
    }

    /// Deflection value.
    public var deflection: Double {
        get { OCCTPolyPolygonOnTriDeflection(handle) }
        set { OCCTPolyPolygonOnTriSetDeflection(handle, newValue) }
    }

    /// Create a deep copy of this polygon (`Poly_PolygonOnTriangulation::Copy()`).
    public func copy() -> PolygonOnTriangulation? {
        guard let ref = OCCTPolyPolygonOnTriCopy(handle) else { return nil }
        return PolygonOnTriangulation(handle: ref)
    }

    /// Overwrite the node-index array in place (`ChangeNodeArray()`).
    /// The supplied array must have the same length as `nodeCount`.
    /// - Returns: true on success, false on size mismatch.
    @discardableResult
    public func setNodes(_ nodeIndices: [Int32]) -> Bool {
        nodeIndices.withUnsafeBufferPointer { buf in
            OCCTPolyPolygonOnTriSetNodes(handle, buf.baseAddress!, Int32(nodeIndices.count))
        }
    }

    /// Overwrite the parameter array in place (`ChangeParameterArray()`).
    /// Requires `hasParameters` and an array length equal to `nodeCount`.
    /// - Returns: true on success, false otherwise.
    @discardableResult
    public func setParameters(_ params: [Double]) -> Bool {
        params.withUnsafeBufferPointer { buf in
            OCCTPolyPolygonOnTriSetParameters(handle, buf.baseAddress!, Int32(params.count))
        }
    }
}

/// Result of merging triangulation nodes.
public struct MergedMeshData: Sendable {
    public let vertices: [SIMD3<Float>]
    public let normals: [SIMD3<Float>]
    public let indices: [UInt32]
    public let triangleCount: Int
    public let vertexCount: Int
}

/// Merge nodes from all face triangulations of a meshed shape.
/// - Parameters:
///   - shape: A shape that has been triangulated (e.g., via Mesh.from(shape:))
///   - smoothAngle: Normal smoothing angle threshold in radians
///   - mergeTolerance: Distance threshold for merging nodes (0 = positional only)
/// - Returns: Merged mesh data, or nil on failure
public func mergedMeshNodes(
    from shape: Shape,
    smoothAngle: Double,
    mergeTolerance: Double = 0.0
) -> MergedMeshData? {
    let maxVerts: Int32 = 1_000_000
    let maxIdx: Int32 = 3_000_000
    var vertices = [Float](repeating: 0, count: Int(maxVerts) * 3)
    var normals = [Float](repeating: 0, count: Int(maxVerts) * 3)
    var indices = [UInt32](repeating: 0, count: Int(maxIdx))
    var triCount: Int32 = 0

    let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
        normals.withUnsafeMutableBufferPointer { nBuf in
            indices.withUnsafeMutableBufferPointer { iBuf in
                OCCTPolyMergeNodes(
                    shape.handle, smoothAngle, mergeTolerance,
                    vBuf.baseAddress, nBuf.baseAddress,
                    iBuf.baseAddress,
                    maxVerts, maxIdx,
                    &triCount)
            }
        }
    }
    if nVerts == 0 { return nil }

    let nv = Int(nVerts)
    let nt = Int(triCount)
    let verts: [SIMD3<Float>] = unpackSIMD3(vertices, count: nv)
    let norms: [SIMD3<Float>] = unpackSIMD3(normals, count: nv)
    let idxSlice = Array(indices.prefix(nt * 3))

    return MergedMeshData(
        vertices: verts, normals: norms, indices: idxSlice,
        triangleCount: nt, vertexCount: nv)
}

/// Mutable coherent triangulation for mesh editing operations.
public final class CoherentTriangulation: @unchecked Sendable {
    let handle: OCCTCoherentTriangulationRef

    init(handle: OCCTCoherentTriangulationRef) {
        self.handle = handle
    }

    deinit {
        OCCTCoherentTriangulationRelease(handle)
    }

    /// Create an empty coherent triangulation.
    public static func create() -> CoherentTriangulation {
        let ref = OCCTCoherentTriangulationCreate()!
        return CoherentTriangulation(handle: ref)
    }

    /// Create a coherent triangulation from a meshed shape's first face triangulation.
    /// - Parameter deflection: Linear mesh deflection (mm) for the auto-triangulation. Default `0.1`.
    public static func createFromMesh(_ shape: Shape, deflection: Double = 0.1)
        -> CoherentTriangulation?
    {
        guard let ref = OCCTCoherentTriangulationCreateFromMesh(shape.handle, deflection) else {
            return nil
        }
        return CoherentTriangulation(handle: ref)
    }

    /// Add a node at (x, y, z). Returns the 0-based node index.
    public func setNode(x: Double, y: Double, z: Double) -> Int {
        Int(OCCTCoherentTriangulationSetNode(handle, x, y, z))
    }

    /// Add a triangle from three 0-based node indices. Returns true on success.
    @discardableResult
    public func addTriangle(_ n0: Int, _ n1: Int, _ n2: Int) -> Bool {
        OCCTCoherentTriangulationAddTriangle(handle, Int32(n0), Int32(n1), Int32(n2))
    }

    /// Remove a triangle by 0-based index. Returns true on success.
    @discardableResult
    public func removeTriangle(at index: Int) -> Bool {
        OCCTCoherentTriangulationRemoveTriangle(handle, Int32(index))
    }

    /// Number of triangles.
    public var triangleCount: Int {
        Int(OCCTCoherentTriangulationNTriangles(handle))
    }

    /// Compute edge links between triangles. Returns the number of links.
    public func computeLinks() -> Int {
        Int(OCCTCoherentTriangulationComputeLinks(handle))
    }

    /// Number of links (edges). Call computeLinks() first.
    public var linkCount: Int {
        Int(OCCTCoherentTriangulationNLinks(handle))
    }

    /// Set the deflection value.
    public func setDeflection(_ value: Double) {
        OCCTCoherentTriangulationSetDeflection(handle, value)
    }

    /// Get the deflection value.
    public var deflection: Double {
        OCCTCoherentTriangulationDeflection(handle)
    }

    /// Remove degenerated triangles within tolerance. Returns true if any were removed.
    @discardableResult
    public func removeDegenerated(tolerance: Double) -> Bool {
        OCCTCoherentTriangulationRemoveDegenerated(handle, tolerance)
    }

    /// Convert back to standard triangulation data. Returns (nodeCount, triangleCount) or nil.
    public func getResult() -> (nodeCount: Int, triangleCount: Int)? {
        var nbNodes: Int32 = 0
        var nbTris: Int32 = 0
        guard OCCTCoherentTriangulationGetResult(handle, &nbNodes, &nbTris) else { return nil }
        return (Int(nbNodes), Int(nbTris))
    }

    /// Get node coordinates by 1-based index (after getResult).
    public func nodeCoords(at index: Int) -> (x: Double, y: Double, z: Double)? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTCoherentTriangulationNodeCoords(handle, Int32(index), &x, &y, &z) else {
            return nil
        }
        return (x, y, z)
    }
}

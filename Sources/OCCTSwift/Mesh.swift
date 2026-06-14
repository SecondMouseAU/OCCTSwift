import Foundation
import simd
import OCCTBridge

#if canImport(SceneKit)
import SceneKit
#endif

// MARK: - Mesh Parameters

/// Enhanced parameters for controlling mesh tessellation.
///
/// Use these parameters for fine-grained control over mesh quality,
/// especially for CAM toolpath generation or high-quality visualization.
///
/// ## Example
///
/// ```swift
/// var params = MeshParameters.default
/// params.deflection = 0.05  // Fine mesh
/// params.inParallel = true  // Use multiple threads
/// let mesh = shape.mesh(parameters: params)
/// ```
public struct MeshParameters: Sendable {
    /// Linear deflection for boundary edges (maximum chord deviation).
    public var deflection: Double

    /// Angular deflection for boundary edges (radians).
    public var angle: Double

    /// Linear deflection for face interior (0 = same as deflection).
    public var deflectionInterior: Double

    /// Angular deflection for face interior (0 = same as angle).
    public var angleInterior: Double

    /// Minimum element size (0 = no minimum).
    public var minSize: Double

    /// Use relative deflection (proportion of edge size).
    public var relative: Bool

    /// Enable multi-threaded meshing for faster processing.
    public var inParallel: Bool

    /// Generate vertices inside faces (not just on edges).
    public var internalVertices: Bool

    /// Validate surface approximation quality.
    public var controlSurfaceDeflection: Bool

    /// Auto-adjust minSize based on edge size.
    public var adjustMinSize: Bool

    /// Default mesh parameters suitable for interactive display.
    public static var `default`: MeshParameters {
        MeshParameters(
            deflection: 0.1,
            angle: 0.5,
            deflectionInterior: 0,
            angleInterior: 0,
            minSize: 0,
            relative: false,
            inParallel: true,
            internalVertices: true,
            controlSurfaceDeflection: true,
            adjustMinSize: false
        )
    }

    /// Convert to C bridge parameters.
    internal func toBridge() -> OCCTMeshParameters {
        var params = OCCTMeshParameters()
        params.deflection = deflection
        params.angle = angle
        params.deflectionInterior = deflectionInterior
        params.angleInterior = angleInterior
        params.minSize = minSize
        params.relative = relative
        params.inParallel = inParallel
        params.internalVertices = internalVertices
        params.controlSurfaceDeflection = controlSurfaceDeflection
        params.adjustMinSize = adjustMinSize
        return params
    }
}

// MARK: - Triangle with Face Info

/// A mesh triangle with B-Rep face association and normal.
///
/// Use for CAM operations that need to know which B-Rep face
/// each triangle came from, or for per-triangle normal access.
public struct Triangle: Sendable {
    /// Index of first vertex.
    public let v1: UInt32

    /// Index of second vertex.
    public let v2: UInt32

    /// Index of third vertex.
    public let v3: UInt32

    /// Source B-Rep face index (-1 if unknown).
    ///
    /// This allows correlating mesh triangles back to the original
    /// solid faces, useful for CAM operations like selective re-meshing.
    public let faceIndex: Int32

    /// Triangle normal vector.
    public let normal: SIMD3<Float>
}

/// A triangulated mesh representation of a shape.
///
/// Meshes are created by tessellating a `Shape` and contain triangle data
/// suitable for visualization (SceneKit, RealityKit) or export (STL, OBJ).
///
/// ## Creating a Mesh
///
/// ```swift
/// let box = Shape.box(width: 10, height: 5, depth: 3)
/// let mesh = box.mesh(linearDeflection: 0.1)
/// ```
///
/// ## Deflection Parameters
///
/// The quality of tessellation is controlled by deflection:
/// - **linearDeflection**: Maximum distance between mesh and true surface (mm)
/// - **angularDeflection**: Maximum angle between adjacent triangles (radians)
///
/// Smaller values = more triangles = smoother appearance = larger files.
///
/// | Use Case | Linear | Angular |
/// |----------|--------|---------|
/// | Quick preview | 0.5 | 1.0 |
/// | Interactive display | 0.1 | 0.5 |
/// | 3D printing (FDM) | 0.05 | 0.3 |
/// | 3D printing (SLA) | 0.02 | 0.2 |
///
/// ## Using with SceneKit
///
/// ```swift
/// let geometry = mesh.sceneKitGeometry()
/// geometry.materials = [myMaterial]
/// let node = SCNNode(geometry: geometry)
/// scene.rootNode.addChildNode(node)
/// ```
public final class Mesh: @unchecked Sendable {
    internal let handle: OCCTMeshRef

    internal init(handle: OCCTMeshRef) {
        self.handle = handle
    }

    /// Construct a Mesh directly from raw triangulation arrays.
    ///
    /// Use this when you have vertex/index data from a mesh-domain algorithm
    /// (decimation, smoothing, repair, remeshing, OBJ/STL/glTF import) and don't
    /// have a B-Rep source. For meshes derived from OCCT shapes, use `Shape.mesh()`.
    ///
    /// - Parameters:
    ///   - vertices: per-vertex positions; length is the vertex count.
    ///   - normals: optional per-vertex normals; if provided, must match `vertices.count`.
    ///     If `nil`, per-vertex normals are computed by averaging the face normals of
    ///     adjacent triangles (smooth shading default).
    ///   - indices: triangle indices; length must be a multiple of 3, and each value
    ///     must be `< vertices.count`.
    /// - Returns: `nil` if inputs are invalid (empty, mismatched normal count,
    ///   index count not divisible by 3, or any index out of bounds).
    public convenience init?(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>]? = nil,
        indices: [UInt32]
    ) {
        guard !vertices.isEmpty, !indices.isEmpty, indices.count % 3 == 0 else {
            return nil
        }
        if let normals, normals.count != vertices.count {
            return nil
        }
        let vertexCount = UInt32(vertices.count)
        for idx in indices where idx >= vertexCount {
            return nil
        }

        // Flatten SIMD3 → contiguous Float buffers.
        var vertexFloats = [Float](repeating: 0, count: vertices.count * 3)
        for (i, v) in vertices.enumerated() {
            vertexFloats[i * 3 + 0] = v.x
            vertexFloats[i * 3 + 1] = v.y
            vertexFloats[i * 3 + 2] = v.z
        }

        var normalFloatsStorage: [Float]?
        if let normals {
            var n = [Float](repeating: 0, count: normals.count * 3)
            for (i, vec) in normals.enumerated() {
                n[i * 3 + 0] = vec.x
                n[i * 3 + 1] = vec.y
                n[i * 3 + 2] = vec.z
            }
            normalFloatsStorage = n
        }

        let handle: OCCTMeshRef? = vertexFloats.withUnsafeBufferPointer { vbuf in
            indices.withUnsafeBufferPointer { ibuf in
                if var nFloats = normalFloatsStorage {
                    return nFloats.withUnsafeBufferPointer { nbuf in
                        OCCTMeshCreateFromArrays(
                            vbuf.baseAddress,
                            UInt32(vertices.count),
                            nbuf.baseAddress,
                            ibuf.baseAddress,
                            UInt32(indices.count)
                        )
                    }
                } else {
                    return OCCTMeshCreateFromArrays(
                        vbuf.baseAddress,
                        UInt32(vertices.count),
                        nil,
                        ibuf.baseAddress,
                        UInt32(indices.count)
                    )
                }
            }
        }

        guard let h = handle else { return nil }
        self.init(handle: h)
    }

    deinit {
        OCCTMeshRelease(handle)
    }

    // MARK: - Mesh Data

    /// Number of vertices in the mesh.
    public var vertexCount: Int {
        Int(OCCTMeshGetVertexCount(handle))
    }

    /// Number of triangles in the mesh.
    public var triangleCount: Int {
        Int(OCCTMeshGetTriangleCount(handle))
    }

    /// Vertex positions as array of SIMD3<Float>.
    ///
    /// Each vertex is a 3D point (x, y, z).
    /// Array length equals `vertexCount`.
    public var vertices: [SIMD3<Float>] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var floats = [Float](repeating: 0, count: count * 3)
        floats.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetVertices(handle, buffer.baseAddress)
        }

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(SIMD3(
                floats[i * 3],
                floats[i * 3 + 1],
                floats[i * 3 + 2]
            ))
        }
        return result
    }

    /// Vertex normals as array of SIMD3<Float>.
    ///
    /// Each normal is a unit vector perpendicular to the surface at that vertex.
    /// Array length equals `vertexCount`.
    public var normals: [SIMD3<Float>] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var floats = [Float](repeating: 0, count: count * 3)
        floats.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetNormals(handle, buffer.baseAddress)
        }

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(SIMD3(
                floats[i * 3],
                floats[i * 3 + 1],
                floats[i * 3 + 2]
            ))
        }
        return result
    }

    /// Triangle indices as array of UInt32.
    ///
    /// Every three consecutive indices define one triangle.
    /// Array length equals `triangleCount * 3`.
    ///
    /// ```swift
    /// // Triangle 0 uses vertices at indices[0], indices[1], indices[2]
    /// // Triangle 1 uses vertices at indices[3], indices[4], indices[5]
    /// // etc.
    /// ```
    public var indices: [UInt32] {
        let count = triangleCount
        guard count > 0 else { return [] }

        var result = [UInt32](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetIndices(handle, buffer.baseAddress)
        }
        return result
    }

    /// Raw vertex data as contiguous Float array.
    ///
    /// Format: [x0, y0, z0, x1, y1, z1, ...]
    /// Length: `vertexCount * 3`
    public var vertexData: [Float] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetVertices(handle, buffer.baseAddress)
        }
        return result
    }

    /// Raw normal data as contiguous Float array.
    ///
    /// Format: [nx0, ny0, nz0, nx1, ny1, nz1, ...]
    /// Length: `vertexCount * 3`
    public var normalData: [Float] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetNormals(handle, buffer.baseAddress)
        }
        return result
    }

    // MARK: - Statistics

    /// Bounding box of the mesh.
    ///
    /// Returns (min, max) corners of the axis-aligned bounding box.
    public var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        let verts = vertices
        guard !verts.isEmpty else {
            return (.zero, .zero)
        }

        var minPt = verts[0]
        var maxPt = verts[0]

        for v in verts {
            minPt = min(minPt, v)
            maxPt = max(maxPt, v)
        }

        return (minPt, maxPt)
    }

    /// Size of the mesh in each dimension.
    public var size: SIMD3<Float> {
        let (minPt, maxPt) = boundingBox
        return maxPt - minPt
    }

    /// Center point of the mesh.
    public var center: SIMD3<Float> {
        let (minPt, maxPt) = boundingBox
        return (minPt + maxPt) / 2
    }

    // MARK: - Triangle Access with Face Info

    /// Get triangles with B-Rep face association and normals.
    ///
    /// This method provides access to per-triangle data including:
    /// - Vertex indices
    /// - Source B-Rep face index (for correlating with original solid)
    /// - Per-triangle normal vector
    ///
    /// Useful for CAM operations that need to distinguish triangles
    /// by their source face, or for custom rendering with per-triangle normals.
    ///
    /// - Returns: Array of `Triangle` structs
    public func trianglesWithFaces() -> [Triangle] {
        let count = triangleCount
        guard count > 0 else { return [] }

        var cTriangles = [OCCTTriangle](repeating: OCCTTriangle(), count: count)
        let written = cTriangles.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetTrianglesWithFaces(handle, buffer.baseAddress)
        }

        guard written > 0 else { return [] }

        var result: [Triangle] = []
        result.reserveCapacity(Int(written))

        for i in 0..<Int(written) {
            let t = cTriangles[i]
            result.append(Triangle(
                v1: t.v1,
                v2: t.v2,
                v3: t.v3,
                faceIndex: t.faceIndex,
                normal: SIMD3(t.nx, t.ny, t.nz)
            ))
        }

        return result
    }

    // MARK: - Mesh to Shape Conversion

    /// Convert this mesh to a B-Rep shape.
    ///
    /// The mesh triangles are converted to B-Rep faces and sewn together.
    /// This is useful for performing B-Rep operations on mesh data,
    /// such as boolean operations.
    ///
    /// - Note: The resulting shape is a shell/compound of planar faces.
    ///         It may not be a valid solid depending on the mesh topology.
    ///
    /// - Parameter weldTolerance: Vertex-merge tolerance used to sew adjacent triangle
    ///   faces into a shell, in model units. This must scale with the mesh's coordinate
    ///   magnitude — a value too small for a large-coordinate mesh leaves shared edges
    ///   unmerged and yields an open shell. The default (`1e-6`) suits meshes around unit
    ///   scale; raise it for large parts. Must be positive.
    /// - Returns: A `Shape` representing the mesh geometry, or `nil` on failure
    public func toShape(weldTolerance: Double = 1e-6) -> Shape? {
        guard let shapeHandle = OCCTMeshToShapeWithTolerance(handle, weldTolerance) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    // MARK: - Mesh Boolean Operations

    /// Perform boolean union with another mesh.
    ///
    /// This operation uses a B-Rep roundtrip: both meshes are converted
    /// to B-Rep shapes, the union is computed, and the result is re-meshed.
    ///
    /// - Parameters:
    ///   - other: The mesh to union with
    ///   - deflection: Deflection for re-meshing the result (default: 0.1)
    /// - Returns: The union mesh, or `nil` on failure
    public func union(with other: Mesh, deflection: Double = 0.1) -> Mesh? {
        guard let resultHandle = OCCTMeshUnion(handle, other.handle, deflection) else {
            return nil
        }
        return Mesh(handle: resultHandle)
    }

    /// Subtract another mesh from this mesh.
    ///
    /// This operation uses a B-Rep roundtrip: both meshes are converted
    /// to B-Rep shapes, the subtraction is computed, and the result is re-meshed.
    ///
    /// - Parameters:
    ///   - other: The mesh to subtract
    ///   - deflection: Deflection for re-meshing the result (default: 0.1)
    /// - Returns: The difference mesh, or `nil` on failure
    public func subtracting(_ other: Mesh, deflection: Double = 0.1) -> Mesh? {
        guard let resultHandle = OCCTMeshSubtract(handle, other.handle, deflection) else {
            return nil
        }
        return Mesh(handle: resultHandle)
    }

    /// Intersect with another mesh.
    ///
    /// This operation uses a B-Rep roundtrip: both meshes are converted
    /// to B-Rep shapes, the intersection is computed, and the result is re-meshed.
    ///
    /// - Parameters:
    ///   - other: The mesh to intersect with
    ///   - deflection: Deflection for re-meshing the result (default: 0.1)
    /// - Returns: The intersection mesh, or `nil` on failure
    public func intersection(with other: Mesh, deflection: Double = 0.1) -> Mesh? {
        guard let resultHandle = OCCTMeshIntersect(handle, other.handle, deflection) else {
            return nil
        }
        return Mesh(handle: resultHandle)
    }
}

// MARK: - SceneKit Integration

#if canImport(SceneKit)
extension Mesh {
    /// Create a SceneKit geometry from this mesh.
    ///
    /// - Returns: An `SCNGeometry` suitable for use in a SceneKit scene
    ///
    /// The geometry includes vertex positions and normals.
    /// Apply materials separately:
    ///
    /// ```swift
    /// let geometry = mesh.sceneKitGeometry()
    ///
    /// let material = SCNMaterial()
    /// material.diffuse.contents = UIColor.gray
    /// material.metalness.contents = 0.8
    /// geometry.materials = [material]
    ///
    /// let node = SCNNode(geometry: geometry)
    /// ```
    public func sceneKitGeometry() -> SCNGeometry {
        let vertexData = self.vertexData
        let normalData = self.normalData
        let indexData = self.indices

        guard !vertexData.isEmpty else {
            // Return empty geometry
            return SCNGeometry()
        }

        // Create geometry sources
        let vertexSource = SCNGeometrySource(
            data: Data(bytes: vertexData, count: vertexData.count * MemoryLayout<Float>.size),
            semantic: .vertex,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        let normalSource = SCNGeometrySource(
            data: Data(bytes: normalData, count: normalData.count * MemoryLayout<Float>.size),
            semantic: .normal,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        // Create geometry element (triangle indices)
        let element = SCNGeometryElement(
            data: Data(bytes: indexData, count: indexData.count * MemoryLayout<UInt32>.size),
            primitiveType: .triangles,
            primitiveCount: triangleCount,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }

    /// Create a SceneKit node with this mesh and optional material.
    ///
    /// - Parameter material: Optional material to apply
    /// - Returns: An `SCNNode` ready to add to a scene
    public func sceneKitNode(material: SCNMaterial? = nil) -> SCNNode {
        let geometry = sceneKitGeometry()
        if let material = material {
            geometry.materials = [material]
        }
        return SCNNode(geometry: geometry)
    }
}
#endif

// MARK: - Metal Integration

extension Mesh {
    /// Get vertex data suitable for Metal buffers.
    ///
    /// - Returns: Tuple of (positions, normals, indices) as Data objects
    ///
    /// Use with `MTLDevice.makeBuffer(bytes:length:options:)`:
    ///
    /// ```swift
    /// let (positions, normals, indices) = mesh.metalBufferData()
    /// let vertexBuffer = device.makeBuffer(
    ///     bytes: positions.bytes,
    ///     length: positions.count,
    ///     options: .storageModeShared
    /// )
    /// ```
    public func metalBufferData() -> (positions: Data, normals: Data, indices: Data) {
        let vertexData = self.vertexData
        let normalData = self.normalData
        let indexData = self.indices

        let positionsData = Data(bytes: vertexData, count: vertexData.count * MemoryLayout<Float>.size)
        let normalsData = Data(bytes: normalData, count: normalData.count * MemoryLayout<Float>.size)
        let indicesData = Data(bytes: indexData, count: indexData.count * MemoryLayout<UInt32>.size)

        return (positionsData, normalsData, indicesData)
    }
}

// MARK: - RealityKit Integration

#if canImport(RealityKit)
import RealityKit

@available(iOS 18.0, macOS 15.0, *)
extension Mesh {
    /// Create a RealityKit MeshResource from this mesh.
    ///
    /// Use this method to display OCCT geometry in RealityKit-based viewports.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 5, depth: 3)
    /// let mesh = box.mesh(linearDeflection: 0.1)
    /// let meshResource = try mesh.realityKitMeshResource()
    ///
    /// let material = SimpleMaterial(color: .gray, isMetallic: true)
    /// let entity = ModelEntity(mesh: meshResource, materials: [material])
    /// ```
    ///
    /// - Returns: A `MeshResource` suitable for RealityKit
    /// - Throws: An error if mesh generation fails
    @MainActor
    public func realityKitMeshResource() throws -> MeshResource {
        let verts = vertices
        let norms = normals
        let inds = indices

        guard !verts.isEmpty else {
            // Return empty mesh
            var descriptor = MeshDescriptor()
            descriptor.positions = MeshBuffers.Positions([])
            descriptor.primitives = .triangles([])
            return try MeshResource.generate(from: [descriptor])
        }

        var descriptor = MeshDescriptor()

        // Set positions
        descriptor.positions = MeshBuffers.Positions(verts)

        // Set normals
        descriptor.normals = MeshBuffers.Normals(norms)

        // Set triangle indices
        descriptor.primitives = .triangles(inds)

        return try MeshResource.generate(from: [descriptor])
    }

    /// Create a RealityKit ModelEntity from this mesh.
    ///
    /// Convenience method that creates both the MeshResource and ModelEntity.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shape = Shape.cylinder(radius: 5, height: 10)
    /// let mesh = shape.mesh(linearDeflection: 0.05)
    ///
    /// let entity = try mesh.realityKitModelEntity(
    ///     material: SimpleMaterial(color: .blue, isMetallic: true)
    /// )
    /// content.add(entity)
    /// ```
    ///
    /// - Parameter material: The material to apply to the entity
    /// - Returns: A `ModelEntity` ready to add to a RealityKit scene
    /// - Throws: An error if mesh generation fails
    @MainActor
    public func realityKitModelEntity(material: RealityKit.Material) throws -> ModelEntity {
        let meshResource = try realityKitMeshResource()
        return ModelEntity(mesh: meshResource, materials: [material])
    }

    /// Create a RealityKit ModelEntity with default gray metallic material.
    ///
    /// - Returns: A `ModelEntity` ready to add to a RealityKit scene
    /// - Throws: An error if mesh generation fails
    @MainActor
    public func realityKitModelEntity() throws -> ModelEntity {
        let material = SimpleMaterial(color: .gray, isMetallic: true)
        return try realityKitModelEntity(material: material)
    }
}

#endif

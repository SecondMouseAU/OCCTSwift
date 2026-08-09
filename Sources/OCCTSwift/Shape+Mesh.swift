import Foundation
import simd
import OCCTBridge

extension Shape {


    // MARK: - BRepMesh_Deflection (v0.61.0)

    /// Compute absolute deflection from relative deflection for meshing.
    ///
    /// - Parameters:
    ///   - relativeDeflection: Relative deflection value
    ///   - maxShapeSize: Maximum shape dimension
    /// - Returns: Absolute deflection value, or nil on failure
    public func computeAbsoluteDeflection(relativeDeflection: Double, maxShapeSize: Double) -> Double? {
        let result = OCCTComputeAbsoluteDeflection(handle, relativeDeflection, maxShapeSize)
        return result >= 0 ? result : nil
    }

    /// Check if a mesh deflection is consistent with requirements.
    ///
    /// - Parameters:
    ///   - current: Current deflection value
    ///   - required: Required deflection value
    ///   - allowDecrease: Whether to allow the mesh to be finer than required
    ///   - ratio: Comparison ratio (0 to 1, default 0.1)
    /// - Returns: true if the current deflection is acceptable
    public static func deflectionIsConsistent(current: Double, required: Double,
                                               allowDecrease: Bool = false,
                                               ratio: Double = 0.1) -> Bool {
        return OCCTDeflectionIsConsistent(current, required, allowDecrease, ratio)
    }

    // MARK: - BRepBuilderAPI_MakeShapeOnMesh (v0.61.0)

    /// Build a shape from a triangulated mesh.
    ///
    /// Creates a topological shape from point coordinates and triangle indices.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (vertices of the mesh)
    ///   - triangles: Array of triangle index triples (1-based indices into points array)
    /// - Returns: Shape built from the mesh, or nil on failure
    public static func fromMesh(points: [SIMD3<Double>], triangles: [(Int32, Int32, Int32)]) -> Shape? {
        var flatPoints = [Double]()
        flatPoints.reserveCapacity(points.count * 3)
        for pt in points {
            flatPoints.append(pt.x)
            flatPoints.append(pt.y)
            flatPoints.append(pt.z)
        }
        var flatTriangles = [Int32]()
        flatTriangles.reserveCapacity(triangles.count * 3)
        for tri in triangles {
            flatTriangles.append(tri.0)
            flatTriangles.append(tri.1)
            flatTriangles.append(tri.2)
        }
        guard let h = OCCTShapeFromMesh(flatPoints, Int32(points.count),
                                         flatTriangles, Int32(triangles.count)) else { return nil }
        return Shape(handle: h)
    }
    /// Maximum dimension of the shape's bounding box (for mesh sizing).
    public var meshMaxDimension: Double {
        OCCTMeshShapeToolBoxMaxDimension(handle)
    }

    // --- Triangulation queries ---

    /// Number of triangulation nodes on a face.
    public var triangulationNodeCount: Int32 {
        OCCTFaceTriangulationNodeCount(handle)
    }

    /// Number of triangles in the triangulation of a face.
    public var triangulationTriangleCount: Int32 {
        OCCTFaceTriangulationTriangleCount(handle)
    }

    /// Deflection of the face triangulation.
    public var triangulationDeflection: Double {
        OCCTFaceTriangulationDeflection(handle)
    }

    /// Get the 3D coordinates of a triangulation node (1-based index).
    public func triangulationNode(at index: Int32) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTFaceTriangulationNode(handle, index, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the node indices of a triangle (1-based index). Returns 1-based node indices.
    public func triangulationTriangle(at index: Int32) -> (Int32, Int32, Int32) {
        var n1: Int32 = 0, n2: Int32 = 0, n3: Int32 = 0
        OCCTFaceTriangulationTriangle(handle, index, &n1, &n2, &n3)
        return (n1, n2, n3)
    }

    /// Whether the face triangulation has normals.
    public var triangulationHasNormals: Bool {
        OCCTFaceTriangulationHasNormals(handle)
    }

    /// Get the normal at a triangulation node (1-based index).
    public func triangulationNormal(at index: Int32) -> SIMD3<Double> {
        var nx = 0.0, ny = 0.0, nz = 0.0
        OCCTFaceTriangulationNormal(handle, index, &nx, &ny, &nz)
        return SIMD3(nx, ny, nz)
    }

    /// Whether the face triangulation has UV nodes.
    public var triangulationHasUVNodes: Bool {
        OCCTFaceTriangulationHasUVNodes(handle)
    }

    /// Get the UV coordinates of a triangulation node (1-based index).
    public func triangulationUVNode(at index: Int32) -> SIMD2<Double> {
        var u = 0.0, v = 0.0
        OCCTFaceTriangulationUVNode(handle, index, &u, &v)
        return SIMD2(u, v)
    }
}

extension Shape {
    /// Write shape to VRML file.
    /// - Parameters:
    ///   - url: File URL to write to (.wrl extension)
    ///   - version: VRML version (1 or 2, default 2)
    ///   - deflection: Mesh deflection for triangulation (default 0.01)
    ///   - representation: Visual representation mode (default .shaded)
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL,
                          version: Int = 2,
                          deflection: Double = 0.01,
                          representation: VrmlRepresentation = .shaded) -> Bool {
        OCCTVrmlWriteShape(handle, url.path, Int32(version), deflection, representation.rawValue)
    }
}

extension Shape {

    /// Write this shape's triangulation to a binary STL file.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - filePath: Output file path.
    ///   - deflection: Linear mesh deflection (mm) for the auto-triangulation. Default `0.1`.
    /// - Returns: true on success.
    public func writeSTLBinary(to filePath: String, deflection: Double = 0.1) -> Bool {
        OCCTShapeWriteSTLBinary(handle, filePath, deflection)
    }

    /// Write this shape's triangulation to an ASCII STL file.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - filePath: Output file path.
    ///   - deflection: Linear mesh deflection (mm) for the auto-triangulation. Default `0.1`.
    /// - Returns: true on success.
    public func writeSTLAscii(to filePath: String, deflection: Double = 0.1) -> Bool {
        OCCTShapeWriteSTLAscii(handle, filePath, deflection)
    }

    /// Read an STL file and return as a triangulated shape.
    /// - Parameter filePath: Input STL file path.
    /// - Returns: Shape with triangulation, or nil on failure.
    public static func readSTL(from filePath: String) -> Shape? {
        guard let ref = OCCTShapeReadSTL(filePath) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Get adjacent triangles for a triangle in a meshed face.
    /// The three triangles adjacent to one triangle of a face's triangulation.
    ///
    /// `faceIndex` is 0-based, like ``Face/index`` and every other face index in this API (#541).
    /// `triangleIndex` and the returned neighbour indices are `Poly_Triangulation`'s own 1-based
    /// triangle numbers; 0 means no neighbour on that side.
    public func meshTriangleAdjacency(faceIndex: Int, triangleIndex: Int) -> (Int, Int, Int)? {
        var a1: Int32 = 0, a2: Int32 = 0, a3: Int32 = 0
        guard OCCTMeshTriangleAdjacency(handle, Int32(faceIndex), Int32(triangleIndex), &a1, &a2, &a3) else {
            return nil
        }
        return (Int(a1), Int(a2), Int(a3))
    }

    /// A triangle containing the given node of a face's triangulation.
    ///
    /// `faceIndex` is 0-based (#541); `nodeIndex` and the returned triangle index are
    /// `Poly_Triangulation`'s own 1-based numbers.
    public func meshNodeTriangle(faceIndex: Int, nodeIndex: Int) -> Int? {
        let idx = Int(OCCTMeshNodeTriangle(handle, Int32(faceIndex), Int32(nodeIndex)))
        return idx > 0 ? idx : nil
    }

    /// Count triangles sharing a node (triangle fan count).
    ///
    /// `faceIndex` is 0-based (#541); `nodeIndex` is `Poly_Triangulation`'s own 1-based number.
    public func meshNodeTriangleCount(faceIndex: Int, nodeIndex: Int) -> Int {
        Int(OCCTMeshNodeTriangleCount(handle, Int32(faceIndex), Int32(nodeIndex)))
    }
}

extension Shape {
    /// Load a shape from a GLTF or GLB file.
    public static func loadGLTF(fromPath path: String) -> Shape? {
        guard let ref = OCCTImportGLTF(path) else { return nil }
        return Shape(handle: ref)
    }

    /// Load a shape from a GLTF or GLB file URL.
    public static func loadGLTF(from url: URL) -> Shape? {
        loadGLTF(fromPath: url.path)
    }
}

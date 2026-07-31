import Foundation
import simd
import OCCTBridge

/// An edge from a 3D solid shape - represents a curve between vertices
public final class Edge: @unchecked Sendable {
    internal let handle: OCCTEdgeRef

    /// Index of this edge within the parent shape (-1 if standalone)
    public let index: Int

    internal init(handle: OCCTEdgeRef, index: Int = -1) {
        self.handle = handle
        self.index = index
    }

    /// Construct an Edge from a Shape that wraps a TopoDS_Edge. Returns nil
    /// if `shape` is null or wraps a non-edge topology type.
    public convenience init?(_ shape: Shape) {
        guard let h = OCCTEdgeFromShape(shape.handle) else { return nil }
        self.init(handle: h)
    }

    deinit {
        OCCTEdgeRelease(handle)
    }
    
    // MARK: - Properties
    
    /// Get the length of the edge
    public var length: Double {
        OCCTEdgeGetLength(handle)
    }
    
    /// Get the bounding box of the edge
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTEdgeGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }
    
    /// Check if the edge is a straight line
    public var isLine: Bool {
        OCCTEdgeIsLine(handle)
    }
    
    /// Check if the edge is a circular arc
    public var isCircle: Bool {
        OCCTEdgeIsCircle(handle)
    }
    
    /// Get the start and end points of the edge
    public var endpoints: (start: SIMD3<Double>, end: SIMD3<Double>) {
        var startX: Double = 0, startY: Double = 0, startZ: Double = 0
        var endX: Double = 0, endY: Double = 0, endZ: Double = 0
        OCCTEdgeGetEndpoints(handle, &startX, &startY, &startZ, &endX, &endY, &endZ)
        return (start: SIMD3(startX, startY, startZ), end: SIMD3(endX, endY, endZ))
    }
    
    // MARK: - Sampling
    
    // MARK: - 3D Curve Properties (v0.18.0)

    /// Curve type classification
    public enum CurveType: Int32, Sendable {
        case line = 0, circle = 1, ellipse = 2, hyperbola = 3, parabola = 4
        case bezierCurve = 5, bsplineCurve = 6, offsetCurve = 7, other = 8
    }

    /// Projection result for a point onto this edge's curve
    public struct CurveProjection: Sendable {
        public let point: SIMD3<Double>
        public let parameter: Double
        public let distance: Double
    }

    /// Get the parameter bounds of the edge's underlying curve
    public var parameterBounds: (first: Double, last: Double)? {
        var first: Double = 0, last: Double = 0
        guard OCCTEdgeGetParameterBounds(handle, &first, &last) else {
            return nil
        }
        return (first: first, last: last)
    }

    /// Get the curve type of this edge
    public var curveType: CurveType {
        CurveType(rawValue: OCCTEdgeGetCurveType(handle)) ?? .other
    }

    /// Get 3D point at a curve parameter
    public func point(at parameter: Double) -> SIMD3<Double>? {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        guard OCCTEdgeGetPointAtParam(handle, parameter, &px, &py, &pz) else {
            return nil
        }
        return SIMD3(px, py, pz)
    }

    /// Get curvature at a curve parameter
    public func curvature(at parameter: Double) -> Double? {
        var curvature: Double = 0
        guard OCCTEdgeGetCurvature3D(handle, parameter, &curvature) else {
            return nil
        }
        return curvature
    }

    /// Get tangent direction at a curve parameter
    public func tangent(at parameter: Double) -> SIMD3<Double>? {
        var tx: Double = 0, ty: Double = 0, tz: Double = 0
        guard OCCTEdgeGetTangent3D(handle, parameter, &tx, &ty, &tz) else {
            return nil
        }
        return SIMD3(tx, ty, tz)
    }

    /// Get principal normal direction at a curve parameter
    public func normal(at parameter: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTEdgeGetNormal3D(handle, parameter, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get center of curvature at a curve parameter
    public func centerOfCurvature(at parameter: Double) -> SIMD3<Double>? {
        var cx: Double = 0, cy: Double = 0, cz: Double = 0
        guard OCCTEdgeGetCenterOfCurvature3D(handle, parameter, &cx, &cy, &cz) else {
            return nil
        }
        return SIMD3(cx, cy, cz)
    }

    /// Get torsion at a curve parameter
    public func torsion(at parameter: Double) -> Double? {
        var torsion: Double = 0
        guard OCCTEdgeGetTorsion(handle, parameter, &torsion) else {
            return nil
        }
        return torsion
    }

    /// Project a 3D point onto this edge's curve, giving the closest point on the edge.
    ///
    /// The answer is always inside the edge's own parameter range (``parameterBounds``), and always
    /// the true nearest point: where the point has no perpendicular foot on the edge, the nearest
    /// point is one of its ends, and that is what comes back.
    ///
    /// ```swift
    /// let edge = Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0))!.edges()[0]
    ///
    /// let beyond = edge.project(point: SIMD3(100, 0, 0))!
    /// #expect(beyond.point == SIMD3(8, 0, 0))   // the end of the edge
    /// #expect(beyond.distance == 92)
    /// ```
    ///
    /// Before #539 this returned `nil` for that point, because the underlying extrema search finds
    /// no perpendicular foot there, and on an arc it could report the *far* side of the arc as the
    /// nearest point.
    ///
    /// - Returns: The closest point, or nil for an edge with no 3D curve to project onto.
    public func project(point: SIMD3<Double>) -> CurveProjection? {
        let result = OCCTEdgeProjectPoint(handle, point.x, point.y, point.z)
        guard result.isValid else { return nil }
        return CurveProjection(
            point: SIMD3(result.px, result.py, result.pz),
            parameter: result.parameter,
            distance: result.distance
        )
    }

    /// Shortest distance from a 3D point to this edge.
    ///
    /// A one-liner over ``project(point:)``, so it measures to the same nearest point: over the
    /// edge's own parameter range, ends included. Returns nil only for an edge with no 3D curve
    /// (typically a pcurve-only edge from a loft or sweep before `BuildCurves3d`).
    public func distance(to point: SIMD3<Double>) -> Double? {
        project(point: point)?.distance
    }

    /// The 3D curve underlying this edge as a standalone `Curve3D`.
    ///
    /// Returns nil for edges with no 3D curve representation (rare — typically
    /// pcurve-only edges from lofted / swept shapes before `BuildCurves3d`).
    /// Internally the returned curve is a `Geom_TrimmedCurve` over the edge's
    /// parameter range, so consumers get a finite handle even when the
    /// underlying geometry is an unbounded line or circle.
    ///
    /// Use cases:
    /// - Extract `CircleProperties` from a circular edge via `curve3D?.circleProperties`
    /// - Emit native DXF `CIRCLE` / `LINE` entities instead of tessellated polylines
    /// - Feed edge geometry into parametric sampling / analysis pipelines
    public var curve3D: Curve3D? {
        guard let ref = OCCTEdgeGetCurve3D(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    // MARK: - Sampling

    /// Get points along the edge curve
    /// - Parameter count: Number of points to generate (default: automatic based on length),
    ///   honoured within `2`...``Sampling/maximumSampleCount``; outside that range the result
    ///   is empty (#558). The automatic default is bounded too: a long enough edge implies more
    ///   points at 0.5mm spacing than the ceiling can serve.
    /// - Returns: Array of 3D points along the edge
    public func points(count: Int? = nil) -> [SIMD3<Double>] {
        let requested: Int
        if let count {
            requested = count
        } else {
            // ~0.5mm spacing default. Derive in Double: `Int(_:)` on a Double past Int.max is a
            // trap rather than an error, and `length` is geometry-supplied, so the implied count
            // is not bounded a priori (#558). A NaN length fails this guard too.
            let implied = (length / 0.5).rounded(.down) + 1
            guard implied <= Double(Sampling.maximumSampleCount) else { return [] }
            requested = max(2, Int(implied))
        }
        guard let pointCount = Sampling.requested(requested) else { return [] }

        var buffer = [Double](repeating: 0, count: pointCount * 3)
        let actualCount = OCCTEdgeGetPoints(handle, Int32(pointCount), &buffer)
        
        guard actualCount > 0 else { return [] }
        
        var result = [SIMD3<Double>]()
        result.reserveCapacity(Int(actualCount))
        
        for i in 0..<Int(actualCount) {
            let x = buffer[i * 3]
            let y = buffer[i * 3 + 1]
            let z = buffer[i * 3 + 2]
            result.append(SIMD3(x, y, z))
        }
        
        return result
    }
}

// MARK: - Shape Extension for Edge Access

extension Shape {
    /// Get total number of edges in the shape
    public var edgeCount: Int {
        Int(OCCTShapeGetTotalEdgeCount(handle))
    }
    
    /// Get edge by index (0-based)
    /// - Parameter index: The edge index
    /// - Returns: Edge at the given index, or nil if index is out of bounds
    public func edge(at index: Int) -> Edge? {
        guard let edgeHandle = OCCTShapeGetEdgeAtIndex(handle, Int32(index)) else {
            return nil
        }
        return Edge(handle: edgeHandle, index: index)
    }
    
    /// Get all edges from the shape
    public func edges() -> [Edge] {
        let count = edgeCount
        var edges = [Edge]()
        edges.reserveCapacity(count)
        
        for i in 0..<count {
            if let edge = edge(at: i) {
                edges.append(edge)
            }
        }
        
        return edges
    }
}

// MARK: - Edge Analysis (v0.30.0)

extension Edge {
    /// Whether this edge has an underlying 3D curve.
    public var hasCurve3D: Bool {
        OCCTEdgeHasCurve3D(handle)
    }

    /// Whether this edge is closed (start and end vertices coincide).
    public var isClosed3D: Bool {
        OCCTEdgeIsClosed3D(handle)
    }

    /// Whether this edge is a seam edge on the given face.
    ///
    /// A seam edge appears twice on a face with different orientations
    /// (e.g., the seam of a cylindrical face).
    ///
    /// - Parameter face: The face to check against
    /// - Returns: true if this edge is a seam on the face
    public func isSeam(on face: Face) -> Bool {
        OCCTEdgeIsSeam(handle, face.handle)
    }

    /// Get the faces adjacent to this edge within the given shape.
    ///
    /// Most interior edges have exactly 2 adjacent faces. Boundary edges have 1.
    ///
    /// - Parameter shape: The shape containing this edge
    /// - Returns: Tuple of (face1, face2) where face2 may be nil for boundary edges,
    ///   or nil if the edge has no adjacent faces
    public func adjacentFaces(in shape: Shape) -> (Face, Face?)? {
        var face1: OCCTFaceRef?
        var face2: OCCTFaceRef?
        let count = OCCTEdgeGetAdjacentFaces(shape.handle, handle, &face1, &face2)
        guard count >= 1, let f1 = face1 else { return nil }
        let firstFace = Face(handle: f1)
        let secondFace = face2.map { Face(handle: $0) }
        return (firstFace, secondFace)
    }

    /// Compute the dihedral angle between two faces at this edge.
    ///
    /// The dihedral angle is measured between the face normals at the specified
    /// parameter along the edge curve.
    ///
    /// - Parameters:
    ///   - face1: First adjacent face
    ///   - face2: Second adjacent face
    ///   - parameter: Parameter along edge (0.0 to 1.0) where to measure
    /// - Returns: Dihedral angle in radians (0 to 2*PI), or nil on error
    public func dihedralAngle(between face1: Face, and face2: Face, at parameter: Double = 0.5) -> Double? {
        let angle = OCCTEdgeGetDihedralAngle(handle, face1.handle, face2.handle, parameter)
        guard angle >= 0 else { return nil }
        return angle
    }
}

// MARK: - Curve Approximation (v0.46.0)

extension Edge {
    /// Result of curve approximation
    public struct CurveApproximation: Sendable {
        /// Maximum approximation error
        public let maxError: Double
        /// BSpline degree
        public let degree: Int
        /// Number of BSpline control points (poles)
        public let poleCount: Int
    }

    /// Approximate this edge's curve as a BSpline curve.
    ///
    /// Uses Approx_Curve3d to convert the edge's underlying curve (any type)
    /// into a BSpline representation with controlled tolerance and degree.
    ///
    /// - Parameters:
    ///   - tolerance: Maximum allowed approximation error (default 1e-3)
    ///   - maxSegments: Maximum number of BSpline segments (default 100)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    /// - Returns: Approximated BSpline as a Curve3D, or nil on failure
    public func approximatedCurve(tolerance: Double = 1e-3,
                                    maxSegments: Int = 100,
                                    maxDegree: Int = 8) -> Curve3D? {
        guard let ref = OCCTEdgeApproxCurve(handle, tolerance, Int32(maxSegments), Int32(maxDegree)) else {
            return nil
        }
        return Curve3D(handle: ref)
    }

    /// Get information about curve approximation without creating the curve.
    ///
    /// - Parameters:
    ///   - tolerance: Maximum allowed approximation error (default 1e-3)
    ///   - maxSegments: Maximum number of BSpline segments (default 100)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    /// - Returns: Approximation info (error, degree, pole count), or nil on failure
    public func curveApproximationInfo(tolerance: Double = 1e-3,
                                        maxSegments: Int = 100,
                                        maxDegree: Int = 8) -> CurveApproximation? {
        var maxError: Double = 0
        var degree: Int32 = 0
        var nbPoles: Int32 = 0
        guard OCCTEdgeApproxCurveInfo(handle, tolerance, Int32(maxSegments), Int32(maxDegree),
                                       &maxError, &degree, &nbPoles) else {
            return nil
        }
        return CurveApproximation(maxError: maxError, degree: Int(degree), poleCount: Int(nbPoles))
    }
}

// MARK: - Edge Splitting (v0.52.0)

extension Edge {
    /// Split this edge at a parameter value.
    ///
    /// Divides the edge into two new edges at the specified parameter.
    ///
    /// - Parameters:
    ///   - parameter: Parameter value at which to split
    ///   - vertex: 3D position for the split vertex
    /// - Returns: Tuple of (edge1, edge2) representing the two halves, or nil on failure
    public func split(at parameter: Double, vertex: SIMD3<Double>) -> (Edge, Edge)? {
        var e1: OCCTEdgeRef?
        var e2: OCCTEdgeRef?
        guard OCCTShapeFixSplitEdge(handle, parameter, vertex.x, vertex.y, vertex.z, &e1, &e2),
              let edge1 = e1, let edge2 = e2 else { return nil }
        return (Edge(handle: edge1), Edge(handle: edge2))
    }
}

// MARK: - PCurve / BRepAdaptor_Curve2d (v0.61.0)

extension Edge {
    /// Get the 2D parametric curve parameter range for this edge on a face.
    ///
    /// - Parameter face: The face on which the edge lies
    /// - Returns: Tuple of (first, last) parameters, or nil if no PCurve exists
    public func pcurveParams(on face: Face) -> (first: Double, last: Double)? {
        var first: Double = 0
        var last: Double = 0
        let shapeRef = OCCTShapeFromEdge(handle)
        defer { if let s = shapeRef { OCCTShapeRelease(s) } }
        let faceShapeRef = OCCTShapeFromFace(face.handle)
        defer { if let s = faceShapeRef { OCCTShapeRelease(s) } }
        guard let edgeShape = shapeRef, let faceShape = faceShapeRef,
              OCCTEdgePCurveParams(edgeShape, faceShape, &first, &last) else { return nil }
        return (first, last)
    }

    /// Evaluate the 2D parametric curve point for this edge on a face.
    ///
    /// - Parameters:
    ///   - parameter: Curve parameter
    ///   - face: The face on which the edge lies
    /// - Returns: UV point on the face surface, or nil on failure
    public func pcurveValue(at parameter: Double, on face: Face) -> SIMD2<Double>? {
        var u: Double = 0
        var v: Double = 0
        let shapeRef = OCCTShapeFromEdge(handle)
        defer { if let s = shapeRef { OCCTShapeRelease(s) } }
        let faceShapeRef = OCCTShapeFromFace(face.handle)
        defer { if let s = faceShapeRef { OCCTShapeRelease(s) } }
        guard let edgeShape = shapeRef, let faceShape = faceShapeRef,
              OCCTEdgePCurveValue(edgeShape, faceShape, parameter, &u, &v) else { return nil }
        return SIMD2(u, v)
    }

    /// Approximate the 3D curve of this edge on a face from its PCurve.
    ///
    /// Uses Approx_CurveOnSurface to compute a 3D BSpline from the 2D parametric curve.
    ///
    /// - Parameters:
    ///   - face: Face whose surface defines the mapping
    ///   - tolerance: Approximation tolerance (default 1e-4)
    ///   - maxSegments: Max BSpline segments (default 10)
    ///   - maxDegree: Max BSpline degree (default 8)
    /// - Returns: New edge with the approximated 3D curve, or nil on failure
    public func approxCurveOnSurface(face: Face, tolerance: Double = 1e-4,
                                      maxSegments: Int = 10, maxDegree: Int = 8) -> Shape? {
        let shapeRef = OCCTShapeFromEdge(handle)
        defer { if let s = shapeRef { OCCTShapeRelease(s) } }
        let faceShapeRef = OCCTShapeFromFace(face.handle)
        defer { if let s = faceShapeRef { OCCTShapeRelease(s) } }
        guard let edgeShape = shapeRef, let faceShape = faceShapeRef,
              let h = OCCTApproxCurveOnSurface(edgeShape, faceShape, tolerance,
                                                Int32(maxSegments), Int32(maxDegree)) else { return nil }
        return Shape(handle: h)
    }
}

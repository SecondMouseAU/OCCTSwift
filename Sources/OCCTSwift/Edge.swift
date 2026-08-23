import Foundation
import OCCTBridge
import simd

/// An edge from a 3D solid shape - represents a curve between vertices.
public final class Edge: @unchecked Sendable {
    internal let handle: OCCTEdgeRef

    /// Index of this edge within the parent shape (-1 if standalone).
    public let index: Int

    internal init(handle: OCCTEdgeRef, index: Int = -1) {
        self.handle = handle
        self.index = index
    }

    /// Construct an Edge from a Shape that wraps a TopoDS_Edge.
    ///
    /// Returns nil.
    /// if shape is null or wraps a non-edge topology type.
    public convenience init?(_ shape: Shape) {
        guard let h = OCCTEdgeFromShape(shape.handle) else { return nil }
        self.init(handle: h)
    }

    deinit {
        OCCTEdgeRelease(handle)
    }

    // MARK: - Properties

    /// Get the length of the edge.
    public var length: Double {
        OCCTEdgeGetLength(handle)
    }

    /// Get the bounding box of the edge.
    ///
    /// - Returns: The box as `(min, max)` corners, or nil when the edge contributes no geometry
    ///   to it (#943). A genuinely zero-length edge at the world origin returns a real all-zero.
    ///   box: the verdict comes from OCCT's own `Bnd_Box::IsVoid()`, not from the values.
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        unwrapAxisComponentsIfSuccessful { OCCTEdgeGetBounds(handle, $0, $1, $2, $3, $4, $5) }
    }

    /// Check if the edge is a straight line.
    public var isLine: Bool {
        OCCTEdgeIsLine(handle)
    }

    /// Check if the edge is a circular arc.
    public var isCircle: Bool {
        OCCTEdgeIsCircle(handle)
    }

    /// Get the start and end points of the edge.
    public var endpoints: (start: SIMD3<Double>, end: SIMD3<Double>) {
        var startX: Double = 0
        var startY: Double = 0
        var startZ: Double = 0
        var endX: Double = 0
        var endY: Double = 0
        var endZ: Double = 0
        OCCTEdgeGetEndpoints(handle, &startX, &startY, &startZ, &endX, &endY, &endZ)
        return (start: SIMD3(startX, startY, startZ), end: SIMD3(endX, endY, endZ))
    }

    // MARK: - Sampling

    // MARK: - 3D Curve Properties (v0.18.0)

    /// Curve type classification.
    public enum CurveType: Int32, Sendable {
        case line = 0
        case circle = 1
        case ellipse = 2
        case hyperbola = 3
        case parabola = 4
        case bezierCurve = 5
        case bsplineCurve = 6
        case offsetCurve = 7
        case other = 8
    }

    /// Projection result for a point onto this edge's curve.
    public struct CurveProjection: Sendable {
        public let point: SIMD3<Double>
        public let parameter: Double
        public let distance: Double
    }

    /// Get the parameter bounds of the edge's underlying curve.
    public var parameterBounds: (first: Double, last: Double)? {
        var first: Double = 0
        var last: Double = 0
        guard OCCTEdgeGetParameterBounds(handle, &first, &last) else {
            return nil
        }
        return (first: first, last: last)
    }

    /// Get the curve type of this edge.
    public var curveType: CurveType {
        CurveType(rawValue: OCCTEdgeGetCurveType(handle)) ?? .other
    }

    /// Get 3D point at a curve parameter.
    public func point(at parameter: Double) -> SIMD3<Double>? {
        var px: Double = 0
        var py: Double = 0
        var pz: Double = 0
        guard OCCTEdgeGetPointAtParam(handle, parameter, &px, &py, &pz) else {
            return nil
        }
        return SIMD3(px, py, pz)
    }

    /// Get curvature at a curve parameter.
    public func curvature(at parameter: Double) -> Double? {
        var curvature: Double = 0
        guard OCCTEdgeGetCurvature3D(handle, parameter, &curvature) else {
            return nil
        }
        return curvature
    }

    /// Get tangent direction at a curve parameter.
    public func tangent(at parameter: Double) -> SIMD3<Double>? {
        var tx: Double = 0
        var ty: Double = 0
        var tz: Double = 0
        guard OCCTEdgeGetTangent3D(handle, parameter, &tx, &ty, &tz) else {
            return nil
        }
        return SIMD3(tx, ty, tz)
    }

    /// Get principal normal direction at a curve parameter.
    public func normal(at parameter: Double) -> SIMD3<Double>? {
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        guard OCCTEdgeGetNormal3D(handle, parameter, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get center of curvature at a curve parameter.
    public func centerOfCurvature(at parameter: Double) -> SIMD3<Double>? {
        var cx: Double = 0
        var cy: Double = 0
        var cz: Double = 0
        guard OCCTEdgeGetCenterOfCurvature3D(handle, parameter, &cx, &cy, &cz) else {
            return nil
        }
        return SIMD3(cx, cy, cz)
    }

    /// Get torsion at a curve parameter.
    public func torsion(at parameter: Double) -> Double? {
        var torsion: Double = 0
        guard OCCTEdgeGetTorsion(handle, parameter, &torsion) else {
            return nil
        }
        return torsion
    }

    /// Project a 3D point onto this edge's curve, giving the closest point on the edge.
    ///
    /// The answer is always inside the edge's own parameter range (`parameterBounds`), and always.
    /// the true nearest point: where the point has no perpendicular foot on the edge, the nearest
    /// point is one of its ends, and that is what comes back.
    ///
    /// ```swift.
    /// let edge = Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0))!.edges()[0]
    ///
    /// let beyond = edge.project(point: SIMD3(100, 0, 0))!
    /// #expect(beyond.point == SIMD3(8, 0, 0))   // the end of the edge.
    /// #expect(beyond.distance == 92).
    /// ```.
    ///
    /// Before #539 this returned nil for that point, because the underlying extrema search finds.
    /// no perpendicular foot there, and on an arc it could report the *far* side of the arc as the.
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
    /// edge's own parameter range, ends included.
    ///
    /// Returns nil only for an edge with no 3D curve.
    /// (typically a pcurve-only edge from a loft or sweep before BuildCurves3d).
    public func distance(to point: SIMD3<Double>) -> Double? {
        project(point: point)?.distance
    }

    /// The 3D curve underlying this edge as a standalone Curve3D.
    ///
    /// Returns nil for edges with no 3D curve representation (rare, typically.
    /// pcurve-only edges from lofted / swept shapes before BuildCurves3d).
    ///
    /// Internally the returned curve is a Geom_TrimmedCurve over the edge's.
    /// parameter range, so consumers get a finite handle even when the.
    /// underlying geometry is an unbounded line or circle.
    ///
    /// Use cases:
    /// - Extract CircleProperties from a circular edge via `curve3D?.circleProperties`.
    /// - Emit native DXF CIRCLE / LINE entities instead of tessellated polylines.
    /// - Feed edge geometry into parametric sampling / analysis pipelines.
    public var curve3D: Curve3D? {
        guard let ref = OCCTEdgeGetCurve3D(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    // MARK: - Sampling

    /// Get points along the edge curve.
    /// - Parameter count: Number of points to generate (default: automatic based on length),
    ///   honoured within 2...``Sampling/maximumSampleCount``; outside that range the result.
    ///   is empty (#558).
    ///
    ///   The automatic default is bounded too: a long enough edge implies more
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
    /// The number of **distinct** edges in this shape, the same `TopExp::MapShapes` enumeration
    /// ``edges()``/``edge(at:)`` walk.
    ///
    /// An edge reachable from two adjacent faces is counted once here, not once per face: a plain
    /// box has 12 edges by this count even though every one of them borders two faces.
    ///
    /// See.
    /// ``edges()`` for the identity rule this follows and why it does not need an.
    /// orientation-preserving counterpart the way ``Shape/faces()`` does.
    ///
    /// `nbEdges` was a second spelling of this same question, backed by a bare.
    ///
    /// TopExp_Explorer occurrence walk instead of this deduplicated count, and is deprecated in.
    /// favour of this one (#651).
    public var edgeCount: Int {
        Int(OCCTShapeGetTotalEdgeCount(handle))
    }

    /// Get edge by index (0-based).
    /// - Parameter index: The edge index
    /// - Returns: Edge at the given index, or nil if index is out of bounds
    public func edge(at index: Int) -> Edge? {
        guard let edgeHandle = OCCTShapeGetEdgeAtIndex(handle, Int32(index)) else {
            return nil
        }
        return Edge(handle: edgeHandle, index: index)
    }

    /// Every **distinct** edge of this shape, in enumeration order: the same `TopExp::MapShapes`
    /// enumeration `edgeCount` counts.
    ///
    /// ## Identity, not orientation.
    ///
    /// Edges are distinguished the way OCCT distinguishes them for an index: by
    /// `TopoDS_Shape::IsSame`, which compares the underlying curve and placement and **ignores
    /// orientation**.
    ///
    /// An edge reachable from two owners, the ordinary case of any two adjacent.
    /// faces on one solid, collapses to a single entry here, carrying whichever orientation was.
    /// reached first.
    ///
    /// ```swift.
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.edges().count)    // 12: the distinct, addressable edges
    /// print(box.contents.edges)   // 24: one per (face, edge) visit, ShapeAnalysis_ShapeContents
    /// ```.
    ///
    /// Unlike ``Shape/faces()``, this collapse is **not** a defect (#638, following #614's own.
    /// method rather than assuming the analogy holds). #614 was a defect because.
    /// `Face.normal(atU:v:)` reverses on TopAbs_REVERSED, so a face's stored orientation changes
    /// the answer.
    ///
    /// Edge has no such consumer: it exposes no `.orientation` accessor at all, and
    /// every geometric query on it, ``Edge/tangent(at:)``, ``Edge/point(at:)``,
    /// ``Edge/parameterBounds``, ``Edge/curvature(at:)``, reads the edge's underlying Geom_Curve
    /// through `BRep_Tool::Curve`, which is defined independently of TopAbs_Orientation. A
    /// bridge-wide audit found no site that derives an orientation-dependent answer from an edge.
    /// obtained here; the one edge-orientation branch in the bridge.
    /// (occtSampleWirePoints) reads orientation fresh off a BRepTools_WireExplorer walk of the.
    /// wire it samples, not from an edge this method returns.
    ///
    /// If a future `Edge.orientation`.
    /// accessor or an orientation-sensitive consumer is added, re-run that audit before assuming.
    /// the collapse is still safe.
    ///
    /// See `Scripts/repro/cluster-a-subshape-enumeration/`.
    ///
    /// - Returns: Every distinct edge, so `edges()[k].index == k`, or an empty array if any edge
    ///   could not be built.
    ///
    ///   Never a short array, which would shift every later ordinal (#979).
    public func edges() -> [Edge] {
        // Each element is already an owning Edge, so discarding one releases its handle and the
        // enumeration helper has nothing of its own to release.
        wrapSubShapeEnumeration(
            (0..<edgeCount).map { edge(at: $0) },
            wrap: { element, _ in element },
            release: { _ in })
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
    /// A seam edge appears twice on a face with different orientations.
    /// (e.g., the seam of a cylindrical face).
    ///
    /// - Parameter face: The face to check against
    /// - Returns: true if this edge is a seam on the face
    public func isSeam(on face: Face) -> Bool {
        OCCTEdgeIsSeam(handle, face.handle)
    }

    /// Get the faces adjacent to this edge within the given shape.
    ///
    /// Most interior edges have exactly 2 adjacent faces.
    ///
    /// Boundary edges have 1.
    ///
    /// **Reports at most two, even where more bound the edge** (#777).
    ///
    /// An edge can bound three or.
    /// more faces in a compound whose solids share a face, and this returns whichever two the.
    /// underlying `TopExp::MapShapesAndAncestors` list holds first, with no signal that it
    /// truncated.
    ///
    /// Measured on two solids sharing one cut face: each of the four shared edges is
    /// bounded by four face occurrences, three distinct under IsSame, and this hands back two.
    ///
    /// Face values.
    ///
    /// ``Shape/adjacentFaces(forEdge:)`` sees more of them, and is not a complete answer either:
    /// it walks MapShapesAndUniqueAncestors through an IsSame-keyed map, so it reports the.
    /// three DISTINCT faces rather than the four occurrences, and it caps at 64 with no signal.
    /// when it truncates.
    ///
    /// Neither entry point can currently report an occurrence set.
    ///
    /// Tracked as.
    /// #1087.
    ///
    /// - Parameter shape: The shape containing this edge
    /// - Returns: Tuple of (face1, face2) where face2 may be nil for boundary edges,
    ///   or nil if the edge has no adjacent faces.
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
    /// The dihedral angle is measured between the face normals at the specified.
    /// parameter along the edge curve.
    ///
    /// - Parameters:
    ///   - face1: First adjacent face
    ///   - face2: Second adjacent face
    ///   - parameter: Parameter along edge (0.0 to 1.0) where to measure
    /// - Returns: Dihedral angle in radians (0 to 2*PI), or nil on error
    public func dihedralAngle(between face1: Face, and face2: Face, at parameter: Double = 0.5)
        -> Double?
    {
        let angle = OCCTEdgeGetDihedralAngle(handle, face1.handle, face2.handle, parameter)
        guard angle >= 0 else { return nil }
        return angle
    }
}

// MARK: - Curve Approximation (v0.46.0)

extension Edge {
    /// Result of curve approximation.
    public struct CurveApproximation: Sendable {
        /// Maximum approximation error.
        public let maxError: Double
        /// BSpline degree.
        public let degree: Int
        /// Number of BSpline control points (poles).
        public let poleCount: Int
    }

    /// Approximate this edge's curve as a BSpline curve.
    ///
    /// Uses Approx_Curve3d to convert the edge's underlying curve (any type).
    /// into a BSpline representation with controlled tolerance and degree.
    ///
    /// - Parameters:
    ///   - tolerance: Maximum allowed approximation error (default 1e-3)
    ///   - maxSegments: Maximum number of BSpline segments (default 100)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    /// - Returns: Approximated BSpline as a Curve3D, or nil on failure
    public func approximatedCurve(
        tolerance: Double = 1e-3,
        maxSegments: Int = 100,
        maxDegree: Int = 8
    ) -> Curve3D? {
        guard let ref = OCCTEdgeApproxCurve(handle, tolerance, Int32(maxSegments), Int32(maxDegree))
        else {
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
    public func curveApproximationInfo(
        tolerance: Double = 1e-3,
        maxSegments: Int = 100,
        maxDegree: Int = 8
    ) -> CurveApproximation? {
        var maxError: Double = 0
        var degree: Int32 = 0
        var nbPoles: Int32 = 0
        guard
            OCCTEdgeApproxCurveInfo(
                handle, tolerance, Int32(maxSegments), Int32(maxDegree),
                &maxError, &degree, &nbPoles)
        else {
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
            let edge1 = e1, let edge2 = e2
        else { return nil }
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
            OCCTEdgePCurveParams(edgeShape, faceShape, &first, &last)
        else { return nil }
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
            OCCTEdgePCurveValue(edgeShape, faceShape, parameter, &u, &v)
        else { return nil }
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
    public func approxCurveOnSurface(
        face: Face, tolerance: Double = 1e-4,
        maxSegments: Int = 10, maxDegree: Int = 8
    ) -> Shape? {
        let shapeRef = OCCTShapeFromEdge(handle)
        defer { if let s = shapeRef { OCCTShapeRelease(s) } }
        let faceShapeRef = OCCTShapeFromFace(face.handle)
        defer { if let s = faceShapeRef { OCCTShapeRelease(s) } }
        guard let edgeShape = shapeRef, let faceShape = faceShapeRef,
            let h = OCCTApproxCurveOnSurface(
                edgeShape, faceShape, tolerance,
                Int32(maxSegments), Int32(maxDegree))
        else { return nil }
        return Shape(handle: h)
    }
}

extension Edge {
    /// Prepare polygon points from a meshed edge.
    public func meshPolygonPoints() -> [(Double, Double, Double)] {
        var coords = [Double](repeating: 0, count: 3000)  // up to 1000 points
        let count = OCCTMeshCinertPreparePolygon(handle, &coords, 1000)
        var points: [(Double, Double, Double)] = []
        for i in 0..<Int(count) {
            points.append((coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]))
        }
        return points
    }
}

extension Edge {
    /// Validate edge geometry on a face (3D curve vs curve-on-surface consistency).
    public func validate(on face: Face, tolerance: Double = 1e-3) -> ValidateEdgeResult {
        let r = OCCTValidateEdge(handle, face.handle, tolerance)
        return ValidateEdgeResult(
            isDone: r.isDone, isWithinTolerance: r.isWithinTolerance,
            maxDistance: r.maxDistance, tolerance: r.tolerance)
    }
}

extension Edge {
    /// Compute quasi-uniform parameter distribution on this edge.
    ///
    /// The first parameter is always the start of the edge and the last is always its end.
    ///
    /// ```swift.
    /// if let edge = Shape.box(width: 10, height: 10, depth: 10)?.edges().first {
    ///     let params = edge.quasiUniformParameters(count: 10)
    ///     #expect(params.count == 10).
    /// }.
    /// ```.
    ///
    /// - Parameter count: Desired number of sample points, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    ///
    ///   Shares.
    ///   the contract of ``Curve3D/quasiUniformParameters(count:)``, which wraps the same
    ///   GCPnts_QuasiUniformAbscissa for the standalone-curve case.
    /// - Returns: Array of parameter values, never more than count of them, or empty on failure
    public func quasiUniformParameters(count: Int) -> [Double] {
        guard let count = Sampling.requested(count) else { return [] }
        var params = [Double](repeating: 0, count: count)
        let n = OCCTGCPntsQuasiUniform(handle, Int32(count), &params, Int32(count))
        return Array(params.prefix(Int(n)))
    }
}

extension Edge {
    /// Sample this edge using tangential deflection criteria.
    public func tangentialDeflectionPoints(
        angularDeflection: Double = 0.1,
        curvatureDeflection: Double = 0.1,
        minPoints: Int = 2
    ) -> [TangentialDeflectionPoint] {
        let maxPts: Int32 = 10000
        var params = [Double](repeating: 0, count: Int(maxPts))
        var coords = [Double](repeating: 0, count: Int(maxPts) * 3)
        let n = OCCTGCPntsTangentialDeflection(
            handle, angularDeflection, curvatureDeflection,
            Int32(minPoints), &params, &coords, maxPts)
        return (0..<Int(n)).map { i in
            TangentialDeflectionPoint(
                parameter: params[i], x: coords[i * 3], y: coords[i * 3 + 1], z: coords[i * 3 + 2])
        }
    }
}

extension Edge {
    /// Compute curve linear inertia (length and center of mass).
    ///
    /// ```swift.
    /// let e = Edge.line(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
    /// e.curveInertia.length          // 10.
    /// e.curveInertia.centerOfMass    // (5,0,0).
    /// ```.
    public var curveInertia: CurveInertia {
        let r = OCCTBRepGPropCinert(handle)
        return CurveInertia(
            length: r.mass,
            centerOfMass: massCentroid(mass: r.mass, x: r.centerX, y: r.centerY, z: r.centerZ))
    }
}

import Foundation
import OCCTBridge
import simd

extension Shape {

    /// Apply 2D fillets (rounded corners) to a planar face at specified vertices.
    ///
    /// Uses BRepFilletAPI_MakeFillet2d to round corners of a planar face.
    /// Vertex indices are 0-based and correspond to the topological vertex order.
    ///
    /// - Note: Only the **first** face of the receiver is filleted, and the result is that
    ///   face alone; the other faces of a multi-face shape are neither filleted nor carried
    ///   through. Vertex indices are numbered within that first face. Call this on one face
    ///   at a time.
    ///
    /// - Note: An index naming no vertex of that first face fails the whole call rather than being
    ///   skipped (#568). Previously it was dropped and the corners that did resolve were rounded,
    ///   reported as a complete result.
    ///
    /// - Parameters:
    ///   - vertexIndices: 0-based indices of vertices to fillet
    ///   - radii: Fillet radius for each vertex (must match vertexIndices count)
    /// - Returns: Modified shape with fillets, or nil on failure
    ///
    /// ```swift
    /// let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
    /// let rounded = face.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [2, 2, 2, 2])
    /// print(rounded?.edgeCount ?? 0)   // 8: four straights and four arcs
    /// ```
    public func fillet2D(vertexIndices: [Int], radii: [Double]) -> Shape? {
        guard !vertexIndices.isEmpty, vertexIndices.count == radii.count else { return nil }
        let indices = vertexIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { idxBuf in
            radii.withUnsafeBufferPointer { radBuf in
                OCCTFace2DFillet(
                    handle, idxBuf.baseAddress, radBuf.baseAddress, Int32(vertexIndices.count))
            }
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Apply 2D chamfers (angled cuts) to a planar face between adjacent edge pairs.
    ///
    /// Uses BRepFilletAPI_MakeFillet2d to add chamfers at the intersection of
    /// adjacent edges. Edge indices are 0-based and correspond to the topological edge order.
    ///
    /// - Note: Only the **first** face of the receiver is chamfered, and the result is that
    ///   face alone; the other faces of a multi-face shape are neither chamfered nor carried
    ///   through. Edge indices are numbered within that first face. Call this on one face at
    ///   a time.
    ///
    /// - Note: *Either* half of a pair naming no edge of that first face fails the whole call
    ///   rather than being skipped (#568). Previously the pair was dropped and the corners that
    ///   did resolve were cut, reported as a complete result.
    ///
    /// - Note: The same edge pair named twice fails the whole call rather than crashing (#705).
    ///   This is an upstream OCCT defect in `BRepFilletAPI_MakeFillet2d::AddChamfer`, not this
    ///   wrapper's own: the pair's second call finds its shared vertex already consumed by the
    ///   first chamfer, and the resulting failure returns two null edges that `AddChamfer`
    ///   dereferences without checking for first. The process SIGSEGV'd, uncatchably, before this
    ///   guard existed. The check is order independent: `(0, 1)` and `(1, 0)` name the same pair
    ///   and both are refused. Reusing one edge across two *different* pairs is unaffected and
    ///   still works, e.g. chamfering every corner of a rectangle with
    ///   `(0, 1), (1, 2), (2, 3), (3, 0)`.
    ///
    /// - Parameters:
    ///   - edgePairs: Array of (edge1Index, edge2Index) pairs identifying adjacent edges
    ///   - distances: Chamfer distance for each edge pair
    /// - Returns: Modified shape with chamfers, or nil on failure
    ///
    /// ```swift
    /// let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
    /// let cut = face.chamfer2D(edgePairs: [(0, 1), (2, 3)], distances: [2, 2])
    /// print(cut?.edgeCount ?? 0)   // 6: two corners replaced by chamfer edges
    ///
    /// // A repeated pair is refused, not crashed, and not silently collapsed to one chamfer.
    /// print(face.chamfer2D(edgePairs: [(0, 1), (0, 1)], distances: [1, 2]) == nil)   // true
    /// ```
    public func chamfer2D(edgePairs: [(Int, Int)], distances: [Double]) -> Shape? {
        guard !edgePairs.isEmpty, edgePairs.count == distances.count else { return nil }
        let edge1Indices = edgePairs.map { Int32($0.0) }
        let edge2Indices = edgePairs.map { Int32($0.1) }
        let result = edge1Indices.withUnsafeBufferPointer { e1Buf in
            edge2Indices.withUnsafeBufferPointer { e2Buf in
                distances.withUnsafeBufferPointer { distBuf in
                    OCCTFace2DChamfer(
                        handle, e1Buf.baseAddress, e2Buf.baseAddress,
                        distBuf.baseAddress, Int32(edgePairs.count))
                }
            }
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Result of a 2D analytical fillet operation.
    public struct AnaFilletResult {
        /// The fillet arc edge.
        public let fillet: Shape
        /// Trimmed first edge.
        public let edge1: Shape
        /// Trimmed second edge.
        public let edge2: Shape
    }

    /// Compute a 2D analytical fillet between two edges (segments or arcs of circle).
    ///
    /// Uses ChFi2d_AnaFilletAlgo for fast exact fillet computation in a plane.
    ///
    /// - Parameters:
    ///   - edge1: First edge shape
    ///   - edge2: Second edge shape
    ///   - planeOrigin: A point on the plane
    ///   - planeNormal: Normal direction of the plane
    ///   - radius: Fillet radius
    /// - Returns: Fillet result with arc and trimmed edges, or nil on failure
    public static func anaFillet(
        edge1: Shape,
        edge2: Shape,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> AnaFilletResult? {
        let r = OCCTChFi2dAnaFillet(
            edge1.handle, edge2.handle,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            radius)
        guard r.success,
            let fillet = r.fillet,
            let e1 = r.edge1,
            let e2 = r.edge2
        else { return nil }
        return AnaFilletResult(
            fillet: Shape(handle: fillet),
            edge1: Shape(handle: e1),
            edge2: Shape(handle: e2))
    }

    /// Compute a 2D analytical fillet between two edges.
    ///
    /// Convenience overload accepting `Edge` objects directly.
    public static func anaFillet(
        edge1: Edge, edge2: Edge,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> AnaFilletResult? {
        guard let s1 = Shape.fromEdge(edge1),
            let s2 = Shape.fromEdge(edge2)
        else { return nil }
        return anaFillet(
            edge1: s1, edge2: s2,
            planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }

    /// Compute a 2D analytical fillet between two edges of a wire.
    ///
    /// Extracts edges from the wire and fillets between adjacent pairs.
    /// Edge indices are 0-based; fillet is computed between edges at `index` and `index+1`.
    ///
    /// - Parameters:
    ///   - wire: Wire containing the edges
    ///   - edgeIndex: Index of first edge (second edge is edgeIndex+1)
    ///   - planeOrigin: A point on the plane
    ///   - planeNormal: Normal direction of the plane
    ///   - radius: Fillet radius
    /// - Returns: Fillet result, or nil on failure
    public static func anaFillet(
        wire: Wire, edgeIndex: Int = 0,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> AnaFilletResult? {
        let edges = wire.edges()
        guard edgeIndex >= 0, edgeIndex + 1 < edges.count else { return nil }
        return anaFillet(
            edge1: edges[edgeIndex], edge2: edges[edgeIndex + 1],
            planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }

    // MARK: - ChFi2d_FilletAlgo

    /// Result of a 2D iterative fillet operation.
    public struct FilletAlgoResult {
        /// The fillet arc edge.
        public let fillet: Shape
        /// Trimmed first edge.
        public let edge1: Shape
        /// Trimmed second edge.
        public let edge2: Shape
        /// Number of fillet solutions found.
        public let resultCount: Int
    }

    /// Compute a 2D iterative fillet between two edges in a plane.
    ///
    /// Uses ChFi2d_FilletAlgo for general 2D fillet computation. Supports
    /// any edge types (not just lines and arcs like `anaFillet`).
    ///
    /// - Parameters:
    ///   - edge1: First edge shape
    ///   - edge2: Second edge shape
    ///   - planeOrigin: A point on the working plane
    ///   - planeNormal: Normal direction of the plane
    ///   - radius: Fillet radius
    /// - Returns: Fillet result with arc and trimmed edges, or nil on failure
    public static func filletAlgo(
        edge1: Shape, edge2: Shape,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> FilletAlgoResult? {
        let r = OCCTChFi2dFilletAlgo(
            edge1.handle, edge2.handle,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            radius)
        guard r.success,
            let fillet = r.fillet,
            let e1 = r.edge1,
            let e2 = r.edge2
        else { return nil }
        return FilletAlgoResult(
            fillet: Shape(handle: fillet),
            edge1: Shape(handle: e1),
            edge2: Shape(handle: e2),
            resultCount: Int(r.resultCount))
    }

    /// Compute a 2D iterative fillet between two edges.
    ///
    /// Convenience overload accepting `Edge` objects directly.
    public static func filletAlgo(
        edge1: Edge, edge2: Edge,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> FilletAlgoResult? {
        guard let s1 = Shape.fromEdge(edge1),
            let s2 = Shape.fromEdge(edge2)
        else { return nil }
        return filletAlgo(
            edge1: s1, edge2: s2,
            planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }

    /// Compute a 2D iterative fillet between two edges of a wire.
    ///
    /// - Parameters:
    ///   - wire: Wire containing the edges
    ///   - edgeIndex: Index of first edge (second edge is edgeIndex+1)
    ///   - planeOrigin: A point on the working plane
    ///   - planeNormal: Normal direction of the plane
    ///   - radius: Fillet radius
    /// - Returns: Fillet result, or nil on failure
    public static func filletAlgo(
        wire: Wire, edgeIndex: Int = 0,
        planeOrigin: SIMD3<Double> = .zero,
        planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> FilletAlgoResult? {
        let edges = wire.edges()
        guard edgeIndex >= 0, edgeIndex + 1 < edges.count else { return nil }
        return filletAlgo(
            edge1: edges[edgeIndex], edge2: edges[edgeIndex + 1],
            planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }

    // MARK: BRepBuilderAPI_MakeEdge2d

    /// Create a 2D edge from two 2D points.
    public static func edge2d(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Shape? {
        guard let h = OCCTMakeEdge2dFromPoints(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a circle arc with parameter bounds.
    ///
    /// `radius` must be positive. `BRepBuilderAPI_MakeEdge2d` reports success for a zero radius
    /// and hands back a zero-length edge with both vertices at the centre (#553), so the radius is
    /// checked before OCCT sees it. A non-positive radius returns nil.
    ///
    /// ```swift
    /// let arc = Shape.edge2dFromCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0),
    ///                                  radius: 3, p1: 0, p2: .pi)
    /// ```
    public static func edge2dFromCircle(
        center: SIMD2<Double>,
        direction: SIMD2<Double>,
        radius: Double,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard
            let h = OCCTMakeEdge2dFromCircle(
                center.x, center.y, direction.x, direction.y,
                radius, p1, p2
            )
        else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a line with parameter bounds.
    public static func edge2dFromLine(
        origin: SIMD2<Double>,
        direction: SIMD2<Double>,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard
            let h = OCCTMakeEdge2dFromLine(
                origin.x, origin.y, direction.x, direction.y,
                p1, p2
            )
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - ProjLib_ComputeApprox

    /// Project this edge's 3D curve onto a face's surface → edge on surface.
    public func projectOntoSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTProjLibComputeApprox(handle, face.handle, tolerance) else { return nil }
        return Shape(handle: h)
    }

    /// Project this edge's 3D curve onto a polar surface (sphere, torus) → edge on surface.
    public func projectOntoPolarSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTProjLibComputeApproxOnPolarSurface(handle, face.handle, tolerance) else {
            return nil
        }
        return Shape(handle: h)
    }

    // MARK: - v0.66.0: 2D Vector/Direction Utilities & LProp

    /// Signed angle between two 2D vectors (radians, -π to π).
    public static func vector2DAngle(a: SIMD2<Double>, b: SIMD2<Double>) -> Double {
        OCCTVector2DAngle(a.x, a.y, b.x, b.y)
    }

    /// Cross product of two 2D vectors (scalar value).
    public static func vector2DCross(a: SIMD2<Double>, b: SIMD2<Double>) -> Double {
        OCCTVector2DCross(a.x, a.y, b.x, b.y)
    }

    /// Dot product of two 2D vectors.
    public static func vector2DDot(a: SIMD2<Double>, b: SIMD2<Double>) -> Double {
        OCCTVector2DDot(a.x, a.y, b.x, b.y)
    }

    /// Magnitude of a 2D vector.
    public static func vector2DMagnitude(_ v: SIMD2<Double>) -> Double {
        OCCTVector2DMagnitude(v.x, v.y)
    }

    /// Normalize a 2D vector.
    public static func vector2DNormalized(_ v: SIMD2<Double>) -> SIMD2<Double> {
        var x = v.x
        var y = v.y
        OCCTVector2DNormalize(&x, &y)
        return SIMD2(x, y)
    }

    /// Create a normalized 2D direction from components.
    public static func direction2DNormalized(_ v: SIMD2<Double>) -> SIMD2<Double> {
        var x = v.x
        var y = v.y
        OCCTDirection2DNormalize(&x, &y)
        return SIMD2(x, y)
    }

    /// Signed angle between two 2D directions (radians).
    public static func direction2DAngle(a: SIMD2<Double>, b: SIMD2<Double>) -> Double {
        OCCTDirection2DAngle(a.x, a.y, b.x, b.y)
    }

    /// Cross product of two 2D directions.
    public static func direction2DCross(a: SIMD2<Double>, b: SIMD2<Double>) -> Double {
        OCCTDirection2DCross(a.x, a.y, b.x, b.y)
    }

    // MARK: - GccAna_Circ2d3Tan (v0.68.0)

    /// Solution circle from GccAna solver.
    public struct Circle2DSolution: Sendable {
        public let centerX: Double
        public let centerY: Double
        public let radius: Double
    }

    /// Find circles through 3 points (circumscribed circle).
    public static func circleThrough3Points(
        p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanPoints(
            p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Find circles tangent to 3 lines.
    public static func circleTangent3Lines(
        l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
        l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
        l3Point: SIMD2<Double>, l3Dir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanLines(
            l1Point.x, l1Point.y, l1Dir.x, l1Dir.y,
            l2Point.x, l2Point.y, l2Dir.x, l2Dir.y,
            l3Point.x, l3Point.y, l3Dir.x, l3Dir.y,
            tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Find circles tangent to 3 circles.
    ///
    /// Every radius must be positive. A zero-radius argument is a point, and OCCT does not answer
    /// the point question when it is given one: measured (#553), it returns each solution twice,
    /// because tangency to a circle of radius zero satisfies both the enclosing and the outside
    /// case at once. Use ``circleTangent2CirclesPoint(c1Center:c1Radius:c2Center:c2Radius:point:tolerance:)``,
    /// ``circleTangentCircle2Points(circleCenter:circleRadius:p1:p2:tolerance:)`` or
    /// ``circleThrough3Points(p1:p2:p3:tolerance:)`` to name a point as a point. A non-positive
    /// radius returns an empty array.
    ///
    /// ```swift
    /// let circles = Shape.circleTangent3Circles(c1Center: SIMD2(0, 0), c1Radius: 2,
    ///                                           c2Center: SIMD2(10, 0), c2Radius: 2,
    ///                                           c3Center: SIMD2(5, 8), c3Radius: 2)
    /// print(circles.count)   // 8
    /// ```
    public static func circleTangent3Circles(
        c1Center: SIMD2<Double>, c1Radius: Double,
        c2Center: SIMD2<Double>, c2Radius: Double,
        c3Center: SIMD2<Double>, c3Radius: Double,
        tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanCircles(
            c1Center.x, c1Center.y, c1Radius,
            c2Center.x, c2Center.y, c2Radius,
            c3Center.x, c3Center.y, c3Radius,
            tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Find circles tangent to 2 circles through 1 point.
    ///
    /// Both radii must be positive. With a zero radius the solution set comes back padded with
    /// repeats (#553): measured, four solutions holding two distinct circles. A non-positive
    /// radius returns an empty array.
    ///
    /// ```swift
    /// let circles = Shape.circleTangent2CirclesPoint(c1Center: SIMD2(0, 0), c1Radius: 2,
    ///                                                c2Center: SIMD2(10, 0), c2Radius: 2,
    ///                                                point: SIMD2(5, 8))
    /// ```
    public static func circleTangent2CirclesPoint(
        c1Center: SIMD2<Double>, c1Radius: Double,
        c2Center: SIMD2<Double>, c2Radius: Double,
        point: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d2CirclesPoint(
            c1Center.x, c1Center.y, c1Radius,
            c2Center.x, c2Center.y, c2Radius,
            point.x, point.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Find circles tangent to 1 circle through 2 points.
    ///
    /// `circleRadius` must be positive. This is the case where reading a zero-radius circle as a
    /// point fails outright: measured (#553), the solver finds nothing at all, where
    /// ``circleThrough3Points(p1:p2:p3:tolerance:)`` on the same three positions finds the circle
    /// through them. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let circles = Shape.circleTangentCircle2Points(circleCenter: SIMD2(0, 0), circleRadius: 2,
    ///                                                p1: SIMD2(10, 0), p2: SIMD2(5, 8))
    /// ```
    public static func circleTangentCircle2Points(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        p1: SIMD2<Double>, p2: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2dCircle2Points(
            circleCenter.x, circleCenter.y, circleRadius,
            p1.x, p1.y, p2.x, p2.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Find circles tangent to 2 lines through 1 point.
    public static func circleTangent2LinesPoint(
        l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
        l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
        point: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](
            repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d2LinesPoint(
            l1Point.x, l1Point.y, l1Dir.x, l1Dir.y,
            l2Point.x, l2Point.y, l2Dir.x, l2Dir.y,
            point.x, point.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map {
            Circle2DSolution(
                centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius)
        }
    }

    /// Classify a 2D point relative to a face boundary in parameter space.
    ///
    /// Uses IntTools_FClass2d to determine if a point in the face's UV parameter
    /// space is inside, on, or outside the face boundary.
    ///
    /// Two other wrapped classifiers answer the identical "in/on/out of the face boundary"
    /// question for a UV point — `Face.classify(u:v:)` and `Shape.classifyPoint2D(faceIndex:
    /// u:v:)`, both backed by `BRepClass_FaceClassifier`/`BRepClass_FClassifier` — and both
    /// default to `1e-6`. This method used to default to `1e-7`, an order of magnitude tighter,
    /// so a point 5e-7 from the boundary classified `.onBoundary` through the other two but not
    /// through this one; aligned to `1e-6` to match (#840). `isHole(tolerance:)`, this method's
    /// own `IntTools_FClass2d` file-neighbor, keeps its `1e-7` default deliberately — it answers a
    /// different question (is this face a hole) than the three UV-boundary classifiers above.
    ///
    /// - Warning: This is a **silent runtime behavior change** for any caller relying on the
    ///   implicit default, not just an internal-consistency fix. A point ~5e-7 from a face
    ///   boundary that classified `.outside` under the old `1e-7` default now classifies
    ///   `.onBoundary` under the new `1e-6` default — a 10x loosening — with no compile-time
    ///   signal, and downstream accept/reject logic keyed on that classification can change
    ///   outcome purely from this upgrade for geometry near that boundary band. Pass `tolerance:`
    ///   explicitly to pin a specific value across the upgrade (PR #870 aggregate review).
    ///
    /// - Parameters:
    ///   - u: U parameter coordinate
    ///   - v: V parameter coordinate
    ///   - tolerance: Classification tolerance (default 1e-6)
    /// - Returns: Point classification
    public func classifyPoint2d(u: Double, v: Double, tolerance: Double = 1e-6)
        -> OCCTSwift.PointClassification
    {
        let result = OCCTIntToolsFClass2dPerform(handle, u, v, tolerance)
        // Bridge returns: 0=IN, 1=ON, 2=OUT, 3=UNKNOWN
        // PointClassification: inside=0, outside=1, onBoundary=2, unknown=3
        switch result {
        case 0: return .inside
        case 1: return .onBoundary
        case 2: return .outside
        default: return .unknown
        }
    }

    /// Check if a face represents a hole (inner wire orientation).
    ///
    /// Uses IntTools_FClass2d.
    ///
    /// - Parameter tolerance: Classification tolerance (default 1e-7)
    /// - Returns: true if the face is a hole
    public func isHole(tolerance: Double = 1e-7) -> Bool {
        OCCTIntToolsFClass2dIsHole(handle, tolerance)
    }

    // MARK: - ChFi2d_Builder (v0.72.0)

    /// Add a 2D fillet at a vertex on a planar face.
    ///
    /// This operation works exclusively on **planar faces**, not solids.
    /// To fillet a vertex on a solid, first extract the face:
    /// ```swift
    /// let face = solid.subShapes(ofType: .face)[faceIndex]
    /// let filleted = face.addFillet2d(vertexIndex: 0, radius: 1.0)
    /// ```
    /// - Parameters:
    ///   - vertexIndex: 0-based index of the vertex to fillet.
    ///   - radius: Fillet radius.
    /// - Returns: Result face with fillet, or nil if shape is not a planar face.
    public func addFillet2d(vertexIndex: Int, radius: Double) -> Shape? {
        guard let ref = OCCTChFi2dAddFillet(handle, Int32(vertexIndex), radius) else { return nil }
        return Shape(handle: ref)
    }

    /// Add a 2D chamfer between two edges on a planar face.
    ///
    /// This operation works exclusively on **planar faces**, not solids.
    /// To chamfer edges on a solid, first extract the face:
    /// ```swift
    /// let face = solid.subShapes(ofType: .face)[faceIndex]
    /// let chamfered = face.addChamfer2d(edge1Index: 0, edge2Index: 1, d1: 1.0, d2: 0.5)
    /// ```
    /// - Parameters:
    ///   - edge1Index: 0-based index of first edge.
    ///   - edge2Index: 0-based index of second edge.
    ///   - d1: Distance on first edge.
    ///   - d2: Distance on second edge.
    /// - Returns: Result face with chamfer, or nil if shape is not a planar face.
    public func addChamfer2d(edge1Index: Int, edge2Index: Int, d1: Double, d2: Double) -> Shape? {
        guard let ref = OCCTChFi2dAddChamfer(handle, Int32(edge1Index), Int32(edge2Index), d1, d2)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Add a 2D chamfer at a vertex on a planar face (distance + angle).
    ///
    /// Uses ChFi2d_Builder with distance and angle.
    /// - Parameters:
    ///   - edgeIndex: 0-based index of the reference edge.
    ///   - vertexIndex: 0-based index of the vertex.
    ///   - distance: Distance on edge.
    ///   - angle: Chamfer angle in radians.
    /// - Returns: Result face with chamfer, or nil on failure.
    public func addChamfer2dAngle(edgeIndex: Int, vertexIndex: Int, distance: Double, angle: Double)
        -> Shape?
    {
        guard
            let ref = OCCTChFi2dAddChamferAngle(
                handle, Int32(edgeIndex), Int32(vertexIndex), distance, angle)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Modify a fillet radius on a face that already has a fillet.
    ///
    /// Uses ChFi2d_Builder::Init(original, modified) + ModifyFillet.
    /// - Parameters:
    ///   - originalFace: The face before any fillet was added.
    ///   - filletEdgeIndex: 0-based index of the fillet edge in this face.
    ///   - newRadius: New fillet radius.
    /// - Returns: Result face with modified fillet, or nil on failure.
    public func modifyFillet2d(originalFace: Shape, filletEdgeIndex: Int, newRadius: Double)
        -> Shape?
    {
        guard
            let ref = OCCTChFi2dModifyFillet(
                originalFace.handle, handle, Int32(filletEdgeIndex), newRadius)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Remove a fillet from a face.
    ///
    /// Uses ChFi2d_Builder::Init(original, modified) + RemoveFillet.
    /// - Parameters:
    ///   - originalFace: The face before the fillet was added.
    ///   - filletEdgeIndex: 0-based index of the fillet edge in this face.
    /// - Returns: Result face with fillet removed, or nil on failure.
    public func removeFillet2d(originalFace: Shape, filletEdgeIndex: Int) -> Shape? {
        guard let ref = OCCTChFi2dRemoveFillet(originalFace.handle, handle, Int32(filletEdgeIndex))
        else { return nil }
        return Shape(handle: ref)
    }

    /// Remove a chamfer from a face.
    ///
    /// Uses ChFi2d_Builder::Init(original, modified) + RemoveChamfer.
    /// - Parameters:
    ///   - originalFace: The face before the chamfer was added.
    ///   - chamferEdgeIndex: 0-based index of the chamfer edge in this face.
    /// - Returns: Result face with chamfer removed, or nil on failure.
    public func removeChamfer2d(originalFace: Shape, chamferEdgeIndex: Int) -> Shape? {
        guard
            let ref = OCCTChFi2dRemoveChamfer(originalFace.handle, handle, Int32(chamferEdgeIndex))
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ChFi2d_ChamferAPI (v0.72.0)

    /// Result of a 2D chamfer between two edges.
    public struct Chamfer2DEdgeResult: Sendable {
        /// The chamfer edge.
        public let chamferEdge: Shape
        /// Modified first edge.
        public let modifiedEdge1: Shape
        /// Modified second edge.
        public let modifiedEdge2: Shape
    }

    /// Create a chamfer between two linear edges using ChFi2d_ChamferAPI.
    ///
    /// - Parameters:
    ///   - edge1: First edge.
    ///   - edge2: Second edge.
    ///   - d1: Distance on first edge.
    ///   - d2: Distance on second edge.
    /// - Returns: Chamfer result with edges, or nil on failure.
    public static func chamfer2dEdges(edge1: Shape, edge2: Shape, d1: Double, d2: Double)
        -> Chamfer2DEdgeResult?
    {
        let result = OCCTChFi2dChamferEdges(edge1.handle, edge2.handle, d1, d2)
        guard let ce = result.chamferEdge, let me1 = result.modifiedEdge1,
            let me2 = result.modifiedEdge2
        else { return nil }
        return Chamfer2DEdgeResult(
            chamferEdge: Shape(handle: ce), modifiedEdge1: Shape(handle: me1),
            modifiedEdge2: Shape(handle: me2))
    }

    // MARK: - ChFi2d_FilletAPI (v0.72.0)

    /// Result of a 2D fillet between two edges.
    public struct Fillet2DEdgeResult: Sendable {
        /// The fillet edge.
        public let filletEdge: Shape
        /// Modified first edge.
        public let modifiedEdge1: Shape
        /// Modified second edge.
        public let modifiedEdge2: Shape
        /// Number of possible solutions.
        public let solutionCount: Int
    }

    /// Create a fillet between two edges in a plane using ChFi2d_FilletAPI.
    ///
    /// Automatically selects analytical or iterative algorithm.
    /// - Parameters:
    ///   - edge1: First edge.
    ///   - edge2: Second edge.
    ///   - planeNormal: Normal direction of the plane containing the edges.
    ///   - radius: Fillet radius.
    ///   - nearPoint: Point near desired fillet location (for choosing among solutions).
    /// - Returns: Fillet result with edges and solution count, or nil on failure.
    public static func fillet2dEdges(
        edge1: Shape, edge2: Shape,
        planeNormal: SIMD3<Double>,
        radius: Double,
        nearPoint: SIMD3<Double>
    ) -> Fillet2DEdgeResult? {
        let result = OCCTChFi2dFilletEdges(
            edge1.handle, edge2.handle,
            planeNormal.x, planeNormal.y, planeNormal.z,
            radius, nearPoint.x, nearPoint.y, nearPoint.z)
        guard let fe = result.filletEdge, let me1 = result.modifiedEdge1,
            let me2 = result.modifiedEdge2
        else { return nil }
        return Fillet2DEdgeResult(
            filletEdge: Shape(handle: fe), modifiedEdge1: Shape(handle: me1),
            modifiedEdge2: Shape(handle: me2), solutionCount: Int(result.solutionCount))
    }
}

extension Shape {
    /// Create a 2D edge from a full circle.
    ///
    /// - Parameters:
    ///   - center: Center of the circle.
    ///   - direction: Direction of the X axis of the local 2D frame.
    ///   - radius: Circle radius. Must be greater than zero.
    /// - Returns: The edge, or `nil` if the circle is degenerate.
    ///
    /// ```swift
    /// if let e = Shape.edge2dFullCircle(center: .zero, direction: SIMD2(1, 0), radius: 5) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dFullCircle(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        radius: Double
    ) -> Shape? {
        guard
            let h = OCCTMakeEdge2dFullCircle(
                center.x, center.y,
                direction.x, direction.y,
                radius)
        else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse.
    ///
    /// - Parameters:
    ///   - center: Center of the ellipse.
    ///   - direction: Direction of the X axis of the local 2D frame.
    ///   - majorRadius: Semi-major axis. Must be greater than zero.
    ///   - minorRadius: Semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    /// - Returns: The edge, or `nil` if the ellipse is degenerate. OCCT builds a zero-length edge
    ///   from a zero-radius ellipse, and a doubled-back segment from a zero minor radius.
    ///
    /// ```swift
    /// if let e = Shape.edge2dEllipse(center: .zero, direction: SIMD2(1, 0),
    ///                                majorRadius: 5, minorRadius: 3) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dEllipse(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Shape? {
        guard
            let h = OCCTMakeEdge2dEllipse(
                center.x, center.y,
                direction.x, direction.y,
                majorRadius, minorRadius)
        else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse arc.
    ///
    /// - Parameters:
    ///   - center: Center of the ellipse.
    ///   - direction: Direction of the X axis of the local 2D frame.
    ///   - majorRadius: Semi-major axis. Must be greater than zero.
    ///   - minorRadius: Semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    ///   - u1: Start parameter in radians.
    ///   - u2: End parameter in radians.
    /// - Returns: The edge, or `nil` if the ellipse is degenerate.
    ///
    /// ```swift
    /// if let e = Shape.edge2dEllipseArc(center: .zero, direction: SIMD2(1, 0),
    ///                                   majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dEllipseArc(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double,
        u1: Double, u2: Double
    ) -> Shape? {
        guard
            let h = OCCTMakeEdge2dEllipseArc(
                center.x, center.y,
                direction.x, direction.y,
                majorRadius, minorRadius,
                u1, u2)
        else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D.
    public static func edge2dFromCurve(_ curve: Curve2D) -> Shape? {
        guard let h = OCCTMakeEdge2dCurve(curve.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D with parameter range.
    public static func edge2dFromCurve(_ curve: Curve2D, u1: Double, u2: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dCurveRange(curve.handle, u1, u2) else { return nil }
        return Shape(handle: h)
    }
}

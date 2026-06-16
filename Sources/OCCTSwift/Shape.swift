import Foundation
import simd
import OCCTBridge

/// A 3D solid shape backed by OpenCASCADE B-Rep geometry
public final class Shape: @unchecked Sendable {
    internal let handle: OCCTShapeRef

    internal init(handle: OCCTShapeRef) {
        self.handle = handle
    }

    deinit {
        OCCTShapeRelease(handle)
    }

    // MARK: - Primitive Creation

    /// Create a box centered at origin
    public static func box(width: Double, height: Double, depth: Double) -> Shape? {
        guard let handle = OCCTShapeCreateBox(width, height, depth) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a box at a specific position
    public static func box(
        origin: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateBoxAt(
            origin.x, origin.y, origin.z,
            width, height, depth
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a box at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Corner point of the box.
    ///   - direction: Axis direction for the box height (will be normalized).
    ///   - width: Box width (X extent in local frame).
    ///   - height: Box height (Y extent in local frame).
    ///   - depth: Box depth (Z extent along direction).
    public static func box(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateBoxOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            width, height, depth
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder along Z axis
    public static func cylinder(radius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCylinder(radius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder at a specific XY position with bottom at specified Z
    public static func cylinder(
        at position: SIMD2<Double>,
        bottomZ: Double,
        radius: Double,
        height: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderAt(position.x, position.y, bottomZ, radius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height along the direction.
    public static func cylinder(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        height: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius, height
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cylinder (angular segment) along Z axis.
    ///
    /// - Parameters:
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func cylinder(radius: Double, height: Double, angle: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderPartial(radius, height, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cylinder (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - radius: Cylinder radius.
    ///   - height: Cylinder height along the direction.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func cylinder(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        height: Double,
        angle: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderOrientedPartial(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius, height, angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a tool sweep solid - the volume swept by a cylindrical tool moving between two points
    /// Used for CAM simulation to calculate material removal
    public static func toolSweep(
        radius: Double,
        height: Double,
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> Shape? {
        guard let handle = OCCTShapeCreateToolSweep(
            radius, height,
            start.x, start.y, start.z,
            end.x, end.y, end.z
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere centered at origin
    public static func sphere(radius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSphere(radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere at a specific center point.
    ///
    /// - Parameters:
    ///   - center: Center of the sphere.
    ///   - radius: Sphere radius.
    public static func sphere(center: SIMD3<Double>, radius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSphereAtCenter(
            center.x, center.y, center.z, radius
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create an oriented sphere at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateSphereOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial sphere (angular segment).
    ///
    /// - Parameters:
    ///   - radius: Sphere radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func sphere(radius: Double, angle: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSpherePartial(radius, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial sphere (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        angle: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateSphereOrientedPartial(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius, angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere latitude segment at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the sphere.
    ///   - direction: Axis direction (affects parameterization).
    ///   - radius: Sphere radius.
    ///   - angle1: Lower latitude bound in radians (-pi/2 to pi/2).
    ///   - angle2: Upper latitude bound in radians (-pi/2 to pi/2).
    public static func sphere(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        radius: Double,
        angle1: Double,
        angle2: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateSphereOrientedSegment(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius, angle1, angle2
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cone along Z axis
    public static func cone(bottomRadius: Double, topRadius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCone(bottomRadius, topRadius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cone at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - bottomRadius: Radius at the base.
    ///   - topRadius: Radius at the top.
    ///   - height: Cone height along the direction.
    public static func cone(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        bottomRadius: Double,
        topRadius: Double,
        height: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateConeOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            bottomRadius, topRadius, height
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial cone (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the base circle.
    ///   - direction: Axis direction (will be normalized).
    ///   - bottomRadius: Radius at the base.
    ///   - topRadius: Radius at the top.
    ///   - height: Cone height along the direction.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func cone(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        bottomRadius: Double,
        topRadius: Double,
        height: Double,
        angle: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateConeOrientedPartial(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            bottomRadius, topRadius, height, angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus in XY plane
    public static func torus(majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateTorus(majorRadius, minorRadius) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateTorusOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            majorRadius, minorRadius
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a partial torus (angular segment) at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    ///   - angle: Angular extent in radians (0 < angle <= 2*pi).
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double,
        angle: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateTorusOrientedPartial(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            majorRadius, minorRadius, angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus tube segment at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Center of the torus.
    ///   - direction: Axis direction (normal to the torus plane).
    ///   - majorRadius: Distance from center to tube center.
    ///   - minorRadius: Tube radius.
    ///   - angle1: Start angle of the tube section in radians.
    ///   - angle2: End angle of the tube section in radians.
    public static func torus(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        majorRadius: Double,
        minorRadius: Double,
        angle1: Double,
        angle2: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateTorusOrientedSegment(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            majorRadius, minorRadius, angle1, angle2
        ) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Sweep Operations

    /// Sweep a 2D profile along a path to create a solid.
    ///
    /// The resulting solid is orientation-normalised so its faces point outward
    /// (positive volume) regardless of the profile wire's sense relative to the
    /// path tangent. `BRepOffsetAPI_MakePipe` itself yields an inward-oriented
    /// (negative-volume) solid whenever the section's normal runs against the path
    /// tangent — a latent hazard for downstream booleans and `volume > 0` checks —
    /// so callers no longer need the "point the section normal against the tangent"
    /// incantation. See ``orientedForward()`` for the same fix applied explicitly.
    public static func sweep(profile: Wire, along path: Wire) -> Shape? {
        guard let handle = OCCTShapeCreatePipeSweep(profile.handle, path.handle) else { return nil }
        let swept = Shape(handle: handle)
        return swept.orientedForward()
    }

    /// Extrude a 2D profile in a direction
    public static func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape? {
        guard let handle = OCCTShapeCreateExtrusion(
            profile.handle,
            direction.x, direction.y, direction.z,
            length
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Revolve a 2D profile around an axis
    public static func revolve(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double = .pi * 2
    ) -> Shape? {
        guard let handle = OCCTShapeCreateRevolution(
            profile.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Extrude any shape along a vector.
    public func extruded(by vector: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateExtrusionShape(handle, vector.x, vector.y, vector.z) else { return nil }
        return Shape(handle: h)
    }

    /// Extrude any shape to infinity (or semi-infinity) along a direction.
    public func extrudedInfinite(direction: SIMD3<Double>, infinite: Bool = true) -> Shape? {
        guard let h = OCCTShapeCreateExtrusionInfinite(handle, direction.x, direction.y, direction.z, infinite) else { return nil }
        return Shape(handle: h)
    }

    /// Revolve any shape around an axis (full 360 degrees).
    public func revolved(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>
    ) -> Shape? {
        guard let h = OCCTShapeCreateRevolutionFull(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z) else { return nil }
        return Shape(handle: h)
    }

    /// Revolve any shape around an axis by a partial angle.
    public func revolved(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double
    ) -> Shape? {
        guard let h = OCCTShapeCreateRevolutionPartial(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle) else { return nil }
        return Shape(handle: h)
    }

    /// Loft through multiple profile wires
    public static func loft(profiles: [Wire], solid: Bool = true) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateLoft(buffer.baseAddress, Int32(profiles.count), solid)
        }) else { return nil }
        return Shape(handle: handle)
    }

    /// Loft through profile wires with advanced options.
    ///
    /// - Parameters:
    ///   - profiles: Wire profiles to loft through
    ///   - solid: Whether to create a solid (true) or shell (false)
    ///   - ruled: Whether to use ruled surfaces (true) or smooth B-spline (false)
    ///   - firstVertex: Optional starting vertex (for cone/taper tips)
    ///   - lastVertex: Optional ending vertex (for cone/taper tips)
    /// - Returns: Lofted shape, or nil on failure
    public static func loft(profiles: [Wire], solid: Bool = true, ruled: Bool,
                            firstVertex: SIMD3<Double>? = nil,
                            lastVertex: SIMD3<Double>? = nil) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        let fv = firstVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        let lv = lastVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateLoftAdvanced(buffer.baseAddress, Int32(profiles.count),
                                        solid, ruled,
                                        fv.x, fv.y, fv.z,
                                        lv.x, lv.y, lv.z)
        }) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Boolean Operations

    /// Glue mode for boolean operations (`BOPAlgo_GlueEnum`).
    ///
    /// Gluing speeds up and hardens booleans when the arguments share **coincident
    /// faces**, by telling the algorithm those faces touch instead of intersecting them.
    /// Only use it when the touching faces really are coincident — gluing two solids that
    /// genuinely interpenetrate produces a wrong result.
    public enum BooleanGlue: Int32, Sendable {
        /// No gluing (OCCT default — full intersection).
        case off = 0
        /// `BOPAlgo_GlueShift` — arguments may share coincident faces but are otherwise disjoint.
        case shift = 1
        /// `BOPAlgo_GlueFull` — all arguments are known to share coincident faces (fastest, strictest).
        case full = 2
    }

    /// Default wall-clock bound (seconds) for the boolean ops. A self-intersecting /
    /// inside-out operand (e.g. from `loft(ruled: false)`) can make `BRepAlgoAPI_Cut`
    /// spin indefinitely; the boolean ops abort and return `nil` once this elapses rather
    /// than hanging a pipeline. Override per call; pass `0` (or negative) to disable. (#206)
    public static let defaultBooleanTimeout: Double = 120

    /// Union (add) two shapes together.
    ///
    /// - Parameters:
    ///   - other: The shape to fuse with `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance; a small positive value (e.g. `1e-4`) helps near-tangent / nearly
    ///     coincident faces fuse cleanly. Negative values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    public func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                      timeout: Double = Shape.defaultBooleanTimeout) -> Shape? {
        guard let handle = OCCTShapeUnionEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout) else { return nil }
        return Shape(handle: handle)
    }

    @available(*, deprecated, renamed: "union(_:)",
               message: "Use union(_:) to match subtracting(_:) and Set.union(_:)")
    public func union(with other: Shape) -> Shape? { union(other) }

    /// Subtract another shape from this one.
    ///
    /// - Parameters:
    ///   - other: The tool shape to remove from `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance; raise it slightly when a thin-wall cut under-subtracts. Negative
    ///     values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    public func subtracting(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                            timeout: Double = Shape.defaultBooleanTimeout) -> Shape? {
        guard let handle = OCCTShapeSubtractEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout) else { return nil }
        return Shape(handle: handle)
    }

    /// Intersection of two shapes.
    ///
    /// - Parameters:
    ///   - other: The shape to intersect with `self`.
    ///   - fuzzyValue: Tolerance-based fuzzy value (`SetFuzzyValue`). `0` (default) keeps OCCT's
    ///     default tolerance. Negative values are ignored.
    ///   - glue: Glue mode for coincident-face arguments (default `.off`). See ``BooleanGlue``.
    ///   - timeout: Wall-clock bound in seconds (default ``defaultBooleanTimeout``, 120s). Returns
    ///     `nil` if the operation doesn't finish in time instead of hanging. `0`/negative = unbounded.
    public func intersection(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                             timeout: Double = Shape.defaultBooleanTimeout) -> Shape? {
        guard let handle = OCCTShapeIntersectEx(self.handle, other.handle, fuzzyValue, glue.rawValue, timeout) else { return nil }
        return Shape(handle: handle)
    }

    @available(*, deprecated, renamed: "intersection(_:)",
               message: "Use intersection(_:) to match subtracting(_:) and Set.intersection(_:)")
    public func intersection(with other: Shape) -> Shape? { intersection(other) }

    // MARK: - Modifications

    /// Fillet (round) all edges with given radius
    public func filleted(radius: Double) -> Shape? {
        guard let handle = OCCTShapeFillet(self.handle, radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Chamfer all edges with given distance
    public func chamfered(distance: Double) -> Shape? {
        guard let handle = OCCTShapeChamfer(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    /// Chamfer specific edges with two different distances (asymmetric).
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// and two distances. `dist1` is measured on the reference face side,
    /// `dist2` on the opposite side.
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, dist1, dist2) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedTwoDistances(_ edges: [(edgeIndex: Int, faceIndex: Int, dist1: Double, dist2: Double)]) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d1 = edges.map { $0.dist1 }
        let d2 = edges.map { $0.dist2 }
        guard let h = OCCTShapeChamferTwoDistances(handle, ei, fi, d1, d2, Int32(edges.count)) else { return nil }
        return Shape(handle: h)
    }

    /// Chamfer specific edges with distance + angle.
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// a distance measured on the reference face, and a chamfer angle in degrees
    /// (must be between 0 and 90, exclusive).
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, distance, angleDegrees) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedDistAngle(_ edges: [(edgeIndex: Int, faceIndex: Int, distance: Double, angleDegrees: Double)]) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d = edges.map { $0.distance }
        let a = edges.map { $0.angleDegrees }
        guard let h = OCCTShapeChamferDistAngle(handle, ei, fi, d, a, Int32(edges.count)) else { return nil }
        return Shape(handle: h)
    }

    /// Create a hollow shell by removing material from inside
    public func shelled(thickness: Double) -> Shape? {
        guard let handle = OCCTShapeShell(self.handle, thickness) else { return nil }
        return Shape(handle: handle)
    }

    /// Offset all faces by a distance (positive = outward)
    public func offset(by distance: Double) -> Shape? {
        guard let handle = OCCTShapeOffset(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    /// Offset all faces using the proper join algorithm.
    ///
    /// This uses `PerformByJoin` which is more robust than the simple offset.
    /// It handles gap filling between parallel faces using the specified join type.
    ///
    /// - Parameters:
    ///   - distance: Offset distance (positive = outward, negative = inward)
    ///   - tolerance: Coincidence tolerance (default: 1e-7)
    ///   - joinType: How to fill gaps between offset faces
    ///   - removeInternalEdges: Whether to clean up internal edges
    /// - Returns: Offset shape, or nil on failure
    public func offset(by distance: Double, tolerance: Double = 1e-7,
                       joinType: OffsetJoinType = .arc,
                       removeInternalEdges: Bool = false) -> Shape? {
        guard let h = OCCTShapeOffsetByJoin(handle, distance, tolerance,
                                             joinType.rawValue, removeInternalEdges) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Transformations

    /// Translate the shape
    public func translated(by offset: SIMD3<Double>) -> Shape? {
        guard let handle = OCCTShapeTranslate(self.handle, offset.x, offset.y, offset.z) else { return nil }
        return Shape(handle: handle)
    }

    /// Rotate around an axis through origin
    public func rotated(axis: SIMD3<Double>, angle: Double) -> Shape? {
        guard let handle = OCCTShapeRotate(self.handle, axis.x, axis.y, axis.z, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Scale uniformly from origin
    public func scaled(by factor: Double) -> Shape? {
        guard let handle = OCCTShapeScale(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Mirror across a plane
    public func mirrored(planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero) -> Shape? {
        guard let handle = OCCTShapeMirror(
            self.handle,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z
        ) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Compound Operations

    /// Combine multiple shapes into a compound (no boolean, just grouping)
    public static func compound(_ shapes: [Shape]) -> Shape? {
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateCompound(buffer.baseAddress, Int32(shapes.count))
        }) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Conversion

    /// Wrap a Wire as a Shape to access edge extraction and other Shape methods.
    ///
    /// Since `TopoDS_Wire` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion that enables using Shape methods like
    /// `allEdgePolylines()` on wire geometry without creating solid geometry.
    ///
    /// - Parameter wire: The wire to wrap.
    /// - Returns: A Shape wrapping the wire, or `nil` on failure.
    public static func fromWire(_ wire: Wire) -> Shape? {
        guard let handle = OCCTShapeFromWire(wire.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Wrap an Edge as a Shape to use it with Shape-based APIs.
    ///
    /// Since `TopoDS_Edge` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion.
    ///
    /// - Parameter edge: The edge to wrap.
    /// - Returns: A Shape wrapping the edge, or `nil` on failure.
    public static func fromEdge(_ edge: Edge) -> Shape? {
        guard let handle = OCCTShapeFromEdge(edge.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Wrap a Face as a Shape to use it with Shape-based APIs.
    ///
    /// Since `TopoDS_Face` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion.
    ///
    /// - Parameter face: The face to wrap.
    /// - Returns: A Shape wrapping the face, or `nil` on failure.
    public static func fromFace(_ face: Face) -> Shape? {
        guard let handle = OCCTShapeFromFace(face.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Validation

    /// Check if shape is valid
    public var isValid: Bool {
        OCCTShapeIsValid(handle)
    }

    /// Attempt to repair/heal the shape
    public func healed() -> Shape? {
        guard let handle = OCCTShapeHeal(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Meshing

    /// Generate a triangulated mesh for visualization
    public func mesh(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5
    ) -> Mesh? {
        guard let meshHandle = OCCTShapeCreateMesh(handle, linearDeflection, angularDeflection) else { return nil }
        return Mesh(handle: meshHandle)
    }

    /// Generate a triangulated mesh with progress + cancellation support.
    ///
    /// Wraps `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)` so callers can
    /// observe meshing progress on large or finely-tessellated assemblies and cooperatively
    /// cancel via `progress.shouldCancel()`. After meshing completes, the shape's faces
    /// have triangulations attached and `mesh()` (no progress) can extract them.
    ///
    /// - Throws: `ImportError.cancelled` if the meshing was cancelled cooperatively.
    /// - Returns: The same shape (with triangulations attached) on success, or nil on
    ///   internal failure (no exception thrown for non-cancellation failures, matching
    ///   the existing `mesh()` API).
    @discardableResult
    public func meshWithProgress(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5,
        progress: ImportProgress? = nil
    ) throws -> Shape {
        var cancelled: Bool = false
        let result: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTShapeIncrementalMeshProgress(handle, linearDeflection, angularDeflection, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        // Triangulations are attached to self; the returned handle wraps the same
        // TopoDS_Shape. Release the new wrapper if we don't need it as a separate object.
        if let result {
            OCCTShapeRelease(result)
        }
        return self
    }

    /// Generate a triangulated mesh with enhanced parameters.
    ///
    /// This method provides fine-grained control over tessellation quality,
    /// useful for CAM toolpath generation or high-quality visualization.
    ///
    /// ```swift
    /// var params = MeshParameters.default
    /// params.deflection = 0.02  // Very fine mesh
    /// params.inParallel = true  // Multi-threaded
    /// let mesh = shape.mesh(parameters: params)
    /// ```
    ///
    /// - Parameter parameters: Enhanced mesh parameters
    /// - Returns: A `Mesh` with the specified quality settings
    public func mesh(parameters: MeshParameters) -> Mesh? {
        let bridgeParams = parameters.toBridge()
        guard let meshHandle = OCCTShapeCreateMeshWithParams(handle, bridgeParams) else { return nil }
        return Mesh(handle: meshHandle)
    }

    // MARK: - Edge Discretization

    /// Get a discretized edge as a polyline.
    ///
    /// This method adaptively samples points along a B-Rep edge using
    /// curvature-based deflection control. Useful for:
    /// - Contour toolpath generation
    /// - Edge visualization
    /// - G-code generation from curve edges
    ///
    /// - Parameters:
    ///   - index: Edge index (0-based)
    ///   - deflection: Maximum chord deviation
    ///   - maxPoints: Maximum number of points to return
    /// - Returns: Array of 3D points along the edge, or nil if edge not found
    public func edgePolyline(
        at index: Int,
        deflection: Double = 0.1,
        maxPoints: Int = 1000
    ) -> [SIMD3<Double>]? {
        var points = [Double](repeating: 0, count: maxPoints * 3)
        let numPoints = points.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeGetEdgePolyline(handle, Int32(index), deflection, buffer.baseAddress, Int32(maxPoints))
        }

        guard numPoints > 0 else { return nil }

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(numPoints))

        for i in 0..<Int(numPoints) {
            result.append(SIMD3(
                points[i * 3],
                points[i * 3 + 1],
                points[i * 3 + 2]
            ))
        }

        return result
    }

    /// Get all edges as discretized polylines.
    ///
    /// Convenience method that calls `edgePolyline` for each edge in the shape.
    ///
    /// - Parameters:
    ///   - deflection: Maximum chord deviation
    ///   - maxPointsPerEdge: Maximum points per edge
    /// - Returns: Array of polylines, one per edge
    public func allEdgePolylines(
        deflection: Double = 0.1,
        maxPointsPerEdge: Int = 1000
    ) -> [[SIMD3<Double>]] {
        // Build 3D curves for all edges upfront. Lofted/swept shapes may only
        // have pcurves; this ensures explicit 3D curves exist before discretization.
        OCCTShapeBuildCurves3d(handle)

        let count = Int(OCCTShapeGetTotalEdgeCount(handle))
        var result: [[SIMD3<Double>]] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            if let polyline = edgePolyline(at: i, deflection: deflection, maxPoints: maxPointsPerEdge) {
                result.append(polyline)
            }
        }

        return result
    }

    // MARK: - Import

    /// Load a shape from a STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file.
    ///   - progress: Optional progress + cancellation channel.
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: url.path, progress: progress)
    }

    /// Load a shape from a STEP file path.
    public static func load(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: path, progress: progress)
    }

    /// Load a shape from a STEP file (alias for ``load(from:progress:)`` with explicit naming).
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: url.path, progress: progress)
    }

    /// Load a shape from a STEP file path with optional progress.
    public static func loadSTEP(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportSTEPProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import STEP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - STEP Reader Control (v0.58.0)

    /// Get the number of transferable roots in a STEP file.
    ///
    /// Use this to inspect a STEP file before importing specific roots.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Number of roots (0 if file can't be read)
    public static func stepRootCount(url: URL) -> Int {
        Int(OCCTSTEPReaderNbRoots(url.path))
    }

    /// Get the number of transferable roots in a STEP file.
    public static func stepRootCount(path: String) -> Int {
        Int(OCCTSTEPReaderNbRoots(path))
    }

    /// Import a specific root from a STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - rootIndex: 1-based root index
    /// - Returns: The imported shape
    /// - Throws: ImportError if import fails
    public static func loadSTEPRoot(from url: URL, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportSTEPRoot(url.path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import root \(rootIndex) from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import a specific root from a STEP file.
    public static func loadSTEPRoot(fromPath path: String, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportSTEPRoot(path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import root \(rootIndex) from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Import a STEP file with a specific system length unit.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - unitInMeters: System length unit in meters (e.g. 0.001 for mm, 0.0254 for inch)
    /// - Returns: The imported shape in the specified unit system
    /// - Throws: ImportError if import fails
    public static func loadSTEP(from url: URL, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape {
        try loadSTEP(fromPath: url.path, unitInMeters: unitInMeters, progress: progress)
    }

    /// Import a STEP file with a specific system length unit.
    public static func loadSTEP(fromPath path: String, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportSTEPWithUnitProgress(path, unitInMeters, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import with unit from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Get the number of shapes in a STEP file after full transfer.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Number of shapes (0 if file can't be read)
    public static func stepShapeCount(url: URL) -> Int {
        Int(OCCTSTEPReaderNbShapes(url.path))
    }

    /// Get the number of shapes in a STEP file after full transfer.
    public static func stepShapeCount(path: String) -> Int {
        Int(OCCTSTEPReaderNbShapes(path))
    }

    // MARK: - Robust STEP Import

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// This method is recommended for STEP files that may contain:
    /// - Disconnected faces that need sewing
    /// - Shells that need conversion to solids
    /// - Geometry issues that require healing
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: ImportError if import fails
    public static func loadRobust(from url: URL) throws -> Shape {
        guard let handle = OCCTImportSTEPRobust(url.path) else {
            throw ImportError.importFailed("Failed to import: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// - Parameter path: Path to the STEP file
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: ImportError if import fails
    public static func loadRobust(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTEPRobust(path) else {
            throw ImportError.importFailed("Failed to import: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load a STEP file with diagnostic information about processing steps.
    ///
    /// Use this when you need to understand what processing was applied to the imported geometry.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Import result containing the shape and processing information
    /// - Throws: ImportError if import fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try Shape.loadWithDiagnostics(from: stepFile)
    /// print(result.summary)  // "Shell → Solid (processing: sewing, solid creation, healing)"
    /// let shape = result.shape
    /// ```
    public static func loadWithDiagnostics(from url: URL) throws -> ImportResult {
        let result = OCCTImportSTEPWithDiagnostics(url.path)
        guard let handle = result.shape else {
            throw ImportError.importFailed("Failed to import: \(url.lastPathComponent)")
        }
        return ImportResult(
            shape: Shape(handle: handle),
            originalType: ShapeType(rawValue: Int(result.originalType)) ?? .unknown,
            resultType: ShapeType(rawValue: Int(result.resultType)) ?? .unknown,
            sewingApplied: result.sewingApplied,
            solidCreated: result.solidCreated,
            healingApplied: result.healingApplied
        )
    }

    // MARK: - IGES Import (v0.10.0)

    /// Load a shape from an IGES file
    ///
    /// IGES (Initial Graphics Exchange Specification) is a legacy CAD format
    /// still commonly used in manufacturing and older CAD systems.
    ///
    /// - Parameter url: URL to the IGES file (.igs or .iges)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadIGES(fromPath: url.path, progress: progress)
    }

    /// Load a shape from an IGES file path
    public static func loadIGES(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportIGESProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import IGES file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an IGES file with automatic repair (sewing and healing)
    ///
    /// - Parameters:
    ///   - url: URL to the IGES file
    ///   - progress: Optional progress + cancellation channel.
    /// - Returns: Processed shape with healing applied
    /// - Throws: `ImportError.cancelled` if cancelled, `ImportError.importFailed` on failure.
    public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape {
        try loadIGESRobust(fromPath: url.path, progress: progress)
    }

    /// Load an IGES file with automatic repair from a path.
    public static func loadIGESRobust(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape {
        var cancelled: Bool = false
        let handle: OCCTShapeRef? = withImportProgress(progress) { ctx in
            OCCTImportIGESRobustProgress(path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to import IGES file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - IGES Reader Control (v0.59.0)

    /// Get the number of transferable roots in an IGES file.
    public static func igesRootCount(url: URL) -> Int {
        Int(OCCTIGESReaderNbRoots(url.path))
    }

    /// Get the number of transferable roots in an IGES file.
    public static func igesRootCount(path: String) -> Int {
        Int(OCCTIGESReaderNbRoots(path))
    }

    /// Import a specific root from an IGES file (1-based index).
    public static func loadIGESRoot(from url: URL, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportIGESRoot(url.path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import IGES root \(rootIndex) from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import a specific root from an IGES file (1-based index).
    public static func loadIGESRoot(fromPath path: String, rootIndex: Int) throws -> Shape {
        guard let handle = OCCTImportIGESRoot(path, Int32(rootIndex)) else {
            throw ImportError.importFailed("Failed to import IGES root \(rootIndex) from: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Get the number of shapes in an IGES file after full transfer.
    public static func igesShapeCount(url: URL) -> Int {
        Int(OCCTIGESReaderNbShapes(url.path))
    }

    /// Get the number of shapes in an IGES file after full transfer.
    public static func igesShapeCount(path: String) -> Int {
        Int(OCCTIGESReaderNbShapes(path))
    }

    /// Import only visible entities from an IGES file.
    public static func loadIGESVisible(from url: URL) throws -> Shape {
        guard let handle = OCCTImportIGESVisible(url.path) else {
            throw ImportError.importFailed("Failed to import visible IGES entities from: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Import only visible entities from an IGES file.
    public static func loadIGESVisible(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportIGESVisible(path) else {
            throw ImportError.importFailed("Failed to import visible IGES entities from: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - BREP Import (v0.10.0)

    /// Load a shape from OCCT's native BREP format
    ///
    /// BREP is OCCT's native format for exact B-Rep geometry. It preserves
    /// the full precision of the geometry and is useful for:
    /// - Fast caching of intermediate results
    /// - Debugging geometry issues
    /// - Archiving exact geometry
    ///
    /// - Parameter url: URL to the BREP file (.brep)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadBREP(from url: URL) throws -> Shape {
        guard let handle = OCCTImportBREP(url.path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from a BREP file path
    public static func loadBREP(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportBREP(path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - STL Import (v0.17.0)

    /// Load a shape from an STL file
    ///
    /// - Parameter url: URL to the STL file (.stl)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadSTL(from url: URL) throws -> Shape {
        guard let handle = OCCTImportSTL(url.path) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an STL file path
    public static func loadSTL(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTL(path) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing (sew + solid creation + heal)
    ///
    /// - Parameters:
    ///   - url: URL to the STL file
    ///   - sewingTolerance: Tolerance for sewing disconnected faces (default: 1e-6)
    /// - Returns: Processed shape suitable for solid operations
    /// - Throws: ImportError if import fails
    public static func loadSTLRobust(from url: URL, sewingTolerance: Double = 1e-6) throws -> Shape {
        guard let handle = OCCTImportSTLRobust(url.path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing from a path
    public static func loadSTLRobust(fromPath path: String, sewingTolerance: Double = 1e-6) throws -> Shape {
        guard let handle = OCCTImportSTLRobust(path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - OBJ Import (v0.17.0)

    /// Load a shape from an OBJ file
    ///
    /// - Parameter url: URL to the OBJ file (.obj)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadOBJ(from url: URL) throws -> Shape {
        guard let handle = OCCTImportOBJ(url.path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an OBJ file path
    public static func loadOBJ(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportOBJ(path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - Geometry Construction (v0.11.0)

    /// Create a planar face from a closed wire
    ///
    /// - Parameters:
    ///   - wire: A closed wire defining the face boundary
    ///   - planar: If true, requires the wire to be planar (default: true)
    ///
    /// - Returns: A face shape, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let rect = Wire.rectangle(width: 10, height: 5)!
    /// let face = Shape.face(from: rect)!
    /// let box = face.extruded(direction: [0, 0, 1], length: 3)
    /// ```
    public static func face(from wire: Wire, planar: Bool = true) -> Shape? {
        guard let handle = OCCTShapeCreateFaceFromWire(wire.handle, planar) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a face with holes from outer and inner wires
    ///
    /// - Parameters:
    ///   - outer: The outer boundary wire (closed)
    ///   - holes: Array of inner boundary wires defining holes
    ///
    /// - Returns: A face with holes, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let outer = Wire.rectangle(width: 20, height: 20)!
    /// let hole1 = Wire.circle(radius: 3)!.translated(x: -5, y: 0, z: 0)
    /// let hole2 = Wire.circle(radius: 3)!.translated(x: 5, y: 0, z: 0)
    /// let face = Shape.face(outer: outer, holes: [hole1, hole2])!
    /// ```
    public static func face(outer: Wire, holes: [Wire]) -> Shape? {
        var holeHandles = holes.map { $0.handle as OCCTWireRef? }
        guard let handle = holeHandles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeCreateFaceWithHoles(outer.handle, buffer.baseAddress, Int32(holes.count))
        }) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a solid from a closed shell
    ///
    /// Converts a shell (set of connected faces) into a solid. The shell
    /// must be closed (no gaps) for this to succeed.
    ///
    /// - Parameter shell: A shell shape (typically from sewing operations)
    /// - Returns: A solid shape, or nil if the shell is not closed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sewn = Shape.sew(faces: faces, tolerance: 1e-6)!
    /// let solid = Shape.solid(from: sewn)!
    /// ```
    public static func solid(from shell: Shape) -> Shape? {
        guard let handle = OCCTShapeCreateSolidFromShell(shell.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew multiple shapes into a connected shell or solid
    ///
    /// Sewing connects faces that share edges within the tolerance. This is
    /// useful for repairing imported geometry or combining separately created faces.
    ///
    /// - Parameters:
    ///   - shapes: Array of shapes (faces, shells) to sew together
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape (shell or solid if closed), or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create faces manually and sew into solid
    /// let faces = [topFace, bottomFace, frontFace, backFace, leftFace, rightFace]
    /// let solid = Shape.sew(shapes: faces, tolerance: 0.01)!
    /// ```
    public static func sew(shapes: [Shape], tolerance: Double = 1e-6) -> Shape? {
        guard !shapes.isEmpty else { return nil }

        var shapeHandles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let handle = shapeHandles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeSew(buffer.baseAddress, Int32(shapes.count), tolerance)
        }) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew two shapes together
    ///
    /// - Parameters:
    ///   - shape: First shape to sew
    ///   - other: Second shape to sew
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public static func sew(_ shape: Shape, with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewTwo(shape.handle, other.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew this shape with another
    ///
    /// - Parameters:
    ///   - other: Shape to sew with
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        Shape.sew(self, with: other, tolerance: tolerance)
    }

    // MARK: - Feature-Based Modeling (v0.12.0)

    /// Add a prismatic boss or pocket to the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude (should be on a face of this shape)
    ///   - direction: Extrusion direction
    ///   - height: Extrusion height
    ///   - fuse: If true, adds material (boss); if false, removes material (pocket)
    ///
    /// - Returns: Modified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 50, height: 50, depth: 10)
    /// let bossProfile = Wire.circle(radius: 5)!.offset3D(distance: 25, direction: SIMD3(0, 0, 1))!
    /// let withBoss = box.withPrism(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5, fuse: true)
    /// ```
    public func withPrism(profile: Wire, direction: SIMD3<Double>, height: Double, fuse: Bool) -> Shape? {
        guard let handle = OCCTShapePrism(self.handle, profile.handle,
                                          direction.x, direction.y, direction.z,
                                          height, fuse) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Add a boss (raised feature) to the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - direction: Extrusion direction
    ///   - height: Boss height
    ///
    /// - Returns: Shape with added boss, or nil on failure
    public func withBoss(profile: Wire, direction: SIMD3<Double>, height: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: height, fuse: true)
    }

    /// Create a pocket (depression) in the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile defining the pocket boundary
    ///   - direction: Pocket direction (into the shape)
    ///   - depth: Pocket depth
    ///
    /// - Returns: Shape with pocket, or nil on failure
    public func withPocket(profile: Wire, direction: SIMD3<Double>, depth: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: depth, fuse: false)
    }

    /// Drill a cylindrical hole into the shape
    ///
    /// - Parameters:
    ///   - position: Position of hole center on surface
    ///   - direction: Drill direction (into the shape)
    ///   - radius: Hole radius
    ///   - depth: Hole depth (0 for through-hole)
    ///
    /// - Returns: Shape with drilled hole, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 10)
    /// let drilled = plate.drilled(at: SIMD3(25, 25, 10), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
    /// ```
    public func drilled(at position: SIMD3<Double>, direction: SIMD3<Double>, radius: Double, depth: Double = 0) -> Shape? {
        guard let handle = OCCTShapeDrillHole(self.handle,
                                              position.x, position.y, position.z,
                                              direction.x, direction.y, direction.z,
                                              radius, depth) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Split the shape using a cutting tool
    ///
    /// - Parameter tool: Shape to use as cutting tool
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)
    /// let cuttingPlane = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
    /// let halves = box.split(by: cuttingPlane.translated(by: SIMD3(0, 0, 10)))
    /// ```
    public func split(by tool: Shape) -> [Shape]? {
        var count: Int32 = 0
        guard let shapesPtr = OCCTShapeSplit(self.handle, tool.handle, &count),
              count > 0 else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        // Free only the array, not the shapes (we've taken ownership)
        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Split the shape by a plane
    ///
    /// - Parameters:
    ///   - point: A point on the cutting plane
    ///   - normal: Normal vector of the cutting plane
    ///
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cube = Shape.box(width: 20, height: 20, depth: 20)
    /// // Split horizontally at Z=10
    /// let halves = cube.split(atPlane: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
    /// ```
    public func split(atPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> [Shape]? {
        var count: Int32 = 0
        guard let shapesPtr = OCCTShapeSplitByPlane(self.handle,
                                                     point.x, point.y, point.z,
                                                     normal.x, normal.y, normal.z,
                                                     &count),
              count > 0 else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Glue two shapes together at coincident faces
    ///
    /// More efficient than boolean union when shapes have faces that perfectly align.
    ///
    /// - Parameters:
    ///   - shape1: First shape
    ///   - shape2: Second shape with coincident faces
    ///   - tolerance: Tolerance for face matching (default: 1e-6)
    ///
    /// - Returns: Glued shape, or nil on failure
    public static func glue(_ shape1: Shape, _ shape2: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeGlue(shape1.handle, shape2.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create an evolved shape (profile swept along spine with rotation)
    ///
    /// The profile is swept along the spine, with its orientation evolving
    /// to stay perpendicular to the spine.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///
    /// - Returns: Evolved shape, or nil on failure
    public static func evolved(spine: Wire, profile: Wire) -> Shape? {
        guard let handle = OCCTShapeCreateEvolved(spine.handle, profile.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create an evolved shape with full parameter control.
    ///
    /// Extends the basic `evolved` method with control over join type, coordinate
    /// system, solid/volume mode, and tolerance.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///   - joinType: How to join offset edges (default: .arc)
    ///   - axeProf: If true, profile is in global coordinates; if false, local to spine
    ///   - solid: If true, produce a solid result
    ///   - volume: If true, use volume mode (removes self-intersections)
    ///   - tolerance: Tolerance for evolved shape creation
    /// - Returns: Evolved shape, or nil on failure
    public static func evolvedAdvanced(spine: Shape, profile: Wire,
                                       joinType: OffsetJoinType = .arc,
                                       axeProf: Bool = true,
                                       solid: Bool = true,
                                       volume: Bool = false,
                                       tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeCreateEvolvedAdvanced(spine.handle, profile.handle,
                                                      joinType.rawValue, axeProf,
                                                      solid, volume, tolerance) else { return nil }
        return Shape(handle: h)
    }

    /// Create a linear pattern of the shape
    ///
    /// - Parameters:
    ///   - direction: Direction of the pattern
    ///   - spacing: Distance between copies
    ///   - count: Number of copies (including original)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10)
    /// let rowOfHoles = hole.linearPattern(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)
    /// ```
    public func linearPattern(direction: SIMD3<Double>, spacing: Double, count: Int) -> Shape? {
        guard let handle = OCCTShapeLinearPattern(self.handle,
                                                   direction.x, direction.y, direction.z,
                                                   spacing, Int32(count)) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a circular pattern of the shape.
    ///
    /// This duplicates **the whole body** `count` times around the axis and returns
    /// a compound of the copies. It does **not** pattern features. If `self` is a
    /// solid that already has a hole/pocket cut into it, the result is `count`
    /// overlapping copies of that solid — the holes get filled by neighbouring
    /// copies, not replicated. For the bolt-circle use case ("drill one hole, then
    /// repeat it around the axis") pattern the *tool* shape and subtract it, or use
    /// ``circularPatternCut(tool:axisPoint:axisDirection:count:angle:)`` which does
    /// exactly that in one call.
    ///
    /// - Parameters:
    ///   - axisPoint: Point on the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - count: Number of copies (including original)
    ///   - angle: Total angle to span in radians (0 for full circle)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10).translated(by: SIMD3(20, 0, 0))
    /// // Create 6 hole *tools* in a circle around the Z axis, then subtract them
    /// let tools = hole.circularPattern(
    ///     axisPoint: .zero,
    ///     axisDirection: SIMD3(0, 0, 1),
    ///     count: 6,
    ///     angle: 0  // Full circle
    /// )
    /// let drilled = flange.subtracting(tools!)
    /// ```
    public func circularPattern(axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>, count: Int, angle: Double = 0) -> Shape? {
        guard let handle = OCCTShapeCircularPattern(self.handle,
                                                     axisPoint.x, axisPoint.y, axisPoint.z,
                                                     axisDirection.x, axisDirection.y, axisDirection.z,
                                                     Int32(count), angle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Replicate a feature (a cut/tool shape) around an axis and subtract all
    /// copies from this body in one operation.
    ///
    /// This is the feature-aware companion to
    /// ``circularPattern(axisPoint:axisDirection:count:angle:)``. Where the plain
    /// pattern duplicates the *body*, this one duplicates the *tool* `count` times
    /// around the axis and subtracts the resulting compound from `self`. It is the
    /// natural primitive for a bolt circle: build one hole tool, then pattern it.
    ///
    /// - Parameters:
    ///   - tool: The cutting feature to replicate (e.g. a cylinder positioned at
    ///     the first hole). Patterned about the same axis, then subtracted.
    ///   - axisPoint: Point on the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - count: Number of tool copies (including the original `tool`)
    ///   - angle: Total angle to span in radians (0 for a full circle)
    /// - Returns: This body with all `count` features cut out, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Drill one hole, then repeat it 8× around the Z axis for a bolt circle
    /// let bcr = 40.0
    /// let hole = Shape.cylinder(radius: 3, height: 20)
    ///     .translated(by: SIMD3(bcr, 0, 0))
    /// let flange = blank.circularPatternCut(
    ///     tool: hole,
    ///     axisPoint: .zero,
    ///     axisDirection: SIMD3(0, 0, 1),
    ///     count: 8
    /// )
    /// ```
    public func circularPatternCut(tool: Shape, axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>, count: Int, angle: Double = 0) -> Shape? {
        guard count > 0 else { return nil }
        guard let tools = tool.circularPattern(axisPoint: axisPoint,
                                               axisDirection: axisDirection,
                                               count: count, angle: angle) else {
            return nil
        }
        return subtracting(tools)
    }

    // MARK: - Shape Type

    /// The topological type of the shape
    public var shapeType: ShapeType {
        ShapeType(rawValue: Int(OCCTShapeGetType(handle))) ?? .unknown
    }

    /// Whether the shape is a valid closed solid suitable for CAM operations.
    ///
    /// This is a **topology / per-element** validity check (`BRepCheck_Analyzer`): it does
    /// **not** detect *global self-intersection* (overlapping faces of a single solid). A
    /// self-intersecting B-spline solid — e.g. from `loft(ruled: false)` on imperfectly
    /// corresponding profiles — can report `isValidSolid == true` yet poison downstream
    /// booleans (it made `subtracting` hang indefinitely before #206 bounded it). To screen
    /// for that, use ``isSelfIntersecting(timeout:)``. See also ``signedVolume`` /
    /// ``orientedForward()`` for the separate reversed-orientation hazard.
    public var isValidSolid: Bool {
        OCCTShapeIsValidSolid(handle)
    }

    /// Whether this shape **self-intersects** — overlapping or interfering sub-faces, the
    /// defect that ``isValidSolid`` (a topology check) misses but that can make booleans
    /// hang or return garbage (#206/#208).
    ///
    /// Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test, which is authoritative
    /// but **expensive** (seconds on B-spline solids) and can otherwise run unbounded, so it
    /// is wall-clock bounded by `timeout`.
    ///
    /// - Parameter timeout: Seconds before the check gives up (default 30). `0`/negative = unbounded.
    /// - Returns: `true` if a self-interference was found, `false` if the shape is clean, or
    ///   `nil` if the check could not complete within `timeout` (**indeterminate** — treat as
    ///   "unknown", not "clean").
    ///
    /// Validate-at-the-source recipe for a loft result before using it in a boolean:
    /// ```swift
    /// guard let solid = Shape.loft(profiles: ps, ruled: false)?.orientedForward(),
    ///       solid.isSelfIntersecting() == false else { /* reject */ }
    /// ```
    public func isSelfIntersecting(timeout: Double = 30) -> Bool? {
        switch OCCTShapeSelfIntersectsBounded(handle, timeout) {
        case 1:  return true
        case 0:  return false
        default: return nil   // -1: indeterminate (timed out / errored)
        }
    }

    // MARK: - Sub-Shape Extraction

    /// Get the number of sub-shapes of a given topological type.
    ///
    /// - Parameter type: The topological type to count (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Number of sub-shapes of that type
    public func subShapeCount(ofType type: ShapeType) -> Int {
        Int(OCCTShapeGetSubShapeCount(handle, Int32(type.rawValue)))
    }

    /// Get a sub-shape by type and 0-based index.
    ///
    /// Uses `TopExp::MapShapes` to enumerate sub-shapes of the given type,
    /// then returns the one at the specified index as a `Shape` handle.
    ///
    /// - Parameters:
    ///   - type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    ///   - index: 0-based index into the sub-shapes of that type
    /// - Returns: The sub-shape as a Shape, or nil if index is out of range
    public func subShape(type: ShapeType, index: Int) -> Shape? {
        guard let ref = OCCTShapeGetSubShapeByTypeIndex(handle, Int32(type.rawValue), Int32(index)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get all sub-shapes of a given topological type.
    ///
    /// - Parameter type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Array of sub-shapes
    public func subShapes(ofType type: ShapeType) -> [Shape] {
        let count = subShapeCount(ofType: type)
        return (0..<count).compactMap { subShape(type: type, index: $0) }
    }

    // MARK: - Bounds

    /// Get the axis-aligned bounding box of the shape
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTShapeGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }

    /// Size of the bounding box
    public var size: SIMD3<Double> {
        let b = bounds
        return b.max - b.min
    }

    /// Center of the bounding box
    public var center: SIMD3<Double> {
        let b = bounds
        return (b.min + b.max) / 2
    }

    // MARK: - Slicing

    /// Slice the shape at a given Z height, returning the cross-section as edges
    public func sliceAtZ(_ z: Double) -> Shape? {
        guard let handle = OCCTShapeSliceAtZ(self.handle, z) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Get closed wires from a section at Z level.
    ///
    /// This is useful for CAM operations where you need to work with closed contours
    /// that can be offset for tool compensation.
    ///
    /// - Parameters:
    ///   - z: The Z level to section at
    ///   - tolerance: Tolerance for connecting edges into wires. Use larger values
    ///                (e.g., 1e-4) for imprecise geometry. Default is 1e-6.
    /// - Returns: Array of closed wires representing contours at that Z level.
    ///            Returns empty array if no contours exist at that level.
    ///
    /// Unlike `sliceAtZ(_:)` which returns a shape with loose edges, this method
    /// chains the edges into closed wires that can be used with `Wire.offset(by:)`.
    ///
    /// ## Example: CAM Safety Boundary
    ///
    /// ```swift
    /// let model = try Shape.load(from: stepFile)
    ///
    /// // Get model contour at Z = 5.0
    /// let wires = model.sectionWiresAtZ(5.0)
    ///
    /// for contour in wires {
    ///     // Offset outward by tool radius + stock allowance
    ///     if let safetyBoundary = contour.offset(by: toolRadius + stockAllowance) {
    ///         // Tool center must stay outside this boundary
    ///     }
    /// }
    /// ```
    public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire] {
        var count: Int32 = 0
        guard let wireArray = OCCTShapeSectionWiresAtZ(handle, z, tolerance, &count) else {
            return []
        }
        // Use OCCTFreeWireArrayOnly - Swift Wire objects now own the wire handles
        // and will release them in their deinit. We only need to free the array container.
        defer { OCCTFreeWireArrayOnly(wireArray) }

        var wires: [Wire] = []
        for i in 0..<Int(count) {
            if let wireHandle = wireArray[i] {
                wires.append(Wire(handle: wireHandle))
            }
        }
        return wires
    }

    /// Get points along an edge at the given index.
    ///
    /// Points are sampled uniformly along the edge curve from start to end.
    /// - Parameter index: The edge index (0 to edgeCount-1)
    /// - Parameter maxPoints: Maximum points to return (capped at 20 internally for performance)
    /// - Returns: Array of 3D points along the edge curve
    public func edgePoints(at index: Int, maxPoints: Int = 20) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let count = OCCTShapeGetEdgePoints(handle, Int32(index), &buffer, Int32(maxPoints))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i*3], buffer[i*3+1], buffer[i*3+2]))
        }
        return points
    }

    /// Get all contour points from the shape's edges.
    ///
    /// Note: This returns edge START vertices only, not intermediate curve points.
    /// For curved edges, use `edgePoints(at:maxPoints:)` to get curve samples.
    /// This is suitable for simple polygon contours from Z-plane slices.
    ///
    /// - Parameter maxPoints: Maximum number of points to return
    /// - Returns: Array of 3D points (one per edge start vertex)
    public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let count = OCCTShapeGetContourPoints(handle, &buffer, Int32(maxPoints))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i*3], buffer[i*3+1], buffer[i*3+2]))
        }
        return points
    }
}

// MARK: - Errors

public enum ImportError: Error, LocalizedError {
    case importFailed(String)
    /// The import was cancelled cooperatively via `ImportProgress.shouldCancel()`.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .importFailed(let message):
            return message
        case .cancelled:
            return "Import cancelled"
        }
    }
}

// MARK: - Shape Type

/// Topological type of a shape (matches OCCT TopAbs_ShapeEnum)
public enum ShapeType: Int, CustomStringConvertible, Sendable {
    case compound = 0
    case compSolid = 1
    case solid = 2
    case shell = 3
    case face = 4
    case wire = 5
    case edge = 6
    case vertex = 7
    case unknown = -1

    public var description: String {
        switch self {
        case .compound: return "Compound"
        case .compSolid: return "CompSolid"
        case .solid: return "Solid"
        case .shell: return "Shell"
        case .face: return "Face"
        case .wire: return "Wire"
        case .edge: return "Edge"
        case .vertex: return "Vertex"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Import Result

/// Result of a robust STEP import with diagnostic information
public struct ImportResult: Sendable {
    /// The imported and processed shape
    public let shape: Shape

    /// Original shape type as read from STEP file
    public let originalType: ShapeType

    /// Final shape type after processing
    public let resultType: ShapeType

    /// Whether sewing was applied to connect disconnected faces
    public let sewingApplied: Bool

    /// Whether a solid was created from a shell
    public let solidCreated: Bool

    /// Whether shape healing was applied
    public let healingApplied: Bool

    /// Human-readable summary of the import processing
    public var summary: String {
        var steps: [String] = []
        if sewingApplied { steps.append("sewing") }
        if solidCreated { steps.append("solid creation") }
        if healingApplied { steps.append("healing") }
        let processing = steps.isEmpty ? "none" : steps.joined(separator: ", ")
        return "\(originalType) → \(resultType) (processing: \(processing))"
    }
}

// MARK: - Operators

extension Shape {
    public static func + (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.union(rhs)
    }

    public static func - (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.subtracting(rhs)
    }

    public static func & (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.intersection(rhs)
    }
}

// MARK: - Measurement & Analysis (v0.7.0)

/// Mass and geometric properties of a shape
public struct ShapeProperties: Sendable, Equatable {
    /// Volume in cubic units
    public var volume: Double

    /// Surface area in square units
    public var surfaceArea: Double

    /// Mass (volume × density)
    public var mass: Double

    /// Center of mass location
    public var centerOfMass: SIMD3<Double>

    /// Moment of inertia tensor (3x3 matrix)
    public var momentOfInertia: simd_double3x3

    public init(
        volume: Double,
        surfaceArea: Double,
        mass: Double,
        centerOfMass: SIMD3<Double>,
        momentOfInertia: simd_double3x3
    ) {
        self.volume = volume
        self.surfaceArea = surfaceArea
        self.mass = mass
        self.centerOfMass = centerOfMass
        self.momentOfInertia = momentOfInertia
    }
}

/// Result of distance measurement between two shapes
public struct DistanceResult: Sendable, Equatable {
    /// Minimum distance between the shapes
    public var distance: Double

    /// Closest point on the first shape
    public var pointOnShape1: SIMD3<Double>

    /// Closest point on the second shape
    public var pointOnShape2: SIMD3<Double>

    /// Number of solutions found (may be > 1 for symmetric cases)
    public var solutionCount: Int

    public init(
        distance: Double,
        pointOnShape1: SIMD3<Double>,
        pointOnShape2: SIMD3<Double>,
        solutionCount: Int
    ) {
        self.distance = distance
        self.pointOnShape1 = pointOnShape1
        self.pointOnShape2 = pointOnShape2
        self.solutionCount = solutionCount
    }
}

// MARK: - Shape Measurement Extensions

extension Shape {

    /// Get full mass properties of the shape
    ///
    /// - Parameter density: Material density for mass calculation (default 1.0)
    /// - Returns: Properties including volume, surface area, center of mass, and inertia tensor,
    ///            or nil if calculation fails
    public func properties(density: Double = 1.0) -> ShapeProperties? {
        let result = OCCTShapeGetProperties(handle, density)
        guard result.isValid else { return nil }

        let inertia = simd_double3x3(
            SIMD3<Double>(result.ixx, result.iyx, result.izx),
            SIMD3<Double>(result.ixy, result.iyy, result.izy),
            SIMD3<Double>(result.ixz, result.iyz, result.izz)
        )

        return ShapeProperties(
            volume: result.volume,
            surfaceArea: result.surfaceArea,
            mass: result.mass,
            centerOfMass: SIMD3<Double>(result.centerX, result.centerY, result.centerZ),
            momentOfInertia: inertia
        )
    }

    /// Volume of the shape in cubic units
    public var volume: Double? {
        let v = OCCTShapeGetVolume(handle)
        return v >= 0 ? v : nil
    }

    /// Signed volume of the shape in cubic units.
    ///
    /// Unlike ``volume``, this preserves the sign that `BRepGProp` reports: a
    /// reversed-orientation solid (faces pointing inward) returns a **negative**
    /// value. Use this to detect orientation problems; use ``orientedForward()``
    /// to fix them.
    public var signedVolume: Double {
        OCCTShapeGetVolume(handle)
    }

    /// Return a copy of this solid whose faces are oriented outward (positive
    /// volume).
    ///
    /// Some constructors — notably ``sweep(profile:along:)``
    /// (`BRepOffsetAPI_MakePipe`) — can produce a geometrically correct solid whose
    /// faces point inward, so ``signedVolume`` comes back negative. That is a latent
    /// hazard for booleans and any `volume > 0` validation. This reverses the
    /// orientation when, and only when, the signed volume is negative; a solid that
    /// is already forward-oriented (or a shell/face with no enclosed volume) is
    /// returned unchanged.
    ///
    /// - Returns: An outward-oriented copy, `self` when no fix is needed, or nil if
    ///   reversal fails.
    public func orientedForward() -> Shape? {
        signedVolume < 0 ? reversed : self
    }

    /// Surface area of the shape in square units
    public var surfaceArea: Double? {
        let a = OCCTShapeGetSurfaceArea(handle)
        return a >= 0 ? a : nil
    }

    /// Center of mass (centroid) of the shape
    public var centerOfMass: SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTShapeGetCenterOfMass(handle, &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }

    /// Compute minimum distance between this shape and another
    ///
    /// - Parameters:
    ///   - other: The other shape to measure distance to
    ///   - deflection: Tolerance for curved geometry (default 1e-6)
    /// - Returns: Distance result with closest points, or nil if calculation fails
    public func distance(to other: Shape, deflection: Double = 1e-6) -> DistanceResult? {
        let result = OCCTShapeDistance(handle, other.handle, deflection)
        guard result.isValid else { return nil }

        return DistanceResult(
            distance: result.distance,
            pointOnShape1: SIMD3<Double>(result.p1x, result.p1y, result.p1z),
            pointOnShape2: SIMD3<Double>(result.p2x, result.p2y, result.p2z),
            solutionCount: Int(result.solutionCount)
        )
    }

    /// Get minimum distance between this shape and another
    ///
    /// - Parameter other: The other shape
    /// - Returns: Minimum distance, or nil if calculation fails
    public func minDistance(to other: Shape) -> Double? {
        distance(to: other)?.distance
    }

    /// Check if this shape intersects (overlaps or touches) another shape
    ///
    /// - Parameters:
    ///   - other: The other shape to test
    ///   - tolerance: Distance threshold for intersection (default 1e-6)
    /// - Returns: true if shapes intersect or touch within tolerance
    public func intersects(_ other: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTShapeIntersects(handle, other.handle, tolerance)
    }

    // MARK: - Wire/Edge/Face Convenience Overloads

    /// Get minimum distance between this shape and a wire.
    public func distance(to wire: Wire, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromWire(wire) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Get minimum distance between this shape and an edge.
    public func distance(to edge: Edge, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromEdge(edge) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Get minimum distance between this shape and a face.
    public func distance(to face: Face, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromFace(face) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Check if this shape intersects a wire.
    public func intersects(_ wire: Wire, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromWire(wire) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    /// Check if this shape intersects an edge.
    public func intersects(_ edge: Edge, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromEdge(edge) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    /// Check if this shape intersects a face.
    public func intersects(_ face: Face, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromFace(face) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    /// Number of vertices (corners) in the shape
    public var vertexCount: Int {
        Int(OCCTShapeGetVertexCount(handle))
    }

    /// Get all vertices (corner points) of the shape
    ///
    /// - Returns: Array of vertex positions
    public func vertices() -> [SIMD3<Double>] {
        let count = OCCTShapeGetVertexCount(handle)
        guard count > 0 else { return [] }

        var coords = [Double](repeating: 0, count: Int(count) * 3)
        let written = OCCTShapeGetVertices(handle, &coords)

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(written))

        for i in 0..<Int(written) {
            result.append(SIMD3<Double>(
                coords[i * 3],
                coords[i * 3 + 1],
                coords[i * 3 + 2]
            ))
        }
        return result
    }

    /// Get vertex at specific index
    ///
    /// - Parameter index: Zero-based vertex index
    /// - Returns: Vertex position, or nil if index out of bounds
    public func vertex(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTShapeGetVertexAt(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }
}

// MARK: - Advanced Modeling (v0.8.0)

/// Sweep mode for advanced pipe creation
public enum PipeSweepMode: Sendable {
    /// Standard Frenet trihedron - profile orientation follows spine curvature
    case frenet
    /// Corrected Frenet - avoids twisting at inflection points
    case correctedFrenet
    /// Fixed binormal direction - profile maintains constant orientation
    case fixed(binormal: SIMD3<Double>)
    /// Auxiliary spine - twist controlled by secondary curve
    case auxiliary(spine: Wire)
}

/// Transition mode for pipe shell at spine discontinuities (corners).
public enum PipeTransitionMode: Int32, Sendable {
    /// Transformed — smooth transition (default)
    case transformed = 0
    /// Right corner — sharp right-angle transitions
    case rightCorner = 1
    /// Round corner — filleted transitions
    case roundCorner = 2
}

extension Shape {
    // MARK: - Selective Fillet

    /// Fillet specific edges with uniform radius
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - radius: Fillet radius
    /// - Returns: Filleted shape, or nil on failure
    public func filleted(edges: [Edge], radius: Double) -> Shape? {
        guard !edges.isEmpty, radius > 0 else { return nil }

        // Extract indices from edges
        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeFilletEdges(handle, buffer.baseAddress, Int32(indices.count), radius) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// Fillet specific edges with linear radius interpolation
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - startRadius: Radius at start of each edge
    ///   - endRadius: Radius at end of each edge
    /// - Returns: Filleted shape, or nil on failure
    public func filleted(edges: [Edge], startRadius: Double, endRadius: Double) -> Shape? {
        guard !edges.isEmpty, startRadius > 0, endRadius > 0 else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeFilletEdgesLinear(handle, buffer.baseAddress, Int32(indices.count), startRadius, endRadius) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Draft Angle

    /// Add draft angle to faces for mold release
    ///
    /// Draft angles are used in injection molding and casting to allow parts to
    /// be released from the mold. The angle is measured from the pull direction.
    ///
    /// - Parameters:
    ///   - faces: Faces to add draft to (must have valid indices from this shape)
    ///   - direction: Pull direction (typically vertical, e.g., [0, 0, 1])
    ///   - angle: Draft angle in radians (typically 1-5 degrees)
    ///   - neutralPlane: Plane where draft angle is zero (point and normal)
    /// - Returns: Drafted shape, or nil on failure
    public func drafted(
        faces: [Face],
        direction: SIMD3<Double>,
        angle: Double,
        neutralPlane: (point: SIMD3<Double>, normal: SIMD3<Double>)
    ) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeDraft(
                handle,
                buffer.baseAddress,
                Int32(indices.count),
                direction.x, direction.y, direction.z,
                angle,
                neutralPlane.point.x, neutralPlane.point.y, neutralPlane.point.z,
                neutralPlane.normal.x, neutralPlane.normal.y, neutralPlane.normal.z
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Defeaturing

    /// Remove features by deleting faces
    ///
    /// The defeaturing algorithm removes specified faces and heals the resulting
    /// gaps by extending adjacent faces. Useful for simplifying geometry for
    /// analysis or removing small features.
    ///
    /// - Parameter faces: Faces to remove (must have valid indices from this shape)
    /// - Returns: Shape with features removed, or nil on failure
    public func withoutFeatures(faces: [Face]) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeRemoveFeatures(handle, buffer.baseAddress, Int32(indices.count)) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Advanced Pipe Sweep

    /// Create a pipe (sweep) with advanced sweep modes
    ///
    /// Unlike the basic `pipe(profile:path:)`, this method provides control over
    /// how the profile is oriented along the sweep path.
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep
    ///   - profile: Profile wire to sweep
    ///   - mode: Sweep mode controlling profile orientation
    ///   - solid: If true, create a solid; if false, create a shell
    /// - Returns: Swept shape, or nil on failure
    public static func pipeShell(
        spine: Wire,
        profile: Wire,
        mode: PipeSweepMode = .frenet,
        solid: Bool = true
    ) -> Shape? {
        let result: OCCTShapeRef?

        switch mode {
        case .frenet:
            result = OCCTShapeCreatePipeShell(spine.handle, profile.handle, OCCTPipeModeFrenet, solid)
        case .correctedFrenet:
            result = OCCTShapeCreatePipeShell(spine.handle, profile.handle, OCCTPipeModeCorrectedFrenet, solid)
        case .fixed(let binormal):
            result = OCCTShapeCreatePipeShellWithBinormal(spine.handle, profile.handle, binormal.x, binormal.y, binormal.z, solid)
        case .auxiliary(let auxSpine):
            result = OCCTShapeCreatePipeShellWithAuxSpine(spine.handle, profile.handle, auxSpine.handle, solid)
        }

        guard let shapeRef = result else { return nil }
        return Shape(handle: shapeRef)
    }

    /// Create a pipe shell with transition mode control.
    ///
    /// Controls how the profile transitions at discontinuities (corners) in the spine.
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep
    ///   - profile: Profile wire to sweep
    ///   - mode: Sweep mode controlling profile orientation
    ///   - transition: How to handle transitions at spine corners
    ///   - solid: If true, create a solid; if false, create a shell
    /// - Returns: Swept shape, or nil on failure
    public static func pipeShellWithTransition(
        spine: Wire,
        profile: Wire,
        mode: PipeSweepMode = .frenet,
        transition: PipeTransitionMode = .transformed,
        solid: Bool = true
    ) -> Shape? {
        let modeInt: Int32 = {
            switch mode {
            case .correctedFrenet: return 1
            default: return 0
            }
        }()
        guard let h = OCCTShapeCreatePipeShellWithTransition(
            spine.handle, profile.handle, modeInt, transition.rawValue, solid
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Variable-Section Sweep (v0.21.0)

    /// Create a pipe shell with a law function controlling cross-section scaling.
    ///
    /// The law function defines how the profile scales along the spine.
    /// A law value of 1.0 means no scaling; 2.0 means double size, etc.
    public static func pipeShellWithLaw(
        spine: Wire,
        profile: Wire,
        law: LawFunction,
        solid: Bool = true
    ) -> Shape? {
        guard let result = OCCTShapeCreatePipeShellWithLaw(
            spine.handle, profile.handle, law.handle, solid)
        else { return nil }
        return Shape(handle: result)
    }

    /// Sweep several profiles along a spine for a variable-section pipe shell.
    ///
    /// This is the multi-section form of ``pipeShell(spine:profile:mode:solid:)``: each
    /// profile is positioned in 3D at its station along the spine, and OCCT interpolates a
    /// smooth solid (or shell) that passes through every section. It supports the same
    /// orientation modes — including ``PipeSweepMode/auxiliary(spine:)``, which keeps the
    /// section oriented by a secondary curve (e.g. a thread rib that ramps from a runout to
    /// full crest along a helix while staying radial to the axis).
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep.
    ///   - profiles: Profile wires, each positioned at its station along the spine. At least
    ///     one is required; two or more give a genuinely varying section.
    ///   - mode: Sweep mode controlling profile orientation (incl. `.auxiliary(spine:)`).
    ///   - withContact: If true, each profile is moved to touch the spine before sweeping.
    ///   - withCorrection: If true, each profile is rotated to stay orthogonal to the spine.
    ///   - solid: If true, create a solid; if false, a shell.
    /// - Returns: Swept shape, or nil on failure.
    public static func pipeShellMultiSection(
        spine: Wire,
        profiles: [Wire],
        mode: PipeSweepMode = .frenet,
        withContact: Bool = false,
        withCorrection: Bool = false,
        solid: Bool = true
    ) -> Shape? {
        guard !profiles.isEmpty else { return nil }

        let modeValue: OCCTPipeMode
        var binormal = SIMD3<Double>(0, 0, 0)
        var auxHandle: OCCTWireRef? = nil
        switch mode {
        case .frenet:
            modeValue = OCCTPipeModeFrenet
        case .correctedFrenet:
            modeValue = OCCTPipeModeCorrectedFrenet
        case .fixed(let bn):
            modeValue = OCCTPipeModeFixedBinormal
            binormal = bn
        case .auxiliary(let aux):
            modeValue = OCCTPipeModeAuxiliary
            auxHandle = aux.handle
        }

        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        guard let result = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreatePipeShellMultiSection(
                spine.handle, buffer.baseAddress, Int32(profiles.count),
                modeValue, binormal.x, binormal.y, binormal.z,
                auxHandle, withContact, withCorrection, solid)
        }) else { return nil }
        return Shape(handle: result)
    }

    /// Sweep one or more profiles along a helix to build a worm/screw-thread helicoid,
    /// keeping the section *approximately* radial via an auxiliary-spine framing on the axis.
    ///
    /// This is the turnkey form of the #180 sweep for the common helical case. It builds
    /// the helix spine and a correctly-spanning axis auxiliary spine internally, with the
    /// orientation flags (`CurvilinearEquivalence = false`, no contact) that keep the swept
    /// section roughly radial — avoiding the two footguns that make a hand-rolled
    /// `pipeShell(mode: .auxiliary(...))` return nil:
    /// 1. `Wire.helix(clockwise:)` runs the helix toward +axis or −axis depending on
    ///    handedness, so a guessed axis range can miss it entirely; and
    /// 2. the auxiliary spine must span the helix's **full** axial extent or the section
    ///    planes never intersect it.
    ///
    /// - Important: The auxiliary-spine framing is **not exactly radial** — the result bulges
    ///   ~10–15% beyond the nominal radius for moderate profiles, and for **narrow / fine-pitch
    ///   profiles (e.g. ISO thread V-forms) it balloons severely (≈2× radius) and is unusable**.
    ///   Use this for coarse worm/auger-style ribs, not precise fastener threads. A future
    ///   analytic-helicoid path will give an exact thread flank — see the thread-helicoid
    ///   tracking issue. (This is why `threadedShaft`/`threadedHole` do **not** use it.)
    ///
    /// Profiles are positioned at their stations on the helix, in the (radial, axis) plane.
    /// One profile gives a uniform thread; two or more give a varying section (e.g. a
    /// runout that ramps from full crest to a small rib — the original #180 motivation).
    ///
    /// - Parameters:
    ///   - profiles: Rib profile wires positioned along the helix (at least one).
    ///   - axisOrigin: A point on the worm axis (the helix base).
    ///   - axisDirection: The worm axis direction.
    ///   - radius: Helix (pitch) radius.
    ///   - pitch: Axial advance per turn.
    ///   - turns: Number of turns.
    ///   - clockwise: Helix handedness.
    ///   - solid: If true, create a solid; if false, a shell.
    /// - Returns: The swept helicoid, or nil on failure.
    public static func helicalSweep(profiles: [Wire],
                                    axisOrigin: SIMD3<Double>,
                                    axisDirection: SIMD3<Double>,
                                    radius: Double,
                                    pitch: Double,
                                    turns: Double,
                                    clockwise: Bool = false,
                                    solid: Bool = true) -> Shape? {
        guard !profiles.isEmpty, radius > 0, pitch > 0, turns > 0 else { return nil }
        let axis = simd_normalize(axisDirection)
        guard let helix = Wire.helix(origin: axisOrigin, axis: axis, radius: radius,
                                     pitch: pitch, turns: turns, clockwise: clockwise) else {
            return nil
        }
        // Auxiliary spine = the central axis, spanning the helix's full axial extent in
        // BOTH directions (the helix runs +axis or −axis depending on handedness), so every
        // section plane intersects it. A short/one-sided aux line is the usual cause of a
        // nil auxiliary-spine sweep (#185).
        let span = pitch * turns + max(pitch, radius)
        guard let aux = Wire.line(from: axisOrigin - span * axis,
                                  to: axisOrigin + span * axis) else { return nil }
        return pipeShellMultiSection(spine: helix, profiles: profiles,
                                     mode: .auxiliary(spine: aux), solid: solid)
    }

    /// Single-profile helical sweep — a uniform worm/screw-thread helicoid.
    /// See ``helicalSweep(profiles:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)``.
    public static func helicalSweep(profile: Wire,
                                    axisOrigin: SIMD3<Double>,
                                    axisDirection: SIMD3<Double>,
                                    radius: Double,
                                    pitch: Double,
                                    turns: Double,
                                    clockwise: Bool = false,
                                    solid: Bool = true) -> Shape? {
        helicalSweep(profiles: [profile], axisOrigin: axisOrigin, axisDirection: axisDirection,
                     radius: radius, pitch: pitch, turns: turns, clockwise: clockwise, solid: solid)
    }

    // MARK: - Surface Creation (v0.9.0)

    /// Create a B-spline surface from a grid of control points.
    ///
    /// The surface interpolates approximately through the control point grid.
    /// Control points are specified in row-major order (U varies fastest).
    ///
    /// - Parameters:
    ///   - poles: 2D array of control points [uIndex][vIndex]
    ///   - uDegree: Degree in U direction (default 3 for cubic)
    ///   - vDegree: Degree in V direction (default 3 for cubic)
    /// - Returns: A face shape from the B-spline surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a 4x4 control point grid for a curved surface
    /// let poles: [[SIMD3<Double>]] = [
    ///     [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
    ///     [SIMD3(10, 0, 2), SIMD3(10, 10, 2), SIMD3(10, 20, 2), SIMD3(10, 30, 2)],
    ///     [SIMD3(20, 0, 2), SIMD3(20, 10, 2), SIMD3(20, 20, 2), SIMD3(20, 30, 2)],
    ///     [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)]
    /// ]
    /// let surface = Shape.surface(poles: poles)
    /// ```
    public static func surface(
        poles: [[SIMD3<Double>]],
        uDegree: Int = 3,
        vDegree: Int = 3
    ) -> Shape? {
        guard !poles.isEmpty, let firstRow = poles.first, !firstRow.isEmpty else { return nil }

        let uCount = poles.count
        let vCount = firstRow.count

        // Verify all rows have the same count
        for row in poles {
            guard row.count == vCount else { return nil }
        }

        guard uCount >= uDegree + 1, vCount >= vDegree + 1 else { return nil }

        // Flatten to array of doubles in row-major order
        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(uCount * vCount * 3)

        for row in poles {
            for point in row {
                flatPoles.append(point.x)
                flatPoles.append(point.y)
                flatPoles.append(point.z)
            }
        }

        return flatPoles.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeCreateBSplineSurface(
                buffer.baseAddress,
                Int32(uCount),
                Int32(vCount),
                Int32(uDegree),
                Int32(vDegree)
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// Create a ruled surface between two wires.
    ///
    /// A ruled surface is created by connecting corresponding points on two
    /// boundary curves with straight lines. The result is a smooth surface
    /// that linearly interpolates between the two profiles.
    ///
    /// - Parameters:
    ///   - profile1: First boundary wire
    ///   - profile2: Second boundary wire
    /// - Returns: A shell shape containing the ruled surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a cone-like surface between two circles
    /// let bottom = Wire.circle(radius: 10)!
    /// let top = Wire.circle(radius: 5)!.offset3D(distance: 20, direction: SIMD3(0, 0, 1))!
    /// let cone = Shape.ruled(profile1: bottom, profile2: top)
    /// ```
    public static func ruled(profile1: Wire, profile2: Wire) -> Shape? {
        guard let result = OCCTShapeCreateRuled(profile1.handle, profile2.handle) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a shell (hollow solid) with specific faces left open.
    ///
    /// Unlike the basic `shelled(thickness:)` method, this allows you to specify
    /// which faces should be removed to create openings.
    ///
    /// - Parameters:
    ///   - thickness: Wall thickness (positive = inward, negative = outward)
    ///   - openFaces: Faces to leave open (must have valid indices from this shape)
    /// - Returns: Shelled shape with specified faces open, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a box with an open top
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let topFaces = box.upwardFaces()
    /// let openBox = box.shelled(thickness: 2.0, openFaces: topFaces)
    /// ```
    public func shelled(thickness: Double, openFaces: [Face]) -> Shape? {
        guard !openFaces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(openFaces.count)
        for face in openFaces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeShellWithOpenFaces(
                handle,
                thickness,
                buffer.baseAddress,
                Int32(indices.count)
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }
}

// MARK: - Shape Healing & Analysis (v0.13.0)

/// Result of shape analysis, containing counts of various problems found.
public struct ShapeAnalysisResult {
    /// Number of edges smaller than tolerance
    public let smallEdgeCount: Int

    /// Number of faces smaller than tolerance
    public let smallFaceCount: Int

    /// Number of gaps between edges/faces
    public let gapCount: Int

    /// Number of self-intersections detected
    public let selfIntersectionCount: Int

    /// Number of free (unconnected) edges
    public let freeEdgeCount: Int

    /// Number of free faces (shell not closed)
    public let freeFaceCount: Int

    /// Whether the topology is invalid
    public let hasInvalidTopology: Bool

    /// Total number of problems found
    public var totalProblems: Int {
        smallEdgeCount + smallFaceCount + gapCount + selfIntersectionCount + freeEdgeCount + freeFaceCount + (hasInvalidTopology ? 1 : 0)
    }

    /// Whether the shape appears to be healthy (no problems found)
    public var isHealthy: Bool {
        totalProblems == 0 && !hasInvalidTopology
    }
}

extension Shape {

    // MARK: - Shape Analysis (v0.13.0)

    /// Analyze a shape for problems such as small edges, gaps, and invalid topology.
    ///
    /// - Parameter tolerance: Size threshold for detecting small features
    /// - Returns: Analysis result with problem counts, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shape = Shape.load(from: stepURL)!
    /// if let analysis = shape.analyze(tolerance: 0.001) {
    ///     print("Found \(analysis.totalProblems) problems")
    ///     if analysis.hasInvalidTopology {
    ///         print("Shape has invalid topology!")
    ///     }
    /// }
    /// ```
    public func analyze(tolerance: Double = 1e-6) -> ShapeAnalysisResult? {
        let result = OCCTShapeAnalyze(handle, tolerance)
        guard result.isValid else { return nil }

        return ShapeAnalysisResult(
            smallEdgeCount: Int(result.smallEdgeCount),
            smallFaceCount: Int(result.smallFaceCount),
            gapCount: Int(result.gapCount),
            selfIntersectionCount: Int(result.selfIntersectionCount),
            freeEdgeCount: Int(result.freeEdgeCount),
            freeFaceCount: Int(result.freeFaceCount),
            hasInvalidTopology: result.hasInvalidTopology
        )
    }

    // MARK: - Shape Fixing (v0.13.0)

    /// Fix shape problems with detailed control over what to fix.
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for fixing operations
    ///   - fixSolid: Whether to fix solid orientation
    ///   - fixShell: Whether to fix shell closure
    ///   - fixFace: Whether to fix face issues
    ///   - fixWire: Whether to fix wire issues
    /// - Returns: Fixed shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix only wire and face issues, not solid
    /// let fixed = shape.fixed(tolerance: 0.001, fixSolid: false)
    /// ```
    public func fixed(tolerance: Double = 1e-6,
                      fixSolid: Bool = true,
                      fixShell: Bool = true,
                      fixFace: Bool = true,
                      fixWire: Bool = true) -> Shape? {
        guard let result = OCCTShapeFixDetailed(handle, tolerance, fixSolid, fixShell, fixFace, fixWire) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Shape Unification (v0.13.0)

    /// Unify faces and edges lying on the same geometry.
    ///
    /// After boolean operations, shapes often have unnecessary internal subdivisions.
    /// This method merges faces that share the same underlying surface and edges
    /// that share the same underlying curve.
    ///
    /// - Parameters:
    ///   - unifyEdges: Whether to merge edges on same curve (default: true)
    ///   - unifyFaces: Whether to merge faces on same surface (default: true)
    ///   - concatBSplines: Whether to concatenate adjacent B-splines (default: true)
    /// - Returns: Unified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // After subtracting multiple cylinders, unify to simplify topology
    /// let result = box - cyl1 - cyl2 - cyl3
    /// let clean = result.unified()
    /// print("Faces reduced from \(result.faceCount) to \(clean.faceCount)")
    /// ```
    public func unified(unifyEdges: Bool = true,
                        unifyFaces: Bool = true,
                        concatBSplines: Bool = true) -> Shape? {
        guard let result = OCCTShapeUnifySameDomain(handle, unifyEdges, unifyFaces, concatBSplines) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Remove faces smaller than the specified area threshold.
    ///
    /// Useful for cleaning up shapes with very small faces that can cause
    /// problems in downstream operations.
    ///
    /// - Parameter minArea: Minimum area threshold; faces smaller than this are removed
    /// - Returns: Cleaned shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Remove faces smaller than 0.01 mm²
    /// let cleaned = shape.withoutSmallFaces(minArea: 0.01)
    /// ```
    public func withoutSmallFaces(minArea: Double) -> Shape? {
        guard let result = OCCTShapeRemoveSmallFaces(handle, minArea) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Simplify a shape by unifying same-domain geometry and healing.
    ///
    /// This is a convenience method that combines `unified()` and `healed()`.
    ///
    /// - Parameter tolerance: Tolerance for simplification operations
    /// - Returns: Simplified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clean up a complex boolean result
    /// let simplified = result.simplified(tolerance: 0.001)
    /// ```
    public func simplified(tolerance: Double = 1e-6) -> Shape? {
        guard let result = OCCTShapeSimplify(handle, tolerance) else {
            return nil
        }
        return Shape(handle: result)
    }
}

extension Wire {

    // MARK: - Wire Fixing (v0.13.0)

    /// Fix wire problems such as gaps, degenerate edges, and incorrect ordering.
    ///
    /// - Parameter tolerance: Tolerance for fixing operations
    /// - Returns: Fixed wire, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix a wire with small gaps between edges
    /// let fixedWire = problematicWire.fixed(tolerance: 0.001)
    /// ```
    public func fixed(tolerance: Double = 1e-6) -> Wire? {
        guard let result = OCCTWireFix(handle, tolerance) else {
            return nil
        }
        return Wire(handle: result)
    }
}

extension Face {

    // MARK: - Face Fixing (v0.13.0)

    /// Fix face problems such as incorrect wire orientation, missing seams, and surface parameters.
    ///
    /// - Parameter tolerance: Tolerance for fixing operations
    /// - Returns: Fixed face as a shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix a face with wire orientation issues
    /// let fixedShape = problematicFace.fixed(tolerance: 0.001)
    /// ```
    public func fixed(tolerance: Double = 1e-6) -> Shape? {
        guard let result = OCCTFaceFix(handle, tolerance) else {
            return nil
        }
        return Shape(handle: result)
    }
}

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

/// Continuity specification for surface filling operations
public enum SurfaceContinuity: Int32 {
    /// Positional continuity (surfaces touch)
    case c0 = 0
    /// Tangent continuity (smooth transition)
    case g1 = 1
    /// Curvature continuity (very smooth)
    case g2 = 2
}

/// Constraint order for advanced plate surface construction (v0.23.0)
public enum PlateConstraintOrder: Int32 {
    /// Position only — surface must pass through the point
    case g0 = 0
    /// Position + tangent — surface must be tangent-continuous
    case g1 = 1
    /// Position + tangent + curvature — surface must be curvature-continuous
    case g2 = 2
}

/// Parameters for surface filling operations
public struct FillingParameters {
    /// Surface continuity at boundaries
    public var continuity: SurfaceContinuity
    /// Surface tolerance
    public var tolerance: Double
    /// Maximum surface degree
    public var maxDegree: Int
    /// Maximum number of segments
    public var maxSegments: Int

    /// Create filling parameters with defaults
    public init(
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 1e-4,
        maxDegree: Int = 8,
        maxSegments: Int = 9
    ) {
        self.continuity = continuity
        self.tolerance = tolerance
        self.maxDegree = maxDegree
        self.maxSegments = maxSegments
    }

    internal var cParams: OCCTFillingParams {
        OCCTFillingParams(
            continuity: continuity.rawValue,
            tolerance: tolerance,
            maxDegree: Int32(maxDegree),
            maxSegments: Int32(maxSegments)
        )
    }
}

extension Shape {
    // MARK: - Variable Radius Fillet (v0.14.0)

    /// Apply a variable radius fillet to a specific edge.
    ///
    /// The radius varies along the edge according to the given radius/parameter pairs.
    /// Parameters are normalized from 0.0 (start of edge) to 1.0 (end of edge).
    ///
    /// - Parameters:
    ///   - edgeIndex: Index of the edge to fillet
    ///   - radiusProfile: Array of (parameter, radius) pairs defining the radius along the edge
    /// - Returns: Filleted shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fillet with radius varying from 1mm at start to 3mm at end
    /// let filleted = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
    /// )
    ///
    /// // Fillet with radius varying: 1mm at start, 2mm at middle, 1mm at end
    /// let complexFillet = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (0.5, 2.0), (1.0, 1.0)]
    /// )
    /// ```
    public func filletedVariable(
        edgeIndex: Int,
        radiusProfile: [(parameter: Double, radius: Double)]
    ) -> Shape? {
        guard radiusProfile.count >= 2 else { return nil }

        var radii = radiusProfile.map { $0.radius }
        var params = radiusProfile.map { $0.parameter }

        guard let result = OCCTShapeFilletVariable(
            handle,
            Int32(edgeIndex),
            &radii,
            &params,
            Int32(radii.count)
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Multi-Edge Blend (v0.14.0)

    /// Apply fillets to multiple edges with individual radii.
    ///
    /// Each edge can have its own fillet radius, allowing for more control
    /// than applying a uniform fillet to all edges.
    ///
    /// - Parameter edgeRadii: Array of (edgeIndex, radius) pairs
    /// - Returns: Filleted shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Apply different radii to different edges
    /// let blended = shape.blendedEdges([
    ///     (0, 1.0),  // Edge 0 gets 1mm fillet
    ///     (1, 2.0),  // Edge 1 gets 2mm fillet
    ///     (2, 0.5)   // Edge 2 gets 0.5mm fillet
    /// ])
    /// ```
    public func blendedEdges(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> Shape? {
        guard !edgeRadii.isEmpty else { return nil }

        var indices = edgeRadii.map { Int32($0.edgeIndex) }
        var radii = edgeRadii.map { $0.radius }

        guard let result = OCCTShapeBlendEdges(
            handle,
            &indices,
            &radii,
            Int32(edgeRadii.count)
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Surface Filling (v0.14.0)

    /// Fill an N-sided boundary with a smooth surface.
    ///
    /// Creates a surface that passes through the given boundary wires
    /// with the specified continuity.
    ///
    /// - Parameters:
    ///   - boundaries: Array of wires defining the boundary
    ///   - parameters: Filling parameters (continuity, tolerance, etc.)
    /// - Returns: Face shape covering the boundary, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fill a 4-sided boundary with a smooth surface
    /// let wire1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
    /// let wire2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5))
    /// let wire3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 3))
    /// let wire4 = Wire.line(from: SIMD3(0, 10, 3), to: SIMD3(0, 0, 0))
    ///
    /// let surface = Shape.fill(
    ///     boundaries: [wire1, wire2, wire3, wire4],
    ///     parameters: FillingParameters(continuity: .g1)
    /// )
    /// ```
    public static func fill(
        boundaries: [Wire],
        parameters: FillingParameters = FillingParameters()
    ) -> Shape? {
        guard !boundaries.isEmpty else { return nil }

        var handles = boundaries.map { $0.handle as OCCTWireRef? }

        guard let result = handles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeFill(buffer.baseAddress, Int32(boundaries.count), parameters.cParams)
        }) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Plate Surfaces (v0.14.0)

    /// Create a surface constrained to pass through specific points.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that interpolates through all given points.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must pass through
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface through scattered points
    /// let surface = Shape.plateSurface(
    ///     through: [
    ///         SIMD3(0, 0, 0),
    ///         SIMD3(10, 0, 1),
    ///         SIMD3(10, 10, 2),
    ///         SIMD3(0, 10, 1),
    ///         SIMD3(5, 5, 3)  // Point in middle raises surface
    ///     ],
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        through points: [SIMD3<Double>],
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3 else { return nil }

        var flatPoints: [Double] = []
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        guard let result = OCCTShapePlatePoints(
            &flatPoints,
            Int32(points.count),
            tolerance
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a surface constrained by boundary curves.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that follows the given boundary curves with specified continuity.
    ///
    /// - Parameters:
    ///   - curves: Array of wires defining boundary constraints
    ///   - continuity: Continuity requirement at boundaries
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface bounded by curves
    /// let curve1 = Wire.bspline([...])
    /// let curve2 = Wire.bspline([...])
    ///
    /// let surface = Shape.plateSurface(
    ///     constrainedBy: [curve1, curve2],
    ///     continuity: .g1,
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        constrainedBy curves: [Wire],
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !curves.isEmpty else { return nil }

        var handles = curves.map { $0.handle as OCCTWireRef? }

        guard let result = handles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapePlateCurves(
                buffer.baseAddress,
                Int32(curves.count),
                continuity.rawValue,
                tolerance
            )
        }) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface through points with specified constraint orders per point.
    ///
    /// Each point can independently specify G0 (position only), G1 (position + tangent),
    /// or G2 (position + tangent + curvature) continuity.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must satisfy
    ///   - orders: Constraint order per point (`.g0`, `.g1`, or `.g2`)
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - pointsOnCurves: Number of sample points on curves (default 15)
    ///   - iterations: Number of solver iterations (default 2)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        through points: [SIMD3<Double>],
        orders: [PlateConstraintOrder],
        degree: Int = 3,
        pointsOnCurves: Int = 15,
        iterations: Int = 2,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3, points.count == orders.count else { return nil }

        var flatPoints: [Double] = []
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }
        var rawOrders = orders.map { Int32($0.rawValue) }

        guard let result = OCCTShapePlatePointsAdvanced(
            &flatPoints, Int32(points.count),
            &rawOrders, Int32(degree),
            Int32(pointsOnCurves), Int32(iterations),
            tolerance
        ) else { return nil }
        return Shape(handle: result)
    }

    /// Create a plate surface with mixed point and curve constraints.
    ///
    /// Combines point constraints (each with its own continuity order) and
    /// curve constraints (wires with continuity orders) into a single plate surface.
    ///
    /// - Parameters:
    ///   - points: Point constraints with positions and orders
    ///   - curves: Curve constraints with wires and orders
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        pointConstraints points: [(point: SIMD3<Double>, order: PlateConstraintOrder)],
        curveConstraints curves: [(wire: Wire, order: PlateConstraintOrder)],
        degree: Int = 3,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !points.isEmpty || !curves.isEmpty else { return nil }

        var flatPoints: [Double] = []
        var pointOrders: [Int32] = []
        for (p, order) in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
            pointOrders.append(Int32(order.rawValue))
        }

        var wireHandles = curves.map { $0.wire.handle as OCCTWireRef? }
        var curveOrders = curves.map { Int32($0.order.rawValue) }

        let result: OCCTShapeRef? = flatPoints.withUnsafeMutableBufferPointer { ptBuf in
            pointOrders.withUnsafeMutableBufferPointer { ordBuf in
                wireHandles.withUnsafeMutableBufferPointer { wireBuf in
                    curveOrders.withUnsafeMutableBufferPointer { coBuf in
                        OCCTShapePlateMixed(
                            points.isEmpty ? nil : ptBuf.baseAddress,
                            points.isEmpty ? nil : ordBuf.baseAddress,
                            Int32(points.count),
                            curves.isEmpty ? nil : wireBuf.baseAddress,
                            curves.isEmpty ? nil : coBuf.baseAddress,
                            Int32(curves.count),
                            Int32(degree), tolerance
                        )
                    }
                }
            }
        }
        guard let result else { return nil }
        return Shape(handle: result)
    }
}

// MARK: - Advanced Healing (v0.17.0)

/// Target geometric continuity for shape divide operations
public enum GeometricContinuity: Int32, Sendable {
    case c0 = 0
    case c1 = 1
    case c2 = 2
    case c3 = 3
}

extension Shape {

    /// Divide a shape at continuity discontinuities
    ///
    /// - Parameter continuity: Target continuity level
    /// - Returns: Divided shape, or nil on failure
    public func divided(at continuity: GeometricContinuity) -> Shape? {
        guard let handle = OCCTShapeDivide(self.handle, continuity.rawValue) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert geometry to direct faces (canonical surfaces)
    ///
    /// - Returns: Shape with canonical surfaces, or nil on failure
    public func directFaces() -> Shape? {
        guard let handle = OCCTShapeDirectFaces(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Scale shape geometry by a factor
    ///
    /// Unlike `scaled(by:)` which applies a geometric transform, this modifies the
    /// underlying surface and curve definitions.
    ///
    /// - Parameter factor: Scale factor
    /// - Returns: Scaled shape, or nil on failure
    public func scaledGeometry(factor: Double) -> Shape? {
        guard let handle = OCCTShapeScaleGeometry(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert BSpline surfaces to their closest analytical form
    ///
    /// Attempts to convert BSpline surfaces to planes, cylinders, cones, spheres, or tori.
    ///
    /// - Parameters:
    ///   - surfaceTolerance: Tolerance for surface approximation (default: 0.01)
    ///   - curveTolerance: Tolerance for curve approximation (default: 0.01)
    ///   - maxDegree: Maximum degree for BSpline restriction (default: 9)
    ///   - maxSegments: Maximum number of segments (default: 10000)
    /// - Returns: Shape with restricted BSplines, or nil on failure
    public func bsplineRestriction(surfaceTolerance: Double = 0.01,
                                   curveTolerance: Double = 0.01,
                                   maxDegree: Int = 9,
                                   maxSegments: Int = 10000) -> Shape? {
        guard let handle = OCCTShapeBSplineRestriction(self.handle, surfaceTolerance, curveTolerance,
                                                        Int32(maxDegree), Int32(maxSegments)) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert swept surfaces to elementary (canonical) surfaces
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func sweptToElementary() -> Shape? {
        guard let handle = OCCTShapeSweptToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert surfaces of revolution to elementary surfaces
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func revolutionToElementary() -> Shape? {
        guard let handle = OCCTShapeRevolutionToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert all surfaces to BSpline
    ///
    /// - Returns: Shape with BSpline surfaces, or nil on failure
    public func convertedToBSpline() -> Shape? {
        guard let handle = OCCTShapeConvertToBSpline(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Sew disconnected faces in this shape together
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewSingle(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }

    /// Upgrade shape: sew + make solid + heal pipeline
    ///
    /// Performs a complete upgrade of the shape by sewing disconnected faces,
    /// attempting to create a solid from shells, and applying shape healing.
    ///
    /// - Parameter tolerance: Tolerance for sewing and healing (default: 1e-6)
    /// - Returns: Upgraded shape, or nil on failure
    public func upgraded(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeUpgrade(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }
}

// MARK: - Point Classification (v0.17.0)

/// Classification of a point relative to a shape
public enum PointClassification: Int32, Sendable {
    /// Point is inside the shape
    case inside = 0      // TopAbs_IN
    /// Point is outside the shape
    case outside = 1     // TopAbs_OUT
    /// Point is on the boundary of the shape
    case onBoundary = 2  // TopAbs_ON
    /// Classification could not be determined
    case unknown = 3     // TopAbs_UNKNOWN
}

extension Shape {

    /// Classify a point relative to this solid
    ///
    /// Determines whether a 3D point is inside, outside, or on the boundary of
    /// this shape. The shape should be a solid for reliable results.
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointInSolid(handle, point.x, point.y, point.z, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }
}

extension Face {

    /// Classify a point relative to this face using a 3D point
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointOnFace(handle, point.x, point.y, point.z, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }

    /// Classify a point relative to this face using UV parameters
    ///
    /// - Parameters:
    ///   - u: U parameter on the face surface
    ///   - v: V parameter on the face surface
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(u: Double, v: Double, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointOnFaceUV(handle, u, v, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }
}


// MARK: - Shape Proximity (v0.18.0)

extension Shape {

    /// A pair of face indices detected as near-miss (within tolerance)
    public struct FaceProximityPair: Sendable {
        public let face1Index: Int
        public let face2Index: Int
    }

    /// Detect face pairs between this shape and another that are within tolerance.
    /// - Parameter deflection: Linear mesh deflection (mm) for the proximity triangulation. Default `0.1`.
    public func proximityFaces(with other: Shape, tolerance: Double, deflection: Double = 0.1) -> [FaceProximityPair] {
        var buffer = [OCCTFaceProximityPair](repeating: OCCTFaceProximityPair(), count: 256)
        let count = OCCTShapeProximity(handle, other.handle, tolerance, &buffer, 256, deflection)

        var pairs = [FaceProximityPair]()
        for i in 0..<Int(count) {
            pairs.append(FaceProximityPair(
                face1Index: Int(buffer[i].face1Index),
                face2Index: Int(buffer[i].face2Index)
            ))
        }
        return pairs
    }

    /// Check if this shape self-intersects
    public var selfIntersects: Bool {
        OCCTShapeSelfIntersects(handle)
    }
}

// MARK: - Wedge Primitive (v0.29.0)

extension Shape {
    /// Create a wedge (tapered box).
    ///
    /// A wedge is a box whose top face is narrowed in the X direction.
    /// When `ltx` equals `dx`, the result is a regular box.
    /// When `ltx` is 0, the result is a pyramid.
    ///
    /// - Parameters:
    ///   - dx: Width in X
    ///   - dy: Height in Y
    ///   - dz: Depth in Z
    ///   - ltx: Width of top face in X (0 to dx)
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(dx: Double, dy: Double, dz: Double, ltx: Double) -> Shape? {
        guard dx > 0, dy > 0, dz > 0, ltx >= 0 else { return nil }
        guard let h = OCCTShapeCreateWedge(dx, dy, dz, ltx) else { return nil }
        return Shape(handle: h)
    }

    /// Create an advanced wedge with custom top face bounds.
    ///
    /// - Parameters:
    ///   - dx, dy, dz: Box dimensions
    ///   - xmin, zmin, xmax, zmax: Top face bounds within the box
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(dx: Double, dy: Double, dz: Double,
                             xmin: Double, zmin: Double,
                             xmax: Double, zmax: Double) -> Shape? {
        guard dx > 0, dy > 0, dz > 0 else { return nil }
        guard let h = OCCTShapeCreateWedgeAdvanced(dx, dy, dz, xmin, zmin, xmax, zmax)
        else { return nil }
        return Shape(handle: h)
    }
    /// Create an oriented wedge at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Corner point of the wedge.
    ///   - direction: Axis direction for the wedge height (will be normalized).
    ///   - dx: Width in X (local frame).
    ///   - dy: Height in Y (local frame).
    ///   - dz: Depth in Z (local frame).
    ///   - ltx: Width of top face in X (0 to dx).
    public static func wedge(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        dx: Double, dy: Double, dz: Double,
        ltx: Double
    ) -> Shape? {
        guard let h = OCCTShapeCreateWedgeOriented(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            dx, dy, dz, ltx
        ) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - NURBS Conversion (v0.29.0)

extension Shape {
    /// Convert all curves and surfaces to NURBS representation.
    ///
    /// Useful for ensuring uniform representation before export
    /// or for algorithms that require NURBS geometry.
    ///
    /// - Returns: A new shape with all geometry converted to NURBS, or nil on failure
    public func convertedToNURBS() -> Shape? {
        guard let h = OCCTShapeConvertToNURBS(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fast Sewing (v0.29.0)

extension Shape {
    /// Sew faces using the fast sewing algorithm.
    ///
    /// Faster than `sewn(tolerance:)` for large models, but may handle
    /// fewer edge cases.
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: The sewn shape, or nil on failure
    public func fastSewn(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeFastSewn(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Normal Projection (v0.29.0)

extension Shape {
    /// Project a wire or edge onto this shape along surface normals.
    ///
    /// - Parameters:
    ///   - wireOrEdge: The wire or edge to project
    ///   - tolerance3D: 3D tolerance (default: 1e-4)
    ///   - tolerance2D: 2D tolerance (default: 1e-5)
    ///   - maxDegree: Maximum BSpline degree (default: 14)
    ///   - maxSegments: Maximum BSpline segments (default: 16)
    /// - Returns: The projected shape, or nil on failure
    public func normalProjection(of wireOrEdge: Shape,
                                  tolerance3D: Double = 1e-4,
                                  tolerance2D: Double = 1e-5,
                                  maxDegree: Int = 14,
                                  maxSegments: Int = 16) -> Shape? {
        guard let h = OCCTShapeNormalProjection(wireOrEdge.handle, handle,
                                                 tolerance3D, tolerance2D,
                                                 Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Half-Space (v0.29.0)

extension Shape {
    /// Create a half-space solid from a face.
    ///
    /// A half-space is an infinite solid on one side of a face.
    /// The reference point indicates which side is solid.
    ///
    /// - Parameters:
    ///   - face: A shape containing the dividing face
    ///   - referencePoint: A point on the solid side
    /// - Returns: A half-space solid, or nil on failure
    public static func halfSpace(face: Shape, referencePoint: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateHalfSpace(face.handle,
                                                referencePoint.x, referencePoint.y, referencePoint.z)
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Sub-Shape Replacement (v0.29.0)

extension Shape {
    /// Replace a sub-shape within this shape.
    ///
    /// - Parameters:
    ///   - oldSubShape: The sub-shape to replace
    ///   - newSubShape: The replacement sub-shape
    /// - Returns: The modified shape, or nil on failure
    public func replacingSubShape(_ oldSubShape: Shape, with newSubShape: Shape) -> Shape? {
        guard let h = OCCTShapeReplaceSubShape(handle, oldSubShape.handle, newSubShape.handle)
        else { return nil }
        return Shape(handle: h)
    }

    /// Remove a sub-shape from this shape.
    ///
    /// - Parameter subShape: The sub-shape to remove
    /// - Returns: The modified shape, or nil on failure
    public func removingSubShape(_ subShape: Shape) -> Shape? {
        guard let h = OCCTShapeRemoveSubShape(handle, subShape.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Periodic Shapes (v0.29.0)

extension Shape {
    /// Make this shape periodic in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = not periodic in X)
    ///   - yPeriod: Period in Y (nil = not periodic in Y)
    ///   - zPeriod: Period in Z (nil = not periodic in Z)
    /// - Returns: A periodic shape, or nil on failure
    public func makePeriodic(xPeriod: Double? = nil,
                              yPeriod: Double? = nil,
                              zPeriod: Double? = nil) -> Shape? {
        guard let h = OCCTShapeMakePeriodic(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Repeat this shape periodically in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = no repetition in X)
    ///   - yPeriod: Period in Y (nil = no repetition in Y)
    ///   - zPeriod: Period in Z (nil = no repetition in Z)
    ///   - xCount: Number of repetitions in X
    ///   - yCount: Number of repetitions in Y
    ///   - zCount: Number of repetitions in Z
    /// - Returns: The repeated shape, or nil on failure
    public func repeated(xPeriod: Double? = nil, xCount: Int = 0,
                          yPeriod: Double? = nil, yCount: Int = 0,
                          zPeriod: Double? = nil, zCount: Int = 0) -> Shape? {
        guard let h = OCCTShapeRepeat(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0,
            Int32(xCount), Int32(yCount), Int32(zCount)
        ) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Draft from Shape (v0.29.0)

extension Shape {
    /// Create a draft shell by sweeping this shape along a direction with taper angle.
    ///
    /// - Parameters:
    ///   - direction: Draft direction
    ///   - angle: Taper angle in radians
    ///   - length: Maximum draft length
    /// - Returns: A draft shell shape, or nil on failure
    public func draft(direction: SIMD3<Double>, angle: Double, length: Double) -> Shape? {
        guard let h = OCCTShapeMakeDraft(handle,
                                          direction.x, direction.y, direction.z,
                                          angle, length)
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Non-Uniform Scale (v0.30.0)

extension Shape {
    /// Scale this shape non-uniformly along each axis.
    ///
    /// Unlike `scaled(by:)` which applies uniform scaling, this allows
    /// different scale factors for X, Y, and Z axes.
    ///
    /// - Parameters:
    ///   - sx: Scale factor along X axis
    ///   - sy: Scale factor along Y axis
    ///   - sz: Scale factor along Z axis
    /// - Returns: The scaled shape, or nil on failure
    public func nonUniformScaled(sx: Double, sy: Double, sz: Double) -> Shape? {
        guard let h = OCCTShapeNonUniformScale(handle, sx, sy, sz) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shell & Vertex Creation (v0.30.0)

extension Shape {
    /// Create a shell from a parametric surface.
    ///
    /// Converts a `Surface` to a topological shell shape.
    ///
    /// - Parameter surface: The parametric surface to convert
    /// - Returns: A shell shape, or nil on failure
    public static func shell(from surface: Surface) -> Shape? {
        guard let h = OCCTShapeCreateShellFromSurface(surface.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a vertex shape at a point.
    ///
    /// - Parameter point: The 3D point position
    /// - Returns: A vertex shape
    public static func vertex(at point: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Simple Offset (v0.30.0)

extension Shape {
    /// Create a simple surface-level offset of this shape.
    ///
    /// Moves each face by a constant distance without filleting intersections.
    /// Faster than `offset(by:)` for thin-wall operations.
    ///
    /// - Parameter distance: Offset distance (positive = outward)
    /// - Returns: The offset shape, or nil on failure
    public func simpleOffset(by distance: Double) -> Shape? {
        guard let h = OCCTShapeSimpleOffset(handle, distance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Middle Path (v0.30.0)

extension Shape {
    /// Extract the middle (spine) path from a pipe-like shape.
    ///
    /// Given two end faces/wires of a pipe-like shape, computes the
    /// spine wire running through the middle. Useful for reverse-engineering
    /// sweep operations from imported geometry.
    ///
    /// - Parameters:
    ///   - startShape: One end of the pipe (face or wire)
    ///   - endShape: Other end of the pipe (face or wire)
    /// - Returns: The middle path wire, or nil on failure
    public func middlePath(start startShape: Shape, end endShape: Shape) -> Shape? {
        guard let h = OCCTShapeMiddlePath(handle, startShape.handle, endShape.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fuse Edges (v0.30.0)

extension Shape {
    /// Merge connected edges that lie on the same curve.
    ///
    /// Removes unnecessary edge splits introduced by boolean operations
    /// or other operations, simplifying the topology.
    ///
    /// - Returns: Shape with fused edges, or nil on failure
    public func fusedEdges() -> Shape? {
        guard let h = OCCTShapeFuseEdges(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Volume from Faces (v0.30.0)

extension Shape {
    /// Create a solid volume from a set of overlapping faces/shells.
    ///
    /// Useful for closing open geometry or creating solids from imported face soups.
    ///
    /// - Parameter shapes: Array of face/shell shapes
    /// - Returns: A solid shape, or nil on failure
    public static func makeVolume(from shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeVolume(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }

    /// Connect separate shapes by making them share common geometry.
    ///
    /// Makes shapes share geometry at coincident boundaries.
    /// Useful for finite element mesh preparation.
    ///
    /// - Parameter shapes: Array of shapes to connect
    /// - Returns: Connected shape, or nil on failure
    public static func makeConnected(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeConnected(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shape Contents (v0.30.0)

/// Census of sub-shape counts in a shape.
public struct ShapeContents: Sendable {
    public let solids: Int
    public let shells: Int
    public let faces: Int
    public let wires: Int
    public let edges: Int
    public let vertices: Int
    public let freeEdges: Int
    public let freeWires: Int
    public let freeFaces: Int
}

extension Shape {
    /// Get a census of sub-shape counts in this shape.
    ///
    /// Reports topology complexity metrics: counts of solids, shells,
    /// faces, wires, edges, vertices, and free (unconnected) elements.
    public var contents: ShapeContents {
        let c = OCCTShapeGetContents(handle)
        return ShapeContents(
            solids: Int(c.nbSolids), shells: Int(c.nbShells),
            faces: Int(c.nbFaces), wires: Int(c.nbWires),
            edges: Int(c.nbEdges), vertices: Int(c.nbVertices),
            freeEdges: Int(c.nbFreeEdges), freeWires: Int(c.nbFreeWires),
            freeFaces: Int(c.nbFreeFaces)
        )
    }
}

// MARK: - Canonical Recognition (v0.30.0)

/// Recognized canonical geometric form.
public struct CanonicalForm: Sendable {
    /// Type of the recognized form.
    public enum FormType: Int32, Sendable {
        case unknown = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    public let type: FormType
    public let origin: SIMD3<Double>
    public let direction: SIMD3<Double>
    public let radius: Double
    public let radius2: Double
    public let gap: Double
}

extension Shape {
    /// Recognize canonical geometric forms in this shape.
    ///
    /// Identifies whether the shape's geometry matches a canonical
    /// form (plane, cylinder, cone, sphere, line, circle, ellipse).
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The recognized form, or nil if no canonical form found
    public func recognizeCanonical(tolerance: Double = 1e-4) -> CanonicalForm? {
        let r = OCCTShapeRecognizeCanonical(handle, tolerance)
        guard let formType = CanonicalForm.FormType(rawValue: r.type), formType != .unknown else { return nil }
        return CanonicalForm(
            type: formType,
            origin: SIMD3(r.origin.0, r.origin.1, r.origin.2),
            direction: SIMD3(r.direction.0, r.direction.1, r.direction.2),
            radius: r.radius, radius2: r.radius2, gap: r.gap
        )
    }
}

// MARK: - Find Surface (v0.30.0)

extension Shape {
    /// Find the underlying surface of a shape (edges or wire).
    ///
    /// Determines the best-fit surface for a set of edges or a wire.
    /// Useful for reconstructing faces from imported wireframes.
    ///
    /// - Parameter tolerance: Surface fitting tolerance
    /// - Returns: The found surface, or nil
    public func findSurface(tolerance: Double = -1) -> Surface? {
        guard let h = OCCTShapeFindSurface(handle, tolerance) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Fix Wireframe (v0.30.0)

extension Shape {
    /// Fix wireframe issues (small edges, gaps).
    ///
    /// - Parameter tolerance: Fixing tolerance
    /// - Returns: Shape with fixed wireframe, or nil on failure
    public func fixedWireframe(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixWireframe(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Remove Internal Wires (v0.30.0)

extension Shape {
    /// Remove internal wires (holes) smaller than a minimum area.
    ///
    /// - Parameter minArea: Minimum area threshold for holes to keep
    /// - Returns: Shape with small holes removed, or nil on failure
    public func removingInternalWires(minArea: Double) -> Shape? {
        guard let h = OCCTShapeRemoveInternalWires(handle, minArea) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Contiguous Edges (v0.30.0)

extension Shape {
    /// Find pairs of edges that are coincident within tolerance.
    ///
    /// Useful for pre-sewing diagnostics to identify edges that
    /// could be merged.
    ///
    /// - Parameter tolerance: Contiguity tolerance
    /// - Returns: Number of contiguous edge pairs found
    public func contiguousEdgeCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFindContiguousEdges(handle, tolerance))
    }
}

// MARK: - Quilt Faces (v0.31.0)

extension Shape {
    /// Quilt multiple shapes (faces/shells) together into a single shell.
    ///
    /// Joins faces that share common edges into a connected shell.
    ///
    /// - Parameter shapes: Array of shapes to quilt together
    /// - Returns: Quilted shell, or nil on failure
    public static func quilt(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeQuilt(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fix Small Faces (v0.31.0)

extension Shape {
    /// Fix small faces by removing or merging them.
    ///
    /// - Parameter tolerance: Precision tolerance for identifying small faces
    /// - Returns: Shape with small faces fixed, or nil on failure
    public func fixingSmallFaces(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixSmallFaces(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Remove Locations (v0.31.0)

extension Shape {
    /// Remove all location transforms, baking them into the geometry.
    ///
    /// Converts a shape with nested transforms into an equivalent shape
    /// where all geometry coordinates are in the global frame.
    ///
    /// - Returns: Shape with locations removed, or nil on failure
    public func removingLocations() -> Shape? {
        guard let h = OCCTShapeRemoveLocations(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Revolution from Curve (v0.31.0)

extension Shape {
    /// Create a solid of revolution by revolving a meridian curve.
    ///
    /// Unlike `revolution(profile:...)` which takes a wire profile,
    /// this creates a revolution directly from a `Geom_Curve`.
    ///
    /// - Parameters:
    ///   - meridian: The curve to revolve
    ///   - axisOrigin: Origin point of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in radians (default: full revolution)
    /// - Returns: Revolved shape, or nil on failure
    public static func revolution(meridian: Curve3D,
                                  axisOrigin: SIMD3<Double> = .zero,
                                  axisDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
                                  angle: Double = 2 * .pi) -> Shape? {
        guard let h = OCCTShapeCreateRevolutionFromCurve(
            meridian.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Linear Rib Feature (v0.31.0)

extension Shape {
    /// Add a linear rib feature to a shape.
    ///
    /// Creates a rib (reinforcement) or slot by extruding a wire profile
    /// in the given direction on the base shape.
    ///
    /// - Parameters:
    ///   - profile: The wire profile of the rib
    ///   - direction: Extrusion direction of the rib
    ///   - draftDirection: Secondary direction controlling draft angle
    ///   - fuse: true to add material (rib), false to remove material (slot)
    /// - Returns: Shape with rib/slot added, or nil on failure
    public func addingLinearRib(profile: Wire,
                                direction: SIMD3<Double>,
                                draftDirection: SIMD3<Double>,
                                fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeAddLinearRib(
            handle, profile.handle,
            direction.x, direction.y, direction.z,
            draftDirection.x, draftDirection.y, draftDirection.z,
            fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Offset Join Type (v0.32.0)

/// Join type for offset operations.
public enum OffsetJoinType: Int32, Sendable {
    /// Arc — fill gaps with pipe arcs and spheres (smooth, rounded)
    case arc = 0
    /// Tangent — tangent extension of faces
    case tangent = 1
    /// Intersection — extend and intersect adjacent faces (sharp edges)
    case intersection = 2
}

// MARK: - Revolution Form Feature (v0.32.0)

extension Shape {
    /// Add a revolution form (revolved rib or groove) to a shape.
    ///
    /// Similar to `addingLinearRib`, but the rib follows a rotational
    /// path around the given axis.
    ///
    /// - Parameters:
    ///   - profile: Wire profile of the rib
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - height1: Height on one side
    ///   - height2: Height on the other side
    ///   - fuse: true for rib (add material), false for groove (remove material)
    /// - Returns: Shape with revolution form, or nil on failure
    public func addingRevolutionForm(profile: Wire,
                                     axisOrigin: SIMD3<Double>,
                                     axisDirection: SIMD3<Double>,
                                     height1: Double, height2: Double,
                                     fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeAddRevolutionForm(
            handle, profile.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            height1, height2, fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Draft Prism Feature (v0.32.0)

extension Shape {
    /// Add a draft prism (tapered extrusion) to a shape.
    ///
    /// Creates a boss or pocket with draft angle (taper), commonly used
    /// in injection mold design.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - height: Extrusion height
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrism(profile: Wire, sketchFaceIndex: Int,
                                 draftAngle: Double, height: Double,
                                 fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeDraftPrism(handle, Int32(sketchFaceIndex),
                                           profile.handle, draftAngle,
                                           height, fuse) else { return nil }
        return Shape(handle: h)
    }

    /// Add a draft prism that extends through the entire shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrismThruAll(profile: Wire, sketchFaceIndex: Int,
                                        draftAngle: Double,
                                        fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeDraftPrismThruAll(handle, Int32(sketchFaceIndex),
                                                  profile.handle, draftAngle,
                                                  fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Revolution Feature (v0.32.0)

extension Shape {
    /// Add a revolved feature (boss or pocket) to a shape.
    ///
    /// Revolves a profile around an axis to add or remove material.
    /// Commonly used for turned parts (lathe operations).
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in degrees
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeature(profile: Wire, sketchFaceIndex: Int,
                                      axisOrigin: SIMD3<Double>,
                                      axisDirection: SIMD3<Double>,
                                      angle: Double = 360,
                                      fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeRevolFeature(handle, Int32(sketchFaceIndex),
                                             profile.handle,
                                             axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                             axisDirection.x, axisDirection.y, axisDirection.z,
                                             angle, fuse) else { return nil }
        return Shape(handle: h)
    }

    /// Add a revolved feature that revolves through 360 degrees.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeatureThruAll(profile: Wire, sketchFaceIndex: Int,
                                             axisOrigin: SIMD3<Double>,
                                             axisDirection: SIMD3<Double>,
                                             fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeRevolFeatureThruAll(handle, Int32(sketchFaceIndex),
                                                    profile.handle,
                                                    axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                    axisDirection.x, axisDirection.y, axisDirection.z,
                                                    fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Face from Surface (v0.33.0)

extension Shape {
    /// Create a face from a surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range (uMin, uMax)
    ///   - vRange: V parameter range (vMin, vMax)
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public static func face(from surface: Surface,
                            uRange: ClosedRange<Double>,
                            vRange: ClosedRange<Double>,
                            tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeCreateFaceFromSurface(surface.handle,
                                                      uRange.lowerBound, uRange.upperBound,
                                                      vRange.lowerBound, vRange.upperBound,
                                                      tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Edges to Faces (v0.33.0)

extension Shape {
    /// Reconstruct faces from a compound of loose edges.
    ///
    /// Takes a shape containing edges and tries to build closed wires,
    /// then creates faces from those wires.
    ///
    /// - Parameters:
    ///   - compound: Shape containing edges to assemble into faces
    ///   - onlyPlanar: If true, only create planar faces
    /// - Returns: Compound of faces, or nil on failure
    public static func facesFromEdges(_ compound: Shape, onlyPlanar: Bool = true) -> Shape? {
        guard let h = OCCTShapeEdgesToFaces(compound.handle, onlyPlanar) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shape-to-Shape Section (v0.34.0)

extension Shape {
    /// Compute the intersection curves/edges between two shapes.
    ///
    /// Returns the intersection geometry (edges/wires) where the two shapes overlap.
    /// Useful for finding contact curves, trim boundaries, and interference analysis.
    ///
    /// - Parameter other: The second shape to intersect with
    /// - Returns: Shape containing intersection edges, or nil on failure
    public func section(_ other: Shape) -> Shape? {
        guard let h = OCCTShapeSection(handle, other.handle) else { return nil }
        return Shape(handle: h)
    }

    @available(*, deprecated, renamed: "section(_:)",
               message: "Use section(_:) to match subtracting(_:) and Set convention")
    public func section(with other: Shape) -> Shape? { section(other) }
}

// MARK: - Boolean Pre-Validation (v0.34.0)

extension Shape {
    /// Check whether this shape is valid for boolean operations.
    ///
    /// - Returns: true if the shape is suitable for boolean operations
    public var isValidForBoolean: Bool {
        OCCTShapeBooleanCheck(handle, nil)
    }

    /// Check whether two shapes are valid for boolean operations with each other.
    ///
    /// - Parameter other: The other shape to check compatibility with
    /// - Returns: true if both shapes are suitable for boolean operations together
    public func isValidForBoolean(with other: Shape) -> Bool {
        OCCTShapeBooleanCheck(handle, other.handle)
    }
}

// MARK: - Split Shape by Wire (v0.34.0)

extension Shape {
    /// Split a face by imprinting a wire onto it.
    ///
    /// The wire is projected/imprinted onto the specified face, dividing it
    /// into multiple faces. Useful for mesh preparation and feature line imprinting.
    ///
    /// - Parameters:
    ///   - wire: Wire to imprint onto the face
    ///   - faceIndex: 0-based index of the face to split
    /// - Returns: Shape with the face split by the wire, or nil on failure
    public func splittingFace(with wire: Wire, faceIndex: Int) -> Shape? {
        guard let h = OCCTShapeSplitByWire(handle, wire.handle, Int32(faceIndex)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Split by Angle (v0.34.0)

extension Shape {
    /// Split surfaces that span more than a specified angle.
    ///
    /// Useful for export to systems that cannot handle full 360° surfaces
    /// (e.g., splitting a full cylinder into quarter-cylinders with maxAngle=90).
    ///
    /// - Parameter maxAngleDegrees: Maximum angle in degrees (e.g., 90 for quarter-turns)
    /// - Returns: Shape with surfaces split at angle boundaries, or nil on failure
    public func splitByAngle(_ maxAngleDegrees: Double) -> Shape? {
        guard let h = OCCTShapeSplitByAngle(handle, maxAngleDegrees) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Drop Small Edges (v0.34.0)

extension Shape {
    /// Remove degenerate/tiny edges from a shape.
    ///
    /// Useful for cleaning up imported geometry with tolerance issues.
    ///
    /// - Parameter tolerance: Tolerance below which edges are considered small
    /// - Returns: Shape with small edges removed, or nil on failure
    public func droppingSmallEdges(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeDropSmallEdges(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

extension Shape {
    /// Fuse multiple shapes simultaneously.
    ///
    /// More robust than sequential pairwise `union(with:)` calls, as it avoids
    /// intermediate tolerance issues and processes all intersections at once.
    ///
    /// - Parameter shapes: Array of shapes to fuse together
    /// - Returns: Fused shape, or nil on failure
    public static func fuseAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeFuseMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Offset Wire (v0.35.0)

extension Shape {
    /// Generate multiple parallel offset wires from a planar face boundary.
    ///
    /// More efficient than calling `Wire.offset` multiple times, and produces
    /// consistent results for CNC toolpath generation.
    ///
    /// - Parameters:
    ///   - offsets: Array of offset distances (positive = outward, negative = inward)
    ///   - joinType: How to join offset segments (default: .arc)
    /// - Returns: Array of offset wires
    public func multiOffsetWires(offsets: [Double],
                                 joinType: OffsetJoinType = .arc) -> [Wire] {
        guard !offsets.isEmpty else { return [] }
        let maxWires = offsets.count * 10 // Allow for multi-contour results
        var wireRefs = [OCCTWireRef?](repeating: nil, count: maxWires)
        let count = offsets.withUnsafeBufferPointer { offsetBuf in
            wireRefs.withUnsafeMutableBufferPointer { wireBuf in
                OCCTWireMultiOffset(handle, offsetBuf.baseAddress, Int32(offsets.count),
                                    joinType.rawValue, wireBuf.baseAddress, Int32(maxWires))
            }
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = wireRefs[i] else { return nil }
            return Wire(handle: ref)
        }
    }
}

// MARK: - Cylindrical Projection (v0.35.0)

extension Shape {
    /// Project a wire/edge shape onto another shape along a direction (cylindrical projection).
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - direction: Projection direction
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWire(_ wire: Shape, onto target: Shape,
                                   direction: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWire(wire.handle, target.handle,
                                            direction.x, direction.y, direction.z) else { return nil }
        return Shape(handle: h)
    }

    /// Project a Wire onto another shape along a direction (cylindrical projection).
    ///
    /// Convenience overload accepting a `Wire` directly.
    public static func projectWire(_ wire: Wire, onto target: Shape,
                                   direction: SIMD3<Double>) -> Shape? {
        guard let wireShape = Shape.fromWire(wire) else { return nil }
        return projectWire(wireShape, onto: target, direction: direction)
    }
}

// MARK: - Same Parameter (v0.35.0)

extension Shape {
    /// Enforce same-parameter consistency on the shape.
    ///
    /// Ensures 3D and 2D curve representations are consistent. Important
    /// for imported geometry and after complex operations.
    ///
    /// - Parameter tolerance: Tolerance for same-parameter check
    /// - Returns: Fixed shape, or nil on failure
    public func sameParameter(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeSameParameter(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Conical Projection (v0.36.0)

extension Shape {
    /// Project a wire/edge shape onto another shape from a point (conical projection).
    ///
    /// Unlike cylindrical projection (parallel rays), conical projection fans out
    /// from a point source, like a spotlight or perspective camera.
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - eye: Point source of projection rays
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWireConical(_ wire: Shape, onto target: Shape,
                                          eye: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWireConical(wire.handle, target.handle,
                                                   eye.x, eye.y, eye.z) else { return nil }
        return Shape(handle: h)
    }

    /// Project a Wire onto another shape from a point (conical projection).
    ///
    /// Convenience overload accepting a `Wire` directly.
    public static func projectWireConical(_ wire: Wire, onto target: Shape,
                                          eye: SIMD3<Double>) -> Shape? {
        guard let wireShape = Shape.fromWire(wire) else { return nil }
        return projectWireConical(wireShape, onto: target, eye: eye)
    }
}

// MARK: - Encode Regularity (v0.36.0)

extension Shape {
    /// Mark smooth (G1-continuous) edges as "regular."
    ///
    /// Downstream algorithms can skip regular edges for better performance.
    /// The angular tolerance controls what is considered "smooth."
    ///
    /// - Parameter toleranceDegrees: Angular tolerance in degrees (default: 1e-10)
    /// - Returns: Shape with regularity encoded, or nil on failure
    public func encodingRegularity(toleranceDegrees: Double = 1e-10) -> Shape? {
        guard let h = OCCTShapeEncodeRegularity(handle, toleranceDegrees) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Update Tolerances (v0.36.0)

extension Shape {
    /// Recalculate and update geometric tolerances on the shape.
    ///
    /// - Parameter verifyFaces: Whether to verify and correct face tolerances
    /// - Returns: Shape with updated tolerances, or nil on failure
    public func updatingTolerances(verifyFaces: Bool = true) -> Shape? {
        guard let h = OCCTShapeUpdateTolerances(handle, verifyFaces) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Divide by Number (v0.36.0)

extension Shape {
    /// Split faces into approximately the specified number of patches.
    ///
    /// Useful for mesh preparation and parametric surface subdivision.
    ///
    /// - Parameter parts: Approximate number of patches per face
    /// - Returns: Shape with divided faces, or nil on failure
    public func dividedByNumber(_ parts: Int) -> Shape? {
        guard parts > 1 else { return nil }
        guard let h = OCCTShapeDivideByNumber(handle, Int32(parts), 1) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Boolean with History (v0.36.0)

/// Result of a boolean operation with shape tracking.
public struct BooleanResult: Sendable {
    /// The result shape
    public let shape: Shape
    /// Shapes in the result that are modifications of faces from the first operand
    public let modifiedFaces: [Shape]
}

extension Shape {
    /// Fuse this shape with another and track which faces were modified.
    ///
    /// - Parameter other: Shape to fuse with
    /// - Returns: Boolean result with modified face tracking, or nil on failure
    public func fuseWithHistory(_ other: Shape) -> BooleanResult? {
        let maxModified: Int32 = 256
        var modRefs = [OCCTShapeRef?](repeating: nil, count: Int(maxModified))
        let count = modRefs.withUnsafeMutableBufferPointer { buf in
            OCCTShapeFuseWithHistory(handle, other.handle, buf.baseAddress, maxModified)
        }
        guard count >= 0 else { return nil }
        // The fuse result is the union
        guard let fused = self.union(other) else { return nil }
        let modified = (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = modRefs[i] else { return nil }
            return Shape(handle: ref)
        }
        return BooleanResult(shape: fused, modifiedFaces: modified)
    }
}

// MARK: - Boolean with Full Per-Input History (issue #165)

/// Per-input-subshape history for a boolean operation: which output
/// sub-shapes the input was modified into, which output sub-shapes were
/// generated FROM it, and whether it was deleted with no replacement.
public struct ShapeHistoryRecord: Sendable {
    /// Output sub-shapes that are modifications of the input (1:1 or 1:N).
    /// Example: a face split by a boolean cut → multiple modified faces.
    public let modified: [Shape]
    /// Output sub-shapes generated FROM the input but not replacing it.
    /// Example: filleting an edge generates new fillet faces from that edge,
    /// while the edge itself is deleted.
    public let generated: [Shape]
    /// True if the input was deleted with no replacement.
    public let isDeleted: Bool
}

/// Retained handle to a boolean operation's builder, queryable for per-input
/// history after the operation completes. Used by tools that need to track
/// selection IDs across boolean / split mutations (e.g. OCCTMCP's
/// `remap_selection`, parametric editors that want feature replay).
public final class ShapeHistoryRef: @unchecked Sendable {
    fileprivate let handle: OCCTBooleanHistoryRef

    fileprivate init(_ handle: OCCTBooleanHistoryRef) {
        self.handle = handle
    }

    deinit {
        OCCTBooleanHistoryRelease(handle)
    }

    /// Look up the post-mutation history of one input sub-shape (any face,
    /// edge, or vertex from the original input shape).
    public func record(of inputSubShape: Shape) -> ShapeHistoryRecord {
        ShapeHistoryRecord(
            modified: collect { buf, max in
                OCCTBooleanHistoryModified(handle, inputSubShape.handle, buf, max)
            },
            generated: collect { buf, max in
                OCCTBooleanHistoryGenerated(handle, inputSubShape.handle, buf, max)
            },
            isDeleted: OCCTBooleanHistoryIsDeleted(handle, inputSubShape.handle)
        )
    }

    private func collect(_ fill: (UnsafeMutablePointer<OCCTShapeRef?>?, Int32) -> Int32) -> [Shape] {
        // Probe with a max=0 call to get the count, then size the buffer exactly.
        let count = fill(nil, 0)
        guard count > 0 else { return [] }
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(count))
        _ = refs.withUnsafeMutableBufferPointer { buf in
            fill(buf.baseAddress, count)
        }
        return refs.compactMap { ref in ref.map(Shape.init(handle:)) }
    }
}

extension Shape {
    /// Boolean union (`self ∪ other`) with full per-input-subshape history.
    /// - Returns: `(result, history)` on success; nil if the operation failed.
    public func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanUnionWithHistory(handle, other.handle, &resultRef),
              let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Boolean subtract (`self \ tool`) with full per-input-subshape history.
    public func subtractedWithFullHistory(_ tool: Shape) -> (result: Shape, history: ShapeHistoryRef)? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanSubtractWithHistory(handle, tool.handle, &resultRef),
              let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Boolean intersect (`self ∩ other`) with full per-input-subshape history.
    public func intersectionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanIntersectWithHistory(handle, other.handle, &resultRef),
              let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Split `self` by `tool` (BRepAlgoAPI_Splitter). The pieces are the
    /// top-level children of the compound result; query history per input
    /// sub-shape via `history.record(of:)`.
    public func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)? {
        var compoundRef: OCCTShapeRef?
        guard let h = OCCTBooleanSplitWithHistory(handle, tool.handle, &compoundRef),
              let compoundRef else { return nil }
        let compound = Shape(handle: compoundRef)

        let pieceCount = OCCTShapeCompoundChildren(compound.handle, nil, 0)
        let pieces: [Shape]
        if pieceCount > 0 {
            var refs = [OCCTShapeRef?](repeating: nil, count: Int(pieceCount))
            _ = refs.withUnsafeMutableBufferPointer { buf in
                OCCTShapeCompoundChildren(compound.handle, buf.baseAddress, pieceCount)
            }
            pieces = refs.compactMap { ref in ref.map(Shape.init(handle:)) }
        } else {
            pieces = []
        }
        return (pieces, ShapeHistoryRef(h))
    }
}

// MARK: - Tier 2 modification ops with full per-input history (issue #165)

extension Shape {
    /// Apply a uniform-radius fillet to the given edges, returning the result
    /// shape and a `ShapeHistoryRef` queryable for `Modified` / `Generated` /
    /// `IsDeleted` per input sub-shape (e.g. a filleted edge → multiple
    /// generated fillet faces).
    public func filletedWithFullHistory(radius: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !edges.isEmpty else { return nil }
        let edgeIndices = edges.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = edgeIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromFilletEdges(handle, buf.baseAddress!, Int32(edgeIndices.count),
                                              radius, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Variable-radius fillet on a single edge: radius linearly varies from
    /// `startRadius` (at the edge's first parameter) to `endRadius` (at last).
    public func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeHistoryFromFilletEdgeVariable(handle, Int32(edge),
                                                               startRadius, endRadius,
                                                               &resultRef),
              let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Apply a uniform chamfer to the given edges, returning the result and
    /// a queryable history.
    public func chamferedWithFullHistory(distance: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !edges.isEmpty else { return nil }
        let edgeIndices = edges.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = edgeIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromChamferEdges(handle, buf.baseAddress!, Int32(edgeIndices.count),
                                               distance, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Shell / hollow: remove the listed faces and offset the remaining shell
    /// inward by `thickness` (use a negative `thickness` for outward), with a
    /// queryable per-face history.
    public func shelledWithFullHistory(facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !facesToRemove.isEmpty else { return nil }
        let faceIndices = facesToRemove.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = faceIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromShell(handle, buf.baseAddress!, Int32(faceIndices.count),
                                       thickness, tolerance, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Defeature: remove given faces by reconnecting surrounding topology.
    /// History reports each removed face as deleted and surrounding faces as
    /// modified.
    public func defeaturedWithFullHistory(faces: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !faces.isEmpty else { return nil }
        let faceIndices = faces.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = faceIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromDefeature(handle, buf.baseAddress!, Int32(faceIndices.count),
                                            &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }
}

// MARK: - Thick Solid / Hollowing (v0.37.0)

extension Shape {
    /// Create a hollowed (thick) solid by removing faces and offsetting inward.
    ///
    /// Removes the specified faces and creates a shell with uniform wall thickness.
    /// The removed faces become openings in the resulting hollow shape.
    ///
    /// - Parameters:
    ///   - faceIndices: 0-based indices of faces to remove (become openings)
    ///   - thickness: Wall thickness (positive = offset inward)
    ///   - tolerance: Tolerance for the operation
    ///   - joinType: How to join offset edges (default: .arc)
    /// - Returns: Hollowed solid, or nil on failure
    public func hollowed(removingFaces faceIndices: [Int],
                         thickness: Double,
                         tolerance: Double = 1e-3,
                         joinType: OffsetJoinType = .arc) -> Shape? {
        guard !faceIndices.isEmpty else { return nil }
        let indices = faceIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { buf in
            OCCTShapeMakeThickSolid(handle, buf.baseAddress, Int32(faceIndices.count),
                                     thickness, tolerance, joinType.rawValue)
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shell from Surface (v0.37.0)

extension Shape {
    /// Create a shell from a parametric surface with UV bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    /// - Returns: Shell shape, or nil on failure
    public static func shell(from surface: Surface,
                             uRange: ClosedRange<Double>,
                             vRange: ClosedRange<Double>) -> Shape? {
        guard let h = OCCTShapeMakeShell(surface.handle,
                                          uRange.lowerBound, uRange.upperBound,
                                          vRange.lowerBound, vRange.upperBound) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Tool Boolean Common (v0.37.0)

extension Shape {
    /// Compute the common (intersection) of multiple shapes simultaneously.
    ///
    /// - Parameter shapes: Array of shapes to intersect
    /// - Returns: Common shape (intersection of all), or nil on failure
    public static func commonAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeCommonMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Oriented Bounding Box (v0.38.0)

/// An oriented (rotated) bounding box that fits tightly around a shape.
public struct OrientedBoundingBox: Sendable {
    /// Center of the bounding box.
    public var center: SIMD3<Double>
    /// X-axis direction of the box.
    public var xDirection: SIMD3<Double>
    /// Y-axis direction of the box.
    public var yDirection: SIMD3<Double>
    /// Z-axis direction of the box.
    public var zDirection: SIMD3<Double>
    /// Half-dimensions along each axis.
    public var halfSizes: SIMD3<Double>

    /// Volume of the bounding box.
    public var volume: Double { 8.0 * halfSizes.x * halfSizes.y * halfSizes.z }

    /// Full dimensions of the bounding box.
    public var dimensions: SIMD3<Double> { 2.0 * halfSizes }
}

extension Shape {
    /// Compute an oriented (tight-fit, rotated) bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB (slower). Default is false.
    /// - Returns: The oriented bounding box, or nil on failure.
    public func orientedBoundingBox(optimal: Bool = false) -> OrientedBoundingBox? {
        var result = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &result) else { return nil }
        return OrientedBoundingBox(
            center: SIMD3(result.centerX, result.centerY, result.centerZ),
            xDirection: SIMD3(result.xDirX, result.xDirY, result.xDirZ),
            yDirection: SIMD3(result.yDirX, result.yDirY, result.yDirZ),
            zDirection: SIMD3(result.zDirX, result.zDirY, result.zDirZ),
            halfSizes: SIMD3(result.halfX, result.halfY, result.halfZ)
        )
    }

    /// Get the 8 corners of the oriented bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB. Default is false.
    /// - Returns: Array of 8 corner points, or nil on failure.
    public func orientedBoundingBoxCorners(optimal: Bool = false) -> [SIMD3<Double>]? {
        var obb = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &obb) else { return nil }
        var corners = [Double](repeating: 0, count: 24)
        OCCTOrientedBoundingBoxCorners(&obb, &corners)
        var result = [SIMD3<Double>]()
        result.reserveCapacity(8)
        for i in stride(from: 0, to: 24, by: 3) {
            result.append(SIMD3(corners[i], corners[i+1], corners[i+2]))
        }
        return result
    }
}

// MARK: - Deep Shape Copy (v0.38.0)

extension Shape {
    /// Create a deep, independent copy of this shape.
    ///
    /// - Parameters:
    ///   - copyGeometry: If true, copy the underlying geometry (default: true).
    ///   - copyMesh: If true, also copy mesh data (default: false).
    /// - Returns: A new independent shape, or nil on failure.
    public func copy(copyGeometry: Bool = true, copyMesh: Bool = false) -> Shape? {
        guard let h = OCCTShapeCopy(handle, copyGeometry, copyMesh) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Sub-Shape Extraction (v0.38.0)

extension Shape {
    /// Number of solid sub-shapes.
    public var solidCount: Int { Int(OCCTShapeGetSolidCount(handle)) }

    /// Extract all solid sub-shapes.
    public var solids: [Shape] {
        let count = OCCTShapeGetSolidCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetSolids(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }

    /// Number of shell sub-shapes.
    public var shellCount: Int { Int(OCCTShapeGetShellCount(handle)) }

    /// The **outer shell** of this solid (`BRepClass3d::OuterShell`).
    ///
    /// For a solid with internal voids (multiple shells — e.g. a body with a cavity), this
    /// returns the shell that bounds the outer body, distinguishing it from the inner void
    /// shells. Returns `nil` if the shape is not a solid (or a compound wrapping one) or has
    /// no shell. Useful for decomposing a part into outer-body + cavities. (#211)
    public var outerShell: Shape? {
        OCCTShapeOuterShell(handle).map(Shape.init(handle:))
    }

    /// The **inner** (void / cavity) shells of this solid — every shell except ``outerShell``.
    ///
    /// Empty for a solid with no internal voids (or a non-solid). Pairs with ``outerShell`` to
    /// decompose a part into outer body + cavities. (#212)
    public var innerShells: [Shape] {
        let count = OCCTShapeInnerShells(handle, nil, 0)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeInnerShells(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in h.map { Shape(handle: $0) } }
    }

    /// Extract all shell sub-shapes.
    public var shells: [Shape] {
        let count = OCCTShapeGetShellCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetShells(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }

    /// Number of wire sub-shapes.
    public var wireCount: Int { Int(OCCTShapeGetWireCount(handle)) }

    /// Extract all wire sub-shapes.
    public var wires: [Shape] {
        let count = OCCTShapeGetWireCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetWires(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }
}

// MARK: - Fuse and Blend (v0.38.0)

extension Shape {
    /// Fuse with another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to fuse with.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Fused and filleted shape, or nil on failure.
    public func fusedAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeFuseAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }

    /// Cut another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to cut from this shape.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Cut and filleted shape, or nil on failure.
    public func cutAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeCutAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

/// Describes an evolving radius along an edge for filleting.
public struct EvolvingFilletEdge: Sendable {
    /// 1-based edge index.
    public var edgeIndex: Int
    /// Array of (parameter, radius) pairs defining the radius evolution along the edge.
    public var radiusPoints: [(parameter: Double, radius: Double)]

    public init(edgeIndex: Int, radiusPoints: [(parameter: Double, radius: Double)]) {
        self.edgeIndex = edgeIndex
        self.radiusPoints = radiusPoints
    }
}

extension Shape {
    /// Apply evolving-radius fillets to multiple edges simultaneously.
    ///
    /// - Parameter edges: Array of edge specifications with radius evolution.
    /// - Returns: Filleted shape, or nil on failure.
    public func filletEvolving(_ edges: [EvolvingFilletEdge]) -> Shape? {
        guard !edges.isEmpty else { return nil }

        let edgeIndices = edges.map { Int32($0.edgeIndex) }
        let pointCounts = edges.map { Int32($0.radiusPoints.count) }
        var radiusPoints = [OCCTFilletRadiusPoint]()
        for edge in edges {
            for rp in edge.radiusPoints {
                radiusPoints.append(OCCTFilletRadiusPoint(parameter: rp.parameter, radius: rp.radius))
            }
        }

        guard let h = OCCTShapeFilletEvolving(handle, edgeIndices, Int32(edges.count),
                                               radiusPoints, pointCounts) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Per-Face Variable Offset (v0.38.0)

extension Shape {
    /// Offset a shape with different distances per face.
    ///
    /// - Parameters:
    ///   - defaultOffset: Default offset distance for all faces.
    ///   - faceOffsets: Dictionary mapping 1-based face indices to custom offset distances.
    ///   - tolerance: Offset tolerance (default: 1e-3).
    ///   - joinType: Join type for offset gaps (default: .arc).
    /// - Returns: Offset shape, or nil on failure.
    public func offsetPerFace(defaultOffset: Double,
                               faceOffsets: [Int: Double],
                               tolerance: Double = 1e-3,
                               joinType: OffsetJoinType = .arc) -> Shape? {
        let indices = Array(faceOffsets.keys).map { Int32($0) }
        let offsets = Array(faceOffsets.keys).map { faceOffsets[$0]! }

        guard let h = OCCTShapeOffsetPerFace(handle, defaultOffset,
                                              indices, offsets,
                                              Int32(faceOffsets.count),
                                              tolerance, Int32(joinType.rawValue)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Free Boundary Analysis (v0.39.0)

    /// Result of free boundary analysis
    public struct FreeBoundsResult: Sendable {
        /// Compound shape containing all free boundary wires
        public let wires: Shape
        /// Number of closed free boundary wires
        public let closedCount: Int
        /// Number of open free boundary wires
        public let openCount: Int
    }

    /// Analyze free boundary wires (open edges not shared by two faces).
    ///
    /// Free boundaries indicate gaps in a shell. A watertight shell has no free boundaries.
    /// - Parameter sewingTolerance: Tolerance for grouping free edges into wires
    /// - Returns: Free bounds result, or nil if no free boundaries found
    public func freeBounds(sewingTolerance: Double = 1e-6) -> FreeBoundsResult? {
        var closedCount: Int32 = 0
        var openCount: Int32 = 0
        guard let h = OCCTShapeFreeBounds(handle, sewingTolerance,
                                           &closedCount, &openCount) else { return nil }
        return FreeBoundsResult(wires: Shape(handle: h),
                                closedCount: Int(closedCount),
                                openCount: Int(openCount))
    }

    /// Fix free boundary wires by closing gaps.
    ///
    /// - Parameters:
    ///   - sewingTolerance: Tolerance for sewing free edges
    ///   - closingTolerance: Maximum distance to close a gap
    /// - Returns: Tuple of (fixed shape, number of wires fixed), or nil on failure
    public func fixedFreeBounds(sewingTolerance: Double = 1e-6,
                                 closingTolerance: Double = 1e-4) -> (shape: Shape, fixedCount: Int)? {
        var fixedCount: Int32 = 0
        guard let h = OCCTShapeFixFreeBounds(handle, sewingTolerance,
                                              closingTolerance, &fixedCount) else { return nil }
        return (shape: Shape(handle: h), fixedCount: Int(fixedCount))
    }

    // MARK: - Pipe Feature (v0.39.0)

    /// Create a pipe feature by sweeping a profile along a spine, fused with or cut from this shape.
    ///
    /// - Parameters:
    ///   - profile: Profile shape (face) to sweep along the spine
    ///   - sketchFaceIndex: Index (0-based) of the face on this shape where the profile sits
    ///   - spine: Wire defining the sweep path
    ///   - fuse: If true, add material; if false, remove material
    /// - Returns: Modified shape, or nil on failure
    public func pipeFeature(profile: Shape, sketchFaceIndex: Int,
                            spine: Wire, fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapePipeFeatureFromProfile(
            handle, profile.handle, Int32(sketchFaceIndex),
            spine.handle, fuse ? 1 : 0
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Semi-Infinite Extrusion (v0.39.0)

    /// Extrude a shape semi-infinitely in a direction.
    ///
    /// Creates a solid that extends infinitely in one direction from the profile.
    /// Useful for half-spaces and trimming operations.
    /// - Parameters:
    ///   - direction: Direction of extrusion
    ///   - infinite: If true, extrude in both directions (infinite); if false, one direction (semi-infinite)
    /// - Returns: Extruded shape, or nil on failure
    public func extrudedSemiInfinite(direction: SIMD3<Double>, infinite: Bool = false) -> Shape? {
        guard let h = OCCTShapeExtrudeSemiInfinite(handle,
                                                    direction.x, direction.y, direction.z,
                                                    !infinite) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Prism Until Face (v0.39.0)

    /// Extrude a profile until it reaches a target face, with automatic fuse/cut.
    ///
    /// Uses BRepFeat_MakePrism which is smarter than simple extrusion+boolean.
    /// - Parameters:
    ///   - profile: Profile face to extrude
    ///   - sketchFaceIndex: Face on this shape where the profile sits (0-based)
    ///   - direction: Extrusion direction
    ///   - fuse: If true, add material; if false, remove material
    ///   - untilFaceIndex: Face index (0-based) where extrusion stops. Pass nil for thru-all.
    /// - Returns: Modified shape, or nil on failure
    public func prismUntilFace(profile: Shape, sketchFaceIndex: Int,
                               direction: SIMD3<Double>, fuse: Bool = true,
                               untilFaceIndex: Int? = nil) -> Shape? {
        guard let h = OCCTShapePrismUntilFace(
            handle, profile.handle, Int32(sketchFaceIndex),
            direction.x, direction.y, direction.z,
            fuse ? 1 : 0, Int32(untilFaceIndex ?? -1)
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Inertia Properties (v0.40.0)

    /// Volume-based inertia properties (volume, center of mass, inertia tensor, principal moments)
    public struct InertiaProperties {
        /// Volume (for volume properties) or surface area (for surface properties)
        public let mass: Double
        /// Center of mass
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia matrix (row-major: [Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz])
        public let inertiaMatrix: [Double]
        /// Principal moments of inertia (Ix, Iy, Iz)
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (three unit vectors)
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Whether the shape has a symmetry axis
        public let hasSymmetryAxis: Bool
        /// Whether the shape has a symmetry point
        public let hasSymmetryPoint: Bool
    }

    /// Compute volume-based inertia properties
    ///
    /// Returns volume, center of mass, 3x3 inertia tensor, principal moments,
    /// and principal axes of inertia.
    /// - Returns: Inertia properties, or nil if computation fails
    public func inertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    /// Compute surface-area-based inertia properties
    ///
    /// Similar to `inertiaProperties()` but uses surface area instead of volume.
    /// The `mass` field contains surface area.
    /// - Returns: Inertia properties, or nil if computation fails
    public func surfaceInertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeSurfaceInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    // MARK: - Extended Distance (v0.40.0)

    /// A distance solution between two shapes
    public struct DistanceSolution {
        /// Closest point on the first shape
        public let point1: SIMD3<Double>
        /// Closest point on the second shape
        public let point2: SIMD3<Double>
        /// Distance between the two points
        public let distance: Double
    }

    /// Compute all distance solutions between this shape and another
    ///
    /// Returns all extremal point pairs, not just the minimum distance.
    /// Useful for finding multiple closest/farthest point pairs.
    /// - Parameters:
    ///   - other: The other shape
    ///   - maxSolutions: Maximum number of solutions to return (default 32)
    /// - Returns: Array of distance solutions, or nil on failure
    public func allDistanceSolutions(to other: Shape, maxSolutions: Int = 32) -> [DistanceSolution]? {
        var buffer = [OCCTDistanceSolution](repeating: OCCTDistanceSolution(), count: maxSolutions)
        let count = OCCTShapeAllDistanceSolutions(handle, other.handle, &buffer, Int32(maxSolutions))
        guard count >= 0 else { return nil }
        return (0..<min(Int(count), maxSolutions)).map { i in
            DistanceSolution(
                point1: SIMD3(buffer[i].point1X, buffer[i].point1Y, buffer[i].point1Z),
                point2: SIMD3(buffer[i].point2X, buffer[i].point2Y, buffer[i].point2Z),
                distance: buffer[i].distance
            )
        }
    }

    /// Check if this shape is fully contained inside another shape
    ///
    /// Uses BRepExtrema_DistShapeShape inner solution detection.
    /// - Parameter container: The potential container shape
    /// - Returns: true if this shape is inside the container, nil on failure
    public func isInside(_ container: Shape) -> Bool? {
        let result = OCCTShapeIsInnerDistance(handle, container.handle)
        guard result >= 0 else { return nil }
        return result == 1
    }

    /// Support type for a distance solution point.
    public enum DistanceSupportType: Int32, Sendable {
        case vertex = 0
        case onEdge = 1
        case inFace = 2
    }

    /// Detailed parametric info for a distance solution.
    public struct DistanceSolutionDetail: Sendable {
        public let supportType1: DistanceSupportType
        public let supportType2: DistanceSupportType
        public let paramEdge1: Double
        public let paramEdge2: Double
        public let paramFaceUV1: (u: Double, v: Double)
        public let paramFaceUV2: (u: Double, v: Double)
    }

    /// Get detailed parametric info for a specific distance solution.
    ///
    /// Returns the support type (vertex/edge/face) and parametric location
    /// for each closest point. Use with `allDistanceSolutions(to:)` to get
    /// the solution index.
    public func distanceSolutionDetail(to other: Shape, solutionIndex: Int) -> DistanceSolutionDetail? {
        var detail = OCCTDistanceSolutionDetail()
        guard OCCTShapeDistanceSolutionDetail(handle, other.handle, Int32(solutionIndex), &detail) else { return nil }
        return DistanceSolutionDetail(
            supportType1: DistanceSupportType(rawValue: detail.supportType1) ?? .vertex,
            supportType2: DistanceSupportType(rawValue: detail.supportType2) ?? .vertex,
            paramEdge1: detail.paramEdge1,
            paramEdge2: detail.paramEdge2,
            paramFaceUV1: (u: detail.paramFaceU1, v: detail.paramFaceV1),
            paramFaceUV2: (u: detail.paramFaceU2, v: detail.paramFaceV2)
        )
    }

    // MARK: - Find Surface (v0.40.0)

    /// Find the underlying geometric surface of a shape (wire or edges)
    ///
    /// Analyzes the edges of a shape to determine if they lie on a common surface.
    /// - Parameters:
    ///   - tolerance: Tolerance for surface detection (default 1e-6)
    ///   - onlyPlane: If true, only look for planar surfaces (default false)
    /// - Returns: The underlying surface, or nil if none found
    public func findSurfaceEx(tolerance: Double = 1e-6, onlyPlane: Bool = false) -> Surface? {
        var found = false
        guard let surfHandle = OCCTShapeFindSurfaceEx(handle, tolerance, onlyPlane, &found),
              found else { return nil }
        return Surface(handle: surfHandle)
    }

    // MARK: - Shape Surgery (v0.41.0)

    /// Remove sub-shapes from this shape
    ///
    /// Uses BRepTools_ReShape to surgically remove faces, edges, or vertices
    /// while preserving the remaining topology.
    /// - Parameter subShapes: Sub-shapes to remove
    /// - Returns: Shape with sub-shapes removed, or nil on failure
    public func removingSubShapes(_ subShapes: [Shape]) -> Shape? {
        var handles = subShapes.map { $0.handle as OCCTShapeRef? }
        guard let h = handles.withUnsafeMutableBufferPointer({ buf in
            OCCTShapeRemoveSubShapes(handle, buf.baseAddress, Int32(subShapes.count))
        }) else { return nil }
        return Shape(handle: h)
    }

    /// Replace sub-shapes in this shape
    ///
    /// Uses BRepTools_ReShape to replace specific sub-shapes with new ones.
    /// - Parameter replacements: Array of (old, new) shape pairs
    /// - Returns: Shape with replacements applied, or nil on failure
    public func replacingSubShapes(_ replacements: [(old: Shape, new: Shape)]) -> Shape? {
        var oldHandles = replacements.map { $0.old.handle as OCCTShapeRef? }
        var newHandles = replacements.map { $0.new.handle as OCCTShapeRef? }
        guard let h = oldHandles.withUnsafeMutableBufferPointer({ oldBuf in
            newHandles.withUnsafeMutableBufferPointer({ newBuf in
                OCCTShapeReplaceSubShapes(handle, oldBuf.baseAddress, newBuf.baseAddress,
                                           Int32(replacements.count))
            })
        }) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Plane Detection (v0.41.0)

    /// Result of plane detection
    public struct DetectedPlane {
        /// Plane normal direction
        public let normal: SIMD3<Double>
        /// Plane origin point
        public let origin: SIMD3<Double>
    }

    /// Find if this shape's edges lie in a plane
    ///
    /// Uses BRepBuilderAPI_FindPlane to detect if a wire, edge set, or shape
    /// lies in a single geometric plane.
    /// - Parameter tolerance: Tolerance for planarity check (default 1e-6)
    /// - Returns: Detected plane, or nil if shape is not planar
    public func findPlane(tolerance: Double = 1e-6) -> DetectedPlane? {
        var nx = 0.0, ny = 0.0, nz = 0.0
        var ox = 0.0, oy = 0.0, oz = 0.0
        guard OCCTShapeFindPlane(handle, tolerance, &nx, &ny, &nz, &ox, &oy, &oz) else {
            return nil
        }
        return DetectedPlane(normal: SIMD3(nx, ny, nz), origin: SIMD3(ox, oy, oz))
    }

    // MARK: - Closed Edge Splitting (v0.41.0)

    /// Split closed (periodic) edges in the shape
    ///
    /// Periodic edges (like circles) can cause issues in some algorithms.
    /// This splits each closed edge into segments.
    /// - Parameter splitPoints: Number of split points per closed edge (default 1, doubles the edge count)
    /// - Returns: Shape with closed edges split, or nil on failure
    public func dividedClosedEdges(splitPoints: Int = 1) -> Shape? {
        guard let h = OCCTShapeDivideClosedEdges(handle, Int32(splitPoints)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Geometry Conversion (v0.41.0)

    /// Convert all surfaces to BSpline form
    ///
    /// Uses ShapeCustom::ConvertToBSpline to convert extrusion, revolution,
    /// offset, and/or planar surfaces to BSpline representation.
    /// - Parameters:
    ///   - extrusion: Convert extrusion surfaces (default true)
    ///   - revolution: Convert revolution surfaces (default true)
    ///   - offset: Convert offset surfaces (default true)
    ///   - plane: Convert planar surfaces (default false)
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsBSpline(extrusion: Bool = true, revolution: Bool = true,
                                       offset: Bool = true, plane: Bool = false) -> Shape? {
        guard let h = OCCTShapeCustomConvertToBSpline(handle, extrusion, revolution, offset, plane) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Convert surfaces to revolution form
    ///
    /// Uses ShapeCustom::ConvertToRevolution to convert surfaces that can be
    /// represented as surfaces of revolution.
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsRevolution() -> Shape? {
        guard let h = OCCTShapeCustomConvertToRevolution(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Face Restriction (v0.41.0)

    /// Create restricted faces from a face and wire boundaries
    ///
    /// Uses BRepAlgo_FaceRestrictor to build faces on the underlying surface
    /// of this shape's first face, bounded by the given wires.
    /// - Parameter boundaries: Wire boundaries that define the restricted regions
    /// - Returns: Array of restricted face shapes, or nil on failure
    public func faceRestricted(by boundaries: [Wire]) -> [Shape]? {
        let maxFaces: Int32 = 64
        var wireHandles = boundaries.map { $0.handle as OCCTWireRef? }
        var outFaces = [OCCTShapeRef?](repeating: nil, count: Int(maxFaces))

        let count = wireHandles.withUnsafeMutableBufferPointer { wireBuf in
            outFaces.withUnsafeMutableBufferPointer { faceBuf in
                OCCTShapeFaceRestrict(handle, wireBuf.baseAddress, Int32(boundaries.count),
                                       faceBuf.baseAddress, maxFaces)
            }
        }
        guard count > 0 else { return nil }
        return (0..<Int(count)).compactMap { i in
            guard let ref = outFaces[i] else { return nil }
            return Shape(handle: ref)
        }
    }

    // MARK: - v0.42.0: Solid Construction, 2D Fillet/Chamfer, Point Cloud Analysis

    /// Create a solid from one or more shell shapes.
    ///
    /// Uses BRepBuilderAPI_MakeSolid to construct a solid from shells extracted from
    /// the given shapes. The first shape provides the outer shell, and additional shapes
    /// provide cavity (inner) shells.
    ///
    /// - Parameter shells: Array of shapes containing shells (first = outer, rest = cavities)
    /// - Returns: Solid shape, or nil on failure
    public static func solidFromShells(_ shells: [Shape]) -> Shape? {
        guard !shells.isEmpty else { return nil }
        var handles = shells.map { $0.handle as OCCTShapeRef? }
        let result = handles.withUnsafeMutableBufferPointer { buffer in
            OCCTSolidFromShells(buffer.baseAddress, Int32(shells.count))
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Apply 2D fillets (rounded corners) to a planar face at specified vertices.
    ///
    /// Uses BRepFilletAPI_MakeFillet2d to round corners of a planar face.
    /// Vertex indices are 0-based and correspond to the topological vertex order.
    ///
    /// - Parameters:
    ///   - vertexIndices: 0-based indices of vertices to fillet
    ///   - radii: Fillet radius for each vertex (must match vertexIndices count)
    /// - Returns: Modified shape with fillets, or nil on failure
    public func fillet2D(vertexIndices: [Int], radii: [Double]) -> Shape? {
        guard !vertexIndices.isEmpty, vertexIndices.count == radii.count else { return nil }
        let indices = vertexIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { idxBuf in
            radii.withUnsafeBufferPointer { radBuf in
                OCCTFace2DFillet(handle, idxBuf.baseAddress, radBuf.baseAddress, Int32(vertexIndices.count))
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
    /// - Parameters:
    ///   - edgePairs: Array of (edge1Index, edge2Index) pairs identifying adjacent edges
    ///   - distances: Chamfer distance for each edge pair
    /// - Returns: Modified shape with chamfers, or nil on failure
    public func chamfer2D(edgePairs: [(Int, Int)], distances: [Double]) -> Shape? {
        guard !edgePairs.isEmpty, edgePairs.count == distances.count else { return nil }
        let edge1Indices = edgePairs.map { Int32($0.0) }
        let edge2Indices = edgePairs.map { Int32($0.1) }
        let result = edge1Indices.withUnsafeBufferPointer { e1Buf in
            edge2Indices.withUnsafeBufferPointer { e2Buf in
                distances.withUnsafeBufferPointer { distBuf in
                    OCCTFace2DChamfer(handle, e1Buf.baseAddress, e2Buf.baseAddress,
                                       distBuf.baseAddress, Int32(edgePairs.count))
                }
            }
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Result of point cloud geometry analysis.
    public enum PointCloudGeometry {
        /// All points are coincident (within tolerance)
        case point(SIMD3<Double>)
        /// Points are collinear — fit a line
        case linear(origin: SIMD3<Double>, direction: SIMD3<Double>)
        /// Points are coplanar — fit a plane
        case planar(origin: SIMD3<Double>, normal: SIMD3<Double>)
        /// Points are dispersed in 3D space
        case space
    }

    /// Analyze a set of 3D points to determine their geometric arrangement.
    ///
    /// Uses GProp_PEquation to classify points as coincident, collinear, coplanar,
    /// or dispersed in 3D space. Useful for determining degeneracy of point sets
    /// before constructing geometry.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 1)
    ///   - tolerance: Tolerance for classification
    /// - Returns: Classification result, or nil on failure
    public static func analyzePointCloud(_ points: [SIMD3<Double>], tolerance: Double = 1e-6) -> PointCloudGeometry? {
        guard !points.isEmpty else { return nil }
        var coords: [Double] = []
        coords.reserveCapacity(points.count * 3)
        for p in points {
            coords.append(p.x)
            coords.append(p.y)
            coords.append(p.z)
        }
        var result = OCCTPointCloudGeometry()
        let ok = coords.withUnsafeBufferPointer { buffer in
            OCCTAnalyzePointCloud(buffer.baseAddress, Int32(points.count), tolerance, &result)
        }
        guard ok else { return nil }
        switch result.type {
        case 0:
            return .point(SIMD3(result.pointX, result.pointY, result.pointZ))
        case 1:
            return .linear(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                direction: SIMD3(result.dirX, result.dirY, result.dirZ)
            )
        case 2:
            return .planar(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                normal: SIMD3(result.normalX, result.normalY, result.normalZ)
            )
        case 3:
            return .space
        default:
            return nil
        }
    }

    // MARK: - v0.43.0: Face Subdivision, Small Face Detection, Location Purge

    /// Subdivide faces whose area exceeds a maximum threshold.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea to split faces larger than the specified area.
    /// Useful for mesh quality control and FEA preprocessing.
    ///
    /// - Parameter maxArea: Maximum face area — faces larger than this are split
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByArea(maxArea: Double) -> Shape? {
        guard let ref = OCCTShapeDivideByArea(handle, maxArea) else { return nil }
        return Shape(handle: ref)
    }

    /// Subdivide faces into a target number of parts.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea in splitting-by-number mode.
    ///
    /// - Parameter parts: Target number of parts per face
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByParts(_ parts: Int) -> Shape? {
        guard let ref = OCCTShapeDivideByParts(handle, Int32(parts)) else { return nil }
        return Shape(handle: ref)
    }

    /// Result of small/degenerate face analysis.
    public struct SmallFaceInfo: Sendable {
        /// Whether the face is collapsed to a point
        public let isSpotFace: Bool
        /// Whether the face has negligible width
        public let isStripFace: Bool
        /// Whether the face is twisted
        public let isTwisted: Bool
        /// Location of spot face (if isSpotFace is true)
        public let spotLocation: SIMD3<Double>?
    }

    /// Check faces for degenerate conditions (spot, strip, twisted).
    ///
    /// Uses ShapeAnalysis_CheckSmallFace to analyze each face of the shape.
    /// Returns only faces that have at least one degenerate condition.
    ///
    /// - Parameter tolerance: Analysis tolerance (default 1e-6)
    /// - Returns: Array of degenerate face descriptions, empty if none found
    public func checkSmallFaces(tolerance: Double = 1e-6) -> [SmallFaceInfo] {
        let maxResults: Int32 = 256
        var results = [OCCTSmallFaceResult](repeating: OCCTSmallFaceResult(), count: Int(maxResults))
        let count = results.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeCheckSmallFaces(handle, tolerance, buffer.baseAddress, maxResults)
        }
        return (0..<Int(count)).map { i in
            let r = results[i]
            return SmallFaceInfo(
                isSpotFace: r.isSpotFace,
                isStripFace: r.isStripFace,
                isTwisted: r.isTwisted,
                spotLocation: r.isSpotFace ? SIMD3(r.spotX, r.spotY, r.spotZ) : nil
            )
        }
    }

    /// Purge problematic location datums from the shape.
    ///
    /// Removes negative-scale and non-unit-scale transforms from the shape and all
    /// sub-shapes. Useful for cleaning imported geometry from STEP/IGES files.
    ///
    /// - Returns: Cleaned shape, or nil if purge was unnecessary or failed
    public var purgedLocations: Shape? {
        guard let ref = OCCTShapePurgeLocations(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Curve-on-Surface Check

    /// Result of a curve-on-surface consistency check.
    public struct CurveOnSurfaceCheck {
        /// Maximum deviation between 3D edge curves and their pcurves on faces
        public let maxDistance: Double
        /// Curve parameter where the maximum deviation occurs
        public let maxParameter: Double
    }

    /// Check edge-on-surface consistency.
    ///
    /// Examines all edge-face pairs in the shape and reports the maximum deviation
    /// between each edge's 3D curve and its parametric curve (pcurve) on the face surface.
    /// Useful for validating imported geometry or checking repair results.
    ///
    /// - Returns: Check result with max distance and parameter, or nil if check fails
    public var curveOnSurfaceCheck: CurveOnSurfaceCheck? {
        var maxDist: Double = 0
        var maxParam: Double = 0
        guard OCCTShapeCheckCurveOnSurface(handle, &maxDist, &maxParam) else { return nil }
        return CurveOnSurfaceCheck(maxDistance: maxDist, maxParameter: maxParam)
    }

    // MARK: - Edge Connection

    /// Connect edges by merging shared vertices in the shape.
    ///
    /// Uses ShapeFix_EdgeConnect to identify edges that share geometric positions
    /// and merges their vertices. Useful for healing imported geometry where
    /// topologically disconnected edges actually meet at the same point.
    ///
    /// - Returns: Shape with connected edges, or nil on failure
    public var connectedEdges: Shape? {
        guard let ref = OCCTShapeConnectEdges(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Self-Intersection Detection (v0.45.0)

    /// Result of a self-intersection check
    public struct SelfIntersectionResult: Sendable {
        /// Number of overlapping triangle pairs found
        public let overlapCount: Int
        /// Whether the check completed successfully
        public let isDone: Bool
    }

    /// Check the shape for self-intersection using BVH-accelerated triangle mesh overlap.
    ///
    /// Meshes the shape and uses BRepExtrema_SelfIntersection to detect overlapping
    /// triangle pairs, which indicate self-intersection.
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for detecting intersections (default 0.001)
    ///   - meshDeflection: Mesh deflection for triangulation (default 0.5)
    /// - Returns: Self-intersection result, or nil if the check failed
    public func selfIntersection(tolerance: Double = 0.001,
                                  meshDeflection: Double = 0.5) -> SelfIntersectionResult? {
        let result = OCCTShapeSelfIntersection(handle, tolerance, meshDeflection)
        guard result.isDone else { return nil }
        return SelfIntersectionResult(overlapCount: Int(result.overlapCount), isDone: true)
    }

    // MARK: - Bezier Conversion

    /// Convert all curves and surfaces in the shape to Bezier representations.
    ///
    /// Uses ShapeUpgrade_ShapeConvertToBezier to replace BSpline curves and surfaces
    /// with their Bezier equivalents. Converts 2D/3D curves, surfaces, lines, circles,
    /// conics, planes, revolutions, extrusions, and BSpline entities.
    ///
    /// - Returns: Shape with Bezier geometry, or nil on failure
    public var convertedToBezier: Shape? {
        guard let ref = OCCTShapeConvertToBezier(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Edge Concavity Analysis (v0.46.0)

    /// Edge concavity type from BRepOffset_Analyse
    public enum EdgeConcavity: Sendable {
        /// Edge connects two faces at a convex angle (outer edge of a box)
        case convex
        /// Edge connects two faces at a concave angle (inner edge of a groove)
        case concave
        /// Edge connects two faces that are tangent (smooth transition)
        case tangent
    }

    /// Classify all edges by their concavity type using BRepOffset_Analyse.
    ///
    /// Analyzes the angles between adjacent faces at each edge to determine
    /// whether each edge is convex, concave, or tangent.
    ///
    /// - Parameter angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Array of (edge, concavity) pairs, or nil on error
    public func edgeConcavities(angle: Double = 0.01) -> [(Edge, EdgeConcavity)]? {
        let count = edgeCount
        guard count > 0 else { return nil }

        var outTypes = [OCCTEdgeConcavity](repeating: OCCTEdgeConcavity(type: OCCTConcavityConvex),
                                            count: count)
        let classified = OCCTShapeAnalyzeEdgeConcavity(handle, angle, &outTypes, Int32(count))
        guard classified > 0 else { return nil }

        var result = [(Edge, EdgeConcavity)]()
        result.reserveCapacity(Int(classified))

        let allEdges = edges()
        for i in 0..<min(Int(classified), allEdges.count) {
            let concavity: EdgeConcavity
            switch outTypes[i].type {
            case OCCTConcavityConvex: concavity = .convex
            case OCCTConcavityConcave: concavity = .concave
            case OCCTConcavityTangent: concavity = .tangent
            default: concavity = .tangent
            }
            result.append((allEdges[i], concavity))
        }
        return result
    }

    /// Count edges of a specific concavity type.
    ///
    /// - Parameters:
    ///   - type: Concavity type to count
    ///   - angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Number of edges of the specified type, or nil on error
    public func edgeConcavityCount(_ type: EdgeConcavity, angle: Double = 0.01) -> Int? {
        let typeValue: Int32
        switch type {
        case .convex: typeValue = 0
        case .concave: typeValue = 1
        case .tangent: typeValue = 2
        }
        let count = OCCTShapeCountEdgeConcavity(handle, angle, typeValue)
        return count >= 0 ? Int(count) : nil
    }

    // MARK: - Geometric Edge Selection (v1.2.1)

    /// Select edges of this shape that satisfy a geometric predicate.
    ///
    /// This is the robust alternative to picking edges by raw index from
    /// ``edges()`` — the index shifts as soon as the model parameters change,
    /// whereas a geometric predicate keeps selecting the right edge. The returned
    /// edges carry their parent index, so they feed straight into
    /// ``filleted(edges:radius:)`` / ``chamferedTwoDistances(_:)`` etc.
    ///
    /// ```swift
    /// // Round only the long edges (> 50 mm) of a bracket
    /// let rounded = bracket.filleted(edges: bracket.edges { $0.length > 50 }, radius: 2)
    /// ```
    ///
    /// - Parameter predicate: Returns true for edges to keep.
    /// - Returns: The matching edges (possibly empty), each with a valid index.
    public func edges(where predicate: (Edge) -> Bool) -> [Edge] {
        edges().filter(predicate)
    }

    /// The concave edges of this solid (interior angle > 180°, e.g. the inside
    /// corner of an L-bracket or the bottom of a groove).
    ///
    /// These are the edges you usually want to *fillet* — a concave fillet adds
    /// material to soften an inside corner. Selecting them geometrically avoids the
    /// fragile "iterate `edges()` and guess the index" workaround.
    ///
    /// ```swift
    /// let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
    /// ```
    ///
    /// - Parameter angle: Threshold (radians) below which an edge counts as tangent
    ///   rather than concave (default 0.01).
    /// - Returns: The concave edges, or an empty array if none / on error.
    public func concaveEdges(angle: Double = 0.01) -> [Edge] {
        (edgeConcavities(angle: angle) ?? []).compactMap { $0.1 == .concave ? $0.0 : nil }
    }

    /// The convex edges of this solid (interior angle < 180°, e.g. the outer
    /// corners of a box).
    ///
    /// These are the edges you usually want to *chamfer* or round on the outside of
    /// a part.
    ///
    /// - Parameter angle: Threshold (radians) below which an edge counts as tangent
    ///   rather than convex (default 0.01).
    /// - Returns: The convex edges, or an empty array if none / on error.
    public func convexEdges(angle: Double = 0.01) -> [Edge] {
        (edgeConcavities(angle: angle) ?? []).compactMap { $0.1 == .convex ? $0.0 : nil }
    }

    /// Select straight edges whose direction is parallel to the given axis.
    ///
    /// Only line edges are considered (curved edges have no single direction). The
    /// test is sign-agnostic: an edge pointing along `+axis` or `-axis` both match.
    ///
    /// ```swift
    /// // Round every vertical edge of an extruded prism
    /// let rounded = part.filleted(edges: part.edges(parallelTo: SIMD3(0, 0, 1)), radius: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - axis: The reference direction (need not be unit length).
    ///   - tolerance: Maximum sine of the angle between edge and axis (default 1e-4).
    /// - Returns: The matching straight edges, each with a valid index.
    public func edges(parallelTo axis: SIMD3<Double>, tolerance: Double = 1e-4) -> [Edge] {
        let axisLen = simd_length(axis)
        guard axisLen > 0 else { return [] }
        let a = axis / axisLen
        return edges().filter { edge in
            guard edge.isLine else { return false }
            let (start, end) = edge.endpoints
            let d = end - start
            let len = simd_length(d)
            guard len > 0 else { return false }
            // |cross| = sin(theta) for unit vectors; parallel when ~0.
            return simd_length(simd_cross(d / len, a)) <= tolerance
        }
    }

    /// Select edges fully contained within an axis-aligned bounding region.
    ///
    /// An edge matches when its entire bounding box lies inside the box spanned by
    /// `min`...`max` (inclusive). Useful for fillets that should only touch a
    /// localised region of an already-built solid.
    ///
    /// - Parameters:
    ///   - min: The lower corner of the region.
    ///   - max: The upper corner of the region.
    /// - Returns: The contained edges, each with a valid index.
    public func edges(inBounds min: SIMD3<Double>, _ max: SIMD3<Double>) -> [Edge] {
        let lo = simd_min(min, max)
        let hi = simd_max(min, max)
        return edges().filter { edge in
            let b = edge.bounds
            return all(b.min .>= lo) && all(b.max .<= hi)
        }
    }

    // MARK: - Local Prism (v0.46.0)

    /// Create a local prism (extrusion) from this shape along a direction.
    ///
    /// Uses LocOpe_Prism which tracks generated shapes for each input sub-shape,
    /// providing more detailed operation history than standard extrusion.
    ///
    /// - Parameter direction: Direction and distance of extrusion
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpePrism(handle, direction.x, direction.y, direction.z) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a local prism with an additional translation.
    ///
    /// - Parameters:
    ///   - direction: Primary direction and distance of extrusion
    ///   - translation: Secondary translation vector
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>, translation: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpePrismWithTranslation(
            handle, direction.x, direction.y, direction.z,
            translation.x, translation.y, translation.z
        ) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - Volume Inertia Properties (v0.46.0)

    /// Volume inertia properties of a solid shape.
    public struct VolumeInertia: Sendable {
        /// Volume of the shape
        public let volume: Double
        /// Center of mass
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major)
        public let inertiaTensor: [Double]
        /// Principal moments of inertia (sorted)
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (3 unit vectors)
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Radii of gyration about principal axes
        public let gyrationRadii: SIMD3<Double>
    }

    /// Compute volume inertia properties of this shape.
    ///
    /// Returns volume, center of mass, inertia tensor, principal moments
    /// and axes of inertia, and radii of gyration.
    ///
    /// - Returns: Volume inertia result, or nil on error
    public var volumeInertia: VolumeInertia? {
        var result = OCCTVolumeInertiaResult()
        guard OCCTShapeVolumeInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return VolumeInertia(
            volume: result.volume,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(result.principalMoment1, result.principalMoment2, result.principalMoment3),
            principalAxes: (
                SIMD3(result.axis1X, result.axis1Y, result.axis1Z),
                SIMD3(result.axis2X, result.axis2Y, result.axis2Z),
                SIMD3(result.axis3X, result.axis3Y, result.axis3Z)
            ),
            gyrationRadii: SIMD3(result.gyrationRadius1, result.gyrationRadius2, result.gyrationRadius3)
        )
    }

    /// Surface inertia properties of a shape.
    public struct SurfaceInertia: Sendable {
        /// Total surface area
        public let area: Double
        /// Center of mass of the surface
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major)
        public let inertiaTensor: [Double]
        /// Principal moments of inertia
        public let principalMoments: SIMD3<Double>
    }

    /// Compute surface (area) inertia properties of this shape.
    ///
    /// - Returns: Surface inertia result, or nil on error
    public var surfaceInertia: SurfaceInertia? {
        var result = OCCTSurfaceInertiaResult()
        guard OCCTShapeSurfaceInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return SurfaceInertia(
            area: result.area,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(result.principalMoment1, result.principalMoment2, result.principalMoment3)
        )
    }
}

// MARK: - Local Revolution (v0.47.0)

extension Shape {
    /// Create a revolved shape by rotating a profile around an axis.
    ///
    /// Uses LocOpe_Revol for local revolution operations with shape tracking.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    /// - Returns: Revolved shape, or nil on failure
    public func localRevolution(axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 angle: Double) -> Shape? {
        guard let ref = OCCTLocOpeRevol(handle,
                                         axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                         axisDirection.x, axisDirection.y, axisDirection.z,
                                         angle) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a revolved shape with angular offset.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    ///   - angularOffset: Angular offset for positioning in radians
    /// - Returns: Revolved shape, or nil on failure
    public func localRevolution(axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 angle: Double,
                                 angularOffset: Double) -> Shape? {
        guard let ref = OCCTLocOpeRevolWithOffset(handle,
                                                   axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                   axisDirection.x, axisDirection.y, axisDirection.z,
                                                   angle, angularOffset) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - Draft Prism (v0.47.0)

extension Face {
    /// Create a draft prism (tapered extrusion) from this face.
    ///
    /// Uses LocOpe_DPrism for creating tapered extrusions with different
    /// heights on each end and a draft angle.
    ///
    /// - Parameters:
    ///   - height1: First height
    ///   - height2: Second height
    ///   - angle: Draft angle in radians
    /// - Returns: Draft prism shape, or nil on failure
    public func draftPrism(height1: Double, height2: Double, angle: Double) -> Shape? {
        guard let ref = OCCTLocOpeDPrism(handle, height1, height2, angle) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a draft prism with single height.
    ///
    /// - Parameters:
    ///   - height: Extrusion height
    ///   - angle: Draft angle in radians
    /// - Returns: Draft prism shape, or nil on failure
    public func draftPrism(height: Double, angle: Double) -> Shape? {
        guard let ref = OCCTLocOpeDPrismSingleHeight(handle, height, angle) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - Constrained Filling (v0.47.0)

extension Shape {
    /// Information about a constrained-fill BSpline surface
    public struct ConstrainedFillInfo: Sendable {
        /// U-direction BSpline degree
        public let uDegree: Int
        /// V-direction BSpline degree
        public let vDegree: Int
        /// Number of control points in U
        public let uPoles: Int
        /// Number of control points in V
        public let vPoles: Int
    }

    /// Create a surface by filling a region bounded by 3 or 4 edge curves.
    ///
    /// Uses GeomFill_ConstrainedFilling to create a BSpline surface that
    /// interpolates the given boundary curves.
    ///
    /// - Parameters:
    ///   - edge1: First boundary edge
    ///   - edge2: Second boundary edge
    ///   - edge3: Third boundary edge
    ///   - edge4: Optional fourth boundary edge (nil for 3-sided fill)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum number of segments (default 15)
    /// - Returns: Face shape built on the filled surface, or nil on failure
    public static func constrainedFill(edge1: Edge, edge2: Edge, edge3: Edge,
                                        edge4: Edge? = nil,
                                        maxDegree: Int = 8,
                                        maxSegments: Int = 15) -> Shape? {
        guard let ref = OCCTGeomFillConstrained(edge1.handle, edge2.handle,
                                                 edge3.handle, edge4?.handle,
                                                 Int32(maxDegree), Int32(maxSegments)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get BSpline surface info from a constrained fill result.
    ///
    /// - Returns: Surface info (degrees, pole counts), or nil if not a BSpline surface
    public var constrainedFillInfo: ConstrainedFillInfo? {
        var info = OCCTConstrainedFillingInfo()
        guard OCCTGeomFillConstrainedInfo(handle, &info), info.isValid else { return nil }
        return ConstrainedFillInfo(
            uDegree: Int(info.uDegree),
            vDegree: Int(info.vDegree),
            uPoles: Int(info.uPoles),
            vPoles: Int(info.vPoles)
        )
    }
}

// MARK: - Shape Validity Checking (v0.47.0)

extension Shape {
    /// Shape check error status codes
    public enum CheckStatus: Int32, Sendable, CaseIterable {
        case noError = 0
        case invalidPointOnCurve = 1
        case invalidPointOnCurveOnSurface = 2
        case invalidPointOnSurface = 3
        case no3DCurve = 4
        case multiple3DCurve = 5
        case invalid3DCurve = 6
        case noCurveOnSurface = 7
        case invalidCurveOnSurface = 8
        case invalidCurveOnClosedSurface = 9
        case invalidSameRangeFlag = 10
        case invalidSameParameterFlag = 11
        case invalidDegeneratedFlag = 12
        case freeEdge = 13
        case invalidMultiConnexity = 14
        case invalidRange = 15
        case emptyWire = 16
        case redundantEdge = 17
        case selfIntersectingWire = 18
        case noSurface = 19
        case invalidWire = 20
        case redundantWire = 21
        case intersectingWires = 22
        case invalidImbricationOfWires = 23
        case emptyShell = 24
        case redundantFace = 25
        case invalidImbricationOfShells = 26
        case unorientableShape = 27
        case notClosed = 28
        case notConnected = 29
        case subshapeNotInShape = 30
        case badOrientation = 31
        case badOrientationOfSubshape = 32
        case invalidPolygonOnTriangulation = 33
        case invalidToleranceValue = 34
        case enclosedRegion = 35
        case checkFail = 36
    }

    /// Result of a shape validity check
    public struct CheckResult: Sendable {
        /// Whether the shape is valid (no errors)
        public let isValid: Bool
        /// Number of errors found
        public let errorCount: Int
        /// First error status (if any)
        public let firstError: CheckStatus?
    }

    /// Check the overall validity of this shape.
    ///
    /// Uses BRepCheck_Analyzer for comprehensive topology and geometry validation.
    ///
    /// - Returns: Check result with validity status and error details
    public var checkResult: CheckResult {
        let result = OCCTCheckShape(handle)
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Get detailed error status codes for this shape.
    ///
    /// Returns all individual error codes found during validation,
    /// useful for diagnosing exactly what's wrong with an invalid shape.
    ///
    /// - Returns: Array of check status codes
    public var detailedCheckStatuses: [CheckStatus] {
        var buffer = [OCCTCheckStatus](repeating: .init(rawValue: 0), count: 256)
        let count = OCCTCheckShapeDetailed(handle, &buffer, 256)
        guard count > 0 else { return [] }
        return (0..<Int(count)).compactMap { i in
            CheckStatus(rawValue: Int32(buffer[i].rawValue))
        }
    }
}

// MARK: - Face Validity Checking (v0.47.0)

extension Face {
    /// Check the validity of this face using BRepCheck_Face.
    ///
    /// Uses BRepCheck_Face for face-specific validation including
    /// wire intersection checks, surface validity, etc.
    ///
    /// - Returns: Check result
    public var faceCheckResult: Shape.CheckResult {
        let result = OCCTCheckFace(handle)
        let status = Shape.CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return Shape.CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }
}

// MARK: - Local Operations, Validation, Fixing, Extrema (v0.48.0)

extension Shape {
    // MARK: - LocOpe_Pipe

    /// Perform a pipe sweep of this shape along a wire spine with shape tracking.
    ///
    /// Uses LocOpe_Pipe to sweep a face profile along a wire path.
    /// Unlike the regular pipe sweep, this tracks generated sub-shapes.
    ///
    /// - Parameter spine: Wire spine to sweep along
    /// - Returns: The swept shape, or nil on failure
    public func localPipe(along spine: Wire) -> Shape? {
        let spineShape = Shape(handle: OCCTShapeFromWire(spine.handle))
        guard let ref = OCCTLocOpePipe(handle, spineShape.handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_LinearForm

    /// Perform a linear form (translation sweep) of this shape with shape tracking.
    ///
    /// Uses LocOpe_LinearForm to sweep a face along a direction vector.
    ///
    /// - Parameters:
    ///   - direction: Direction vector of the sweep
    ///   - from: Start point of the sweep
    ///   - to: End point of the sweep
    /// - Returns: The swept shape, or nil on failure
    public func localLinearForm(direction: SIMD3<Double>,
                                from start: SIMD3<Double>,
                                to end: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpeLinearForm(handle,
                                              direction.x, direction.y, direction.z,
                                              start.x, start.y, start.z,
                                              end.x, end.y, end.z) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_RevolutionForm

    /// Perform a revolution form of this shape with shape tracking.
    ///
    /// Uses LocOpe_RevolutionForm to revolve a face around an axis.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    /// - Returns: The revolved shape, or nil on failure
    public func localRevolutionForm(axisOrigin: SIMD3<Double>,
                                     axisDirection: SIMD3<Double>,
                                     angle: Double) -> Shape? {
        guard let ref = OCCTLocOpeRevolutionForm(handle,
                                                  axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                  axisDirection.x, axisDirection.y, axisDirection.z,
                                                  angle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_SplitShape

    /// Split a face of this shape by adding a wire on it.
    ///
    /// Uses LocOpe_SplitShape to split a face into multiple parts.
    ///
    /// - Parameters:
    ///   - faceIndex: Index of the face to split (0-based)
    ///   - wire: Wire that lies on the face and defines the split
    /// - Returns: Modified shape with the face split, or nil on failure
    public func splitFace(at faceIndex: Int, with wire: Wire) -> Shape? {
        let wireShape = Shape(handle: OCCTShapeFromWire(wire.handle))
        guard let ref = OCCTLocOpeSplitShapeByWire(handle, Int32(faceIndex), wireShape.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Split an edge of this shape at a parameter.
    ///
    /// Uses LocOpe_SplitShape to split an edge by inserting a vertex.
    ///
    /// - Parameters:
    ///   - edgeIndex: Index of the edge to split (0-based)
    ///   - parameter: Parameter along the edge (0.0 to 1.0)
    /// - Returns: The split edge parts as a compound, or nil on failure
    public func splitEdge(at edgeIndex: Int, parameter: Double) -> Shape? {
        guard let ref = OCCTLocOpeSplitShapeByVertex(handle, Int32(edgeIndex), parameter) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_SplitDrafts

    /// Split a face with draft angles on both sides of a wire.
    ///
    /// Uses LocOpe_SplitDrafts to create draft surfaces on a shape.
    ///
    /// - Parameters:
    ///   - faceIndex: Index of the face to split (0-based)
    ///   - wire: Wire defining the split line
    ///   - direction: Extraction direction
    ///   - planeOrigin: Origin of the neutral plane
    ///   - planeNormal: Normal of the neutral plane
    ///   - angle: Draft angle in radians
    /// - Returns: Modified shape with draft, or nil on failure
    public func splitDrafts(faceIndex: Int, wire: Wire,
                            direction: SIMD3<Double>,
                            planeOrigin: SIMD3<Double>,
                            planeNormal: SIMD3<Double>,
                            angle: Double) -> Shape? {
        let wireShape = Shape(handle: OCCTShapeFromWire(wire.handle))
        guard let ref = OCCTLocOpeSplitDrafts(handle, Int32(faceIndex), wireShape.handle,
                                               direction.x, direction.y, direction.z,
                                               planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                               planeNormal.x, planeNormal.y, planeNormal.z,
                                               angle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_FindEdges

    /// Find edges in common between this shape and another.
    ///
    /// Uses LocOpe_FindEdges to identify shared edges.
    ///
    /// - Parameter other: Shape to compare with
    /// - Returns: Array of common edges
    public func commonEdges(with other: Shape) -> [Edge] {
        var buffer = [OCCTShapeRef?](repeating: nil, count: 100)
        let count = OCCTLocOpeFindEdges(handle, other.handle, &buffer, 100)
        var edges = [Edge]()
        edges.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = buffer[i] {
                // Convert shape to edge
                if let edgeRef = OCCTShapeGetEdgeAtIndex(ref, 0) {
                    edges.append(Edge(handle: edgeRef, index: i))
                }
                OCCTShapeRelease(ref)
            }
        }
        return edges
    }

    // MARK: - LocOpe_FindEdgesInFace

    /// Find edges of this shape that lie in a specific face.
    ///
    /// Uses LocOpe_FindEdgesInFace.
    ///
    /// - Parameter faceIndex: Index of the face to check (0-based)
    /// - Returns: Array of edges found in the face
    public func edgesInFace(at faceIndex: Int) -> [Edge] {
        var buffer = [OCCTShapeRef?](repeating: nil, count: 100)
        let count = OCCTLocOpeFindEdgesInFace(handle, Int32(faceIndex), &buffer, 100)
        var edges = [Edge]()
        edges.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = buffer[i] {
                if let edgeRef = OCCTShapeGetEdgeAtIndex(ref, 0) {
                    edges.append(Edge(handle: edgeRef, index: i))
                }
                OCCTShapeRelease(ref)
            }
        }
        return edges
    }

    // MARK: - LocOpe_CSIntersector

    /// Result of a curve-shape intersection
    public struct CSIntersection: Sendable {
        /// Intersection point
        public let point: SIMD3<Double>
        /// Parameter on the curve
        public let parameter: Double
        /// UV parameters on the intersected face
        public let faceUV: SIMD2<Double>
    }

    /// Intersect a line with this shape to find intersection points.
    ///
    /// Uses LocOpe_CSIntersector to find where a line penetrates the shape.
    ///
    /// - Parameters:
    ///   - origin: Line origin
    ///   - direction: Line direction
    /// - Returns: Array of intersection points
    public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>) -> [CSIntersection] {
        var buffer = [OCCTCSIntersectionPoint](repeating: OCCTCSIntersectionPoint(), count: 100)
        let count = OCCTLocOpeCSIntersectLine(handle,
                                               origin.x, origin.y, origin.z,
                                               direction.x, direction.y, direction.z,
                                               &buffer, 100)
        var results = [CSIntersection]()
        results.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let pt = buffer[i]
            results.append(CSIntersection(
                point: SIMD3(pt.px, pt.py, pt.pz),
                parameter: pt.parameter,
                faceUV: SIMD2(pt.uOnFace, pt.vOnFace)
            ))
        }
        return results
    }

    // MARK: - BRepCheck_Analyzer

    /// Perform comprehensive validity analysis on this shape.
    ///
    /// Uses BRepCheck_Analyzer for full topology + geometry validation.
    /// More thorough than `isValid` as it can include geometry checks.
    ///
    /// - Parameter geometryChecks: Whether to include geometry-level checks (default: true)
    /// - Returns: true if the shape is valid
    public func analyzeValidity(geometryChecks: Bool = true) -> Bool {
        OCCTBRepCheckAnalyzerIsValid(handle, geometryChecks)
    }

    /// Check if a specific sub-shape is valid within this shape's context.
    ///
    /// - Parameters:
    ///   - type: Type of sub-shape to check
    ///   - index: 0-based index of the sub-shape
    /// - Returns: true if the sub-shape is valid
    public func isSubShapeValid(type: TopAbs_ShapeEnum, at index: Int) -> Bool {
        OCCTBRepCheckSubShapeValid(handle, type.rawValue, Int32(index))
    }

    /// TopAbs_ShapeEnum for sub-shape type specification
    public enum TopAbs_ShapeEnum: Int32, Sendable {
        case compound = 0, compsolid = 1, solid = 2, shell = 3
        case face = 4, wire = 5, edge = 6, vertex = 7
    }

    // MARK: - BRepCheck per sub-shape type

    /// Check validity of an edge by index.
    public func checkEdge(at index: Int) -> CheckResult {
        let result = OCCTCheckEdge(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a wire by index.
    public func checkWire(at index: Int) -> CheckResult {
        let result = OCCTCheckWire(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a shell by index.
    public func checkShell(at index: Int) -> CheckResult {
        let result = OCCTCheckShell(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a vertex by index.
    public func checkVertex(at index: Int) -> CheckResult {
        let result = OCCTCheckVertex(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    // MARK: - ShapeFix_ShapeTolerance

    /// Limit all tolerances in this shape to a given range.
    ///
    /// - Parameters:
    ///   - min: Minimum tolerance
    ///   - max: Maximum tolerance
    /// - Returns: true if any tolerance was changed
    @discardableResult
    public func limitTolerance(min: Double, max: Double) -> Bool {
        OCCTShapeFixLimitTolerance(handle, min, max)
    }

    /// Set all tolerances in this shape to a specific value.
    ///
    /// - Parameter tolerance: Tolerance value to set
    public func setTolerance(_ tolerance: Double) {
        OCCTShapeFixSetTolerance(handle, tolerance)
    }

    // MARK: - ShapeFix_SplitCommonVertex

    /// Split vertices that are shared between edges in incompatible ways.
    ///
    /// Useful for fixing topology issues where vertices are improperly shared.
    ///
    /// - Returns: Fixed shape, or nil on failure
    public func splitCommonVertices() -> Shape? {
        guard let ref = OCCTShapeFixSplitCommonVertex(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeFix_FaceConnect

    /// Connect adjacent faces in this shape's shell.
    ///
    /// - Parameter tolerance: Connection tolerance
    /// - Returns: Fixed shape with connected faces, or nil on failure
    public func connectedFaces(tolerance: Double = 1e-4) -> Shape? {
        guard let ref = OCCTShapeFixFaceConnect(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeFix_Edge

    /// Fix same-parameter inconsistencies on all edges.
    ///
    /// - Parameter tolerance: Tolerance for fixing (0 = default)
    /// - Returns: Number of edges fixed
    @discardableResult
    public func fixEdgeSameParameter(tolerance: Double = 0) -> Int {
        Int(OCCTShapeFixEdgeSameParameter(handle, tolerance))
    }

    /// Fix vertex tolerance issues on all edges.
    ///
    /// - Returns: Number of edges fixed
    @discardableResult
    public func fixEdgeVertexTolerance() -> Int {
        Int(OCCTShapeFixEdgeVertexTolerance(handle))
    }

    // MARK: - ShapeFix_WireVertex

    /// Fix vertex issues in all wires of this shape.
    ///
    /// - Parameter precision: Precision for fixing
    /// - Returns: Number of fixes applied
    @discardableResult
    public func fixWireVertices(precision: Double = 1e-4) -> Int {
        Int(OCCTShapeFixWireVertex(handle, precision))
    }

    // MARK: - BRepExtrema_ExtCC (Edge-Edge Extrema)

    /// Result of edge-edge distance extrema computation
    public struct EdgeEdgeExtrema: Sendable {
        /// Minimum distance between the edges
        public let distance: Double
        /// Parameter on the first edge at closest point
        public let paramOnEdge1: Double
        /// Parameter on the second edge at closest point
        public let paramOnEdge2: Double
        /// Closest point on edge 1
        public let pointOnEdge1: SIMD3<Double>
        /// Closest point on edge 2
        public let pointOnEdge2: SIMD3<Double>
        /// Whether the edges are parallel
        public let isParallel: Bool
        /// Number of extrema solutions
        public let solutionCount: Int
    }

    /// Compute distance extrema between two edges by index.
    ///
    /// Uses BRepExtrema_ExtCC for edge-edge distance computation.
    ///
    /// - Parameters:
    ///   - edgeIndex1: Index of first edge in this shape (0-based)
    ///   - other: Shape containing the second edge
    ///   - edgeIndex2: Index of second edge in other shape (0-based)
    /// - Returns: Edge-edge extrema result, or nil on failure
    public func edgeEdgeExtrema(edgeIndex1: Int, other: Shape, edgeIndex2: Int) -> EdgeEdgeExtrema? {
        let result = OCCTBRepExtremaExtCC(handle, Int32(edgeIndex1), other.handle, Int32(edgeIndex2))
        guard result.solutionCount > 0 else { return nil }
        return EdgeEdgeExtrema(
            distance: result.distance,
            paramOnEdge1: result.paramOnE1,
            paramOnEdge2: result.paramOnE2,
            pointOnEdge1: SIMD3(result.pt1x, result.pt1y, result.pt1z),
            pointOnEdge2: SIMD3(result.pt2x, result.pt2y, result.pt2z),
            isParallel: result.isParallel,
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtPF (Point-Face Extrema)

    /// Result of point-face distance extrema computation
    public struct PointFaceExtrema: Sendable {
        /// Minimum distance from point to face
        public let distance: Double
        /// UV parameters on the face at closest point
        public let faceUV: SIMD2<Double>
        /// Closest point on the face
        public let pointOnFace: SIMD3<Double>
        /// Number of extrema solutions
        public let solutionCount: Int
    }

    /// Compute distance from a point to a face.
    ///
    /// Uses BRepExtrema_ExtPF for point-face distance computation.
    ///
    /// - Parameters:
    ///   - point: 3D point
    ///   - faceIndex: Index of face in this shape (0-based)
    /// - Returns: Point-face extrema result, or nil on failure
    public func pointFaceExtrema(point: SIMD3<Double>, faceIndex: Int) -> PointFaceExtrema? {
        let result = OCCTBRepExtremaExtPF(point.x, point.y, point.z, handle, Int32(faceIndex))
        guard result.solutionCount > 0 else { return nil }
        return PointFaceExtrema(
            distance: result.distance,
            faceUV: SIMD2(result.u, result.v),
            pointOnFace: SIMD3(result.ptx, result.pty, result.ptz),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtFF (Face-Face Extrema)

    /// Result of face-face distance extrema computation
    public struct FaceFaceExtrema: Sendable {
        /// Minimum distance between faces
        public let distance: Double
        /// UV parameters on face 1
        public let face1UV: SIMD2<Double>
        /// UV parameters on face 2
        public let face2UV: SIMD2<Double>
        /// Closest point on face 1
        public let pointOnFace1: SIMD3<Double>
        /// Closest point on face 2
        public let pointOnFace2: SIMD3<Double>
        /// Number of extrema solutions
        public let solutionCount: Int
    }

    /// Compute distance extrema between two faces.
    ///
    /// Uses BRepExtrema_ExtFF for face-face distance computation.
    ///
    /// - Parameters:
    ///   - faceIndex1: Index of first face in this shape (0-based)
    ///   - other: Shape containing the second face
    ///   - faceIndex2: Index of second face in other shape (0-based)
    /// - Returns: Face-face extrema result, or nil on failure
    public func faceFaceExtrema(faceIndex1: Int, other: Shape, faceIndex2: Int) -> FaceFaceExtrema? {
        let result = OCCTBRepExtremaExtFF(handle, Int32(faceIndex1), other.handle, Int32(faceIndex2))
        guard result.solutionCount > 0 else { return nil }
        return FaceFaceExtrema(
            distance: result.distance,
            face1UV: SIMD2(result.u1, result.v1),
            face2UV: SIMD2(result.u2, result.v2),
            pointOnFace1: SIMD3(result.pt1x, result.pt1y, result.pt1z),
            pointOnFace2: SIMD3(result.pt2x, result.pt2y, result.pt2z),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - ShapeUpgrade_ShapeDivideClosed

    /// Divide closed faces in this shape.
    ///
    /// Uses ShapeUpgrade_ShapeDivideClosed to split faces that
    /// wrap around completely (e.g., cylinder lateral face).
    ///
    /// - Parameter splitPoints: Number of split points per closed face (default: 1)
    /// - Returns: Shape with divided faces, or nil on failure
    public func dividedClosedFaces(splitPoints: Int = 1) -> Shape? {
        guard let ref = OCCTShapeUpgradeDivideClosed(handle, Int32(splitPoints)) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ShapeDivideContinuity

    /// Continuity level for shape division
    public enum ContinuityLevel: Int32, Sendable {
        case c0 = 0, c1 = 1, c2 = 2, c3 = 3, cn = 4, g1 = 5, g2 = 6
    }

    /// Divide this shape at continuity breaks.
    ///
    /// Uses ShapeUpgrade_ShapeDivideContinuity to split faces/edges
    /// at points where the geometry drops below the required continuity.
    ///
    /// - Parameters:
    ///   - criterion: Minimum required continuity level (default: .c1)
    ///   - tolerance: Tolerance for continuity check (default: 1e-4)
    /// - Returns: Divided shape, or nil if no divisions needed or on failure
    public func dividedByContinuity(criterion: ContinuityLevel = .c1, tolerance: Double = 1e-4) -> Shape? {
        guard let ref = OCCTShapeUpgradeDivideContinuity(handle, criterion.rawValue, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BRepExtrema_ExtPC (Point-Edge Extrema)

    /// Result of point-edge distance extrema computation
    public struct PointEdgeExtrema: Sendable {
        /// Minimum distance from the point to the edge
        public let distance: Double
        /// Parameter on edge at closest point
        public let parameter: Double
        /// Closest point on edge
        public let pointOnEdge: SIMD3<Double>
        /// Number of extrema solutions found
        public let solutionCount: Int
    }

    /// Compute minimum distance from a point to an edge of this shape.
    ///
    /// Uses BRepExtrema_ExtPC to find the closest point on the specified edge.
    ///
    /// - Parameters:
    ///   - point: 3D point
    ///   - edgeIndex: 0-based edge index
    /// - Returns: Extrema result, or nil if computation fails
    public func pointEdgeExtrema(point: SIMD3<Double>, edgeIndex: Int) -> PointEdgeExtrema? {
        let result = OCCTBRepExtremaExtPC(point.x, point.y, point.z, handle, Int32(edgeIndex))
        guard result.solutionCount > 0 else { return nil }
        return PointEdgeExtrema(
            distance: result.distance,
            parameter: result.parameter,
            pointOnEdge: SIMD3(result.ptx, result.pty, result.ptz),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtCF (Edge-Face Extrema)

    /// Result of edge-face distance extrema computation
    public struct EdgeFaceExtrema: Sendable {
        /// Minimum distance between edge and face
        public let distance: Double
        /// Parameter on edge at closest point
        public let paramOnEdge: Double
        /// UV parameters on face at closest point
        public let faceUV: SIMD2<Double>
        /// Closest point on edge
        public let pointOnEdge: SIMD3<Double>
        /// Closest point on face
        public let pointOnFace: SIMD3<Double>
        /// Whether edge and face are parallel
        public let isParallel: Bool
        /// Number of extrema solutions found
        public let solutionCount: Int
    }

    /// Compute distance extrema between an edge and a face.
    ///
    /// Uses BRepExtrema_ExtCF to find the closest points between
    /// the specified edge of this shape and a face of another shape.
    ///
    /// - Parameters:
    ///   - edgeIndex: 0-based edge index in this shape
    ///   - other: Shape containing the face
    ///   - faceIndex: 0-based face index in the other shape
    /// - Returns: Extrema result, or nil if parallel or computation fails
    public func edgeFaceExtrema(edgeIndex: Int, other: Shape, faceIndex: Int) -> EdgeFaceExtrema? {
        let result = OCCTBRepExtremaExtCF(handle, Int32(edgeIndex), other.handle, Int32(faceIndex))
        if result.isParallel {
            return EdgeFaceExtrema(
                distance: 0, paramOnEdge: 0, faceUV: .zero,
                pointOnEdge: .zero, pointOnFace: .zero,
                isParallel: true, solutionCount: 0
            )
        }
        guard result.solutionCount > 0 else { return nil }
        return EdgeFaceExtrema(
            distance: result.distance,
            paramOnEdge: result.paramOnEdge,
            faceUV: SIMD2(result.uOnFace, result.vOnFace),
            pointOnEdge: SIMD3(result.edgePtx, result.edgePty, result.edgePtz),
            pointOnFace: SIMD3(result.facePtx, result.facePty, result.facePtz),
            isParallel: false,
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - ShapeFix_FixSmallSolid

    /// Remove small solids from this shape based on volume threshold.
    ///
    /// Solids with volume below the threshold are removed entirely.
    ///
    /// - Parameter volumeThreshold: Volume below which solids are removed
    /// - Returns: Shape with small solids removed, or nil on failure
    public func removeSmallSolids(volumeThreshold: Double) -> Shape? {
        guard let ref = OCCTShapeFixRemoveSmallSolids(handle, volumeThreshold) else { return nil }
        return Shape(handle: ref)
    }

    /// Merge small solids into adjacent larger solids.
    ///
    /// Small solids are merged into their neighbors rather than removed.
    ///
    /// - Parameter widthFactorThreshold: Width factor below which solids are merged
    /// - Returns: Shape with small solids merged, or nil on failure
    public func mergeSmallSolids(widthFactorThreshold: Double) -> Shape? {
        guard let ref = OCCTShapeFixMergeSmallSolids(handle, widthFactorThreshold) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeCustom

    /// Continuity for BSpline restriction
    public enum BSplineContinuity: Int32, Sendable {
        case c0 = 0, c1 = 1, c2 = 2, c3 = 3
    }

    /// Simplify BSpline surfaces and curves by restricting degree and segment count.
    ///
    /// Uses ShapeCustom::BSplineRestriction to approximate geometry with simpler BSplines.
    ///
    /// - Parameters:
    ///   - tol3d: 3D tolerance (default: 0.01)
    ///   - tol2d: 2D tolerance (default: 0.01)
    ///   - maxDegree: Maximum BSpline degree (default: 8)
    ///   - maxSegments: Maximum number of segments (default: 100)
    ///   - continuity3d: 3D continuity requirement (default: .c1)
    ///   - continuity2d: 2D continuity requirement (default: .c1)
    ///   - degreePriority: If true, prioritize degree over segments (default: true)
    ///   - rational: Allow rational BSplines (default: false)
    /// - Returns: Simplified shape, or nil on failure
    public func bsplineRestriction(
        tol3d: Double = 0.01, tol2d: Double = 0.01,
        maxDegree: Int = 8, maxSegments: Int = 100,
        continuity3d: BSplineContinuity = .c1, continuity2d: BSplineContinuity = .c1,
        degreePriority: Bool = true, rational: Bool = false
    ) -> Shape? {
        guard let ref = OCCTShapeCustomBSplineRestriction(
            handle, tol3d, tol2d, Int32(maxDegree), Int32(maxSegments),
            continuity3d.rawValue, continuity2d.rawValue, degreePriority, rational
        ) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeAnalysis_FreeBoundsProperties

    /// Properties of a single free bound (boundary wire)
    public struct FreeBoundInfo: Sendable {
        /// Area enclosed by the bound
        public let area: Double
        /// Perimeter length
        public let perimeter: Double
        /// Aspect ratio (area / perimeter^2)
        public let ratio: Double
        /// Average width
        public let width: Double
        /// Number of notches
        public let notchCount: Int
    }

    /// Result of free bounds analysis
    public struct FreeBoundsAnalysis: Sendable {
        /// Total number of free bounds
        public let totalCount: Int
        /// Number of closed free bounds
        public let closedCount: Int
        /// Number of open free bounds
        public let openCount: Int
    }

    /// Analyze free bounds (boundary wires) of this shape.
    ///
    /// Free bounds are edges that belong to only one face. Uses
    /// ShapeAnalysis_FreeBoundsProperties to find and classify them.
    ///
    /// - Parameter tolerance: Sewing tolerance for finding free bounds
    /// - Returns: Analysis summary with bound counts
    public func freeBoundsAnalysis(tolerance: Double) -> FreeBoundsAnalysis {
        let result = OCCTFreeBoundsAnalyze(handle, tolerance)
        return FreeBoundsAnalysis(
            totalCount: Int(result.totalFreeBounds),
            closedCount: Int(result.closedFreeBounds),
            openCount: Int(result.openFreeBounds)
        )
    }

    /// Get properties of a closed free bound.
    ///
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the closed free bound
    /// - Returns: Properties of the bound, or nil if index is out of range
    public func closedFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo? {
        let result = OCCTFreeBoundsGetClosedBoundInfo(handle, tolerance, Int32(index))
        guard result.perimeter > 0 else { return nil }
        return FreeBoundInfo(
            area: result.area, perimeter: result.perimeter,
            ratio: result.ratio, width: result.width,
            notchCount: Int(result.notchCount)
        )
    }

    /// Get properties of an open free bound.
    ///
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the open free bound
    /// - Returns: Properties of the bound, or nil if index is out of range
    public func openFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo? {
        let result = OCCTFreeBoundsGetOpenBoundInfo(handle, tolerance, Int32(index))
        guard result.perimeter > 0 else { return nil }
        return FreeBoundInfo(
            area: result.area, perimeter: result.perimeter,
            ratio: result.ratio, width: result.width,
            notchCount: Int(result.notchCount)
        )
    }

    /// Get the wire shape of a closed free bound.
    ///
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the closed free bound
    /// - Returns: Wire as a Shape, or nil if index is out of range
    public func closedFreeBoundWire(tolerance: Double, index: Int) -> Shape? {
        guard let ref = OCCTFreeBoundsGetClosedBoundWire(handle, tolerance, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the wire shape of an open free bound.
    ///
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the open free bound
    /// - Returns: Wire as a Shape, or nil if index is out of range
    public func openFreeBoundWire(tolerance: Double, index: Int) -> Shape? {
        guard let ref = OCCTFreeBoundsGetOpenBoundWire(handle, tolerance, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - v0.50.0: Polyhedral distance, history tracking, wire vertex analysis, nearest plane

    /// Result of a polyhedral (approximate) distance computation.
    public struct PolyhedralDistance {
        /// Approximate distance between the two shapes
        public let distance: Double
        /// Closest point on the first shape
        public let point1: SIMD3<Double>
        /// Closest point on the second shape
        public let point2: SIMD3<Double>
    }

    /// Compute fast polyhedral (approximate) distance to another shape.
    ///
    /// Both shapes must be meshed (have triangulation). This is faster than exact
    /// distance but less precise.
    ///
    /// - Parameter other: The other shape
    /// - Returns: Distance result, or nil if computation fails
    public func polyhedralDistance(to other: Shape) -> PolyhedralDistance? {
        let result = OCCTShapePolyhedralDistance(handle, other.handle)
        guard result.success else { return nil }
        return PolyhedralDistance(
            distance: result.distance,
            point1: SIMD3(result.p1x, result.p1y, result.p1z),
            point2: SIMD3(result.p2x, result.p2y, result.p2z))
    }

    /// Shape modification history for tracking what happened during operations.
    public class History {
        let historyRef: OCCTHistoryRef

        /// Create an empty history.
        public init?() {
            guard let ref = OCCTHistoryCreate() else { return nil }
            historyRef = ref
        }

        deinit {
            OCCTHistoryDestroy(historyRef)
        }

        /// Record that an initial shape was modified into a new shape.
        public func addModified(initial: Shape, modified: Shape) {
            OCCTHistoryAddModified(historyRef, initial.handle, modified.handle)
        }

        /// Record that an initial shape generated a new shape.
        public func addGenerated(initial: Shape, generated: Shape) {
            OCCTHistoryAddGenerated(historyRef, initial.handle, generated.handle)
        }

        /// Record that a shape was removed.
        public func remove(_ shape: Shape) {
            OCCTHistoryRemove(historyRef, shape.handle)
        }

        /// Check if a shape was recorded as removed.
        public func isRemoved(_ shape: Shape) -> Bool {
            OCCTHistoryIsRemoved(historyRef, shape.handle)
        }

        /// Whether any modifications were recorded.
        public var hasModified: Bool {
            OCCTHistoryHasModified(historyRef)
        }

        /// Whether any generations were recorded.
        public var hasGenerated: Bool {
            OCCTHistoryHasGenerated(historyRef)
        }

        /// Whether any removals were recorded.
        public var hasRemoved: Bool {
            OCCTHistoryHasRemoved(historyRef)
        }

        /// Number of shapes the given initial shape was modified to.
        public func modifiedCount(of shape: Shape) -> Int {
            Int(OCCTHistoryModifiedCount(historyRef, shape.handle))
        }

        /// Number of shapes the given initial shape generated.
        public func generatedCount(of shape: Shape) -> Int {
            Int(OCCTHistoryGeneratedCount(historyRef, shape.handle))
        }
    }

    /// Result of wire vertex analysis.
    public struct WireVertexAnalysis {
        /// Number of edges in the wire
        public let edgeCount: Int
        /// Whether the analysis completed successfully
        public let isDone: Bool
    }

    /// Vertex status codes from wire vertex analysis.
    public enum WireVertexStatus: Int32 {
        case sameVertex = 0
        case sameCoords = 1
        case close = 2
        case end = 3
        case start = 4
        case intersection = 5
        case disjoined = -1
        case unknown = -2
    }

    /// Analyze wire vertex connections for gaps, overlaps, and intersections.
    ///
    /// - Parameter precision: Tolerance for vertex analysis
    /// - Returns: Analysis result with edge count
    public func wireVertexAnalysis(precision: Double = 0.01) -> WireVertexAnalysis {
        let result = OCCTShapeWireVertexAnalysis(handle, precision)
        return WireVertexAnalysis(edgeCount: Int(result.nbEdges), isDone: result.isDone)
    }

    /// Get the status of a specific vertex in a wire.
    ///
    /// - Parameters:
    ///   - precision: Tolerance for vertex analysis
    ///   - index: 0-based vertex index
    /// - Returns: Vertex status
    public func wireVertexStatus(precision: Double = 0.01, index: Int) -> WireVertexStatus {
        let code = OCCTShapeWireVertexStatus(handle, precision, Int32(index))
        return WireVertexStatus(rawValue: code) ?? .unknown
    }

    /// Result of fitting a plane to a set of points.
    public struct NearestPlane {
        /// Normal direction of the fitted plane
        public let normal: SIMD3<Double>
        /// A point on the fitted plane
        public let origin: SIMD3<Double>
        /// Maximum distance from any input point to the fitted plane
        public let maxDeviation: Double
    }

    /// Fit the nearest plane to a set of 3D points.
    ///
    /// Uses least-squares fitting to find the plane that best fits the points.
    ///
    /// - Parameter points: Array of 3D points (minimum 3)
    /// - Returns: Fitted plane with deviation, or nil if fitting fails
    public static func nearestPlane(to points: [SIMD3<Double>]) -> NearestPlane? {
        guard points.count >= 3 else { return nil }
        var flatPoints = [Double]()
        flatPoints.reserveCapacity(points.count * 3)
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }
        let result = OCCTShapeNearestPlane(flatPoints, Int32(points.count))
        guard result.success else { return nil }
        return NearestPlane(
            normal: SIMD3(result.normalX, result.normalY, result.normalZ),
            origin: SIMD3(result.originX, result.originY, result.originZ),
            maxDeviation: result.maxDeviation)
    }

    // MARK: - v0.51.0: BRepLib_MakeSolid, GC transforms, ChFi2d_AnaFilletAlgo

    /// Create a solid from a shell shape using BRepLib_MakeSolid.
    ///
    /// - Parameter shell: A shape containing a shell (e.g., from shellFromSurface)
    /// - Returns: Solid shape, or nil on failure
    public static func solidFromShell(_ shell: Shape) -> Shape? {
        guard let h = OCCTShapeMakeSolidFromShell(shell.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Mirror this shape about a point (point symmetry / inversion).
    ///
    /// - Parameter point: The center point of the point mirror
    /// - Returns: Mirrored shape, or nil on failure
    public func mirroredAboutPoint(_ point: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeMirrorAboutPoint(handle, point.x, point.y, point.z) else { return nil }
        return Shape(handle: h)
    }

    /// Mirror this shape about an axis line.
    ///
    /// - Parameters:
    ///   - origin: A point on the axis
    ///   - direction: Direction of the axis
    /// - Returns: Mirrored shape, or nil on failure
    public func mirroredAboutAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeMirrorAboutAxis(handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z) else { return nil }
        return Shape(handle: h)
    }

    /// Scale this shape about a specific center point.
    ///
    /// Unlike `scaled(by:)` which scales about the origin, this scales about a given point.
    ///
    /// - Parameters:
    ///   - center: Center of scaling
    ///   - factor: Scale factor
    /// - Returns: Scaled shape, or nil on failure
    public func scaledAboutPoint(_ center: SIMD3<Double>, factor: Double) -> Shape? {
        guard let h = OCCTShapeScaleAboutPoint(handle,
            center.x, center.y, center.z, factor) else { return nil }
        return Shape(handle: h)
    }

    /// Translate this shape by the vector from one point to another.
    ///
    /// - Parameters:
    ///   - from: Start point of the translation vector
    ///   - to: End point of the translation vector
    /// - Returns: Translated shape, or nil on failure
    public func translated(from: SIMD3<Double>, to: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeTranslateByPoints(handle,
            from.x, from.y, from.z,
            to.x, to.y, to.z) else { return nil }
        return Shape(handle: h)
    }

    /// Result of a 2D analytical fillet operation.
    public struct AnaFilletResult {
        /// The fillet arc edge
        public let fillet: Shape
        /// Trimmed first edge
        public let edge1: Shape
        /// Trimmed second edge
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
              let e2 = r.edge2 else { return nil }
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
              let s2 = Shape.fromEdge(edge2) else { return nil }
        return anaFillet(edge1: s1, edge2: s2,
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
        return anaFillet(edge1: edges[edgeIndex], edge2: edges[edgeIndex + 1],
                         planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }
}

// MARK: - BRepFill, LocOpe, Healing (v0.52.0)

extension Shape {

    // MARK: - BRepFill_Generator

    /// Create a ruled shell by lofting between multiple wire sections.
    ///
    /// Each pair of adjacent wires generates a ruled surface between them.
    /// Wires should have the same number of edges for best results.
    ///
    /// - Parameter wires: Array of at least 2 wires to loft between
    /// - Returns: Shell shape connecting the wires, or nil on failure
    public static func ruledShell(from wires: [Wire]) -> Shape? {
        guard wires.count >= 2 else { return nil }
        let handles: [OCCTWireRef] = wires.map { $0.handle }
        return handles.withUnsafeBufferPointer { buffer in
            guard let h = OCCTBRepFillGenerator(buffer.baseAddress!, Int32(wires.count)) else {
                return nil
            }
            return Shape(handle: h)
        }
    }

    // MARK: - BRepFill_AdvancedEvolved

    /// Create an evolved solid from a spine wire and profile wire.
    ///
    /// The profile is swept along the spine, creating a solid. The profile is
    /// oriented perpendicular to the spine at each point.
    ///
    /// - Parameters:
    ///   - spine: Wire defining the sweep path
    ///   - profile: Wire defining the cross-section
    ///   - tolerance: Geometric tolerance (default 1e-3)
    ///   - solid: Whether to produce a solid (default true)
    /// - Returns: Evolved shape, or nil on failure
    public static func advancedEvolved(
        spine: Wire, profile: Wire,
        tolerance: Double = 1e-3, solid: Bool = true
    ) -> Shape? {
        guard let h = OCCTBRepFillAdvancedEvolved(
            spine.handle, profile.handle, tolerance, solid) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_OffsetWire

    /// Offset a planar wire on its face.
    ///
    /// Creates a new wire offset from the edges of the given face.
    /// Positive offset expands outward, negative shrinks inward.
    ///
    /// - Parameters:
    ///   - face: Face containing the wire to offset
    ///   - offset: Signed offset distance
    /// - Returns: Offset wire shape, or nil on failure
    public static func offsetWire(face: Face, offset: Double) -> Shape? {
        guard let h = OCCTBRepFillOffsetWire(face.handle, offset) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_Draft

    /// Create a draft surface from a wire along a direction with a taper angle.
    ///
    /// The wire is projected along the given direction for the specified length,
    /// with faces tapered at the given angle from the direction.
    ///
    /// - Parameters:
    ///   - wire: Wire defining the base profile
    ///   - direction: Draft direction
    ///   - angle: Taper angle in radians
    ///   - length: Draft length
    /// - Returns: Draft shape, or nil on failure
    public static func draft(
        wire: Wire, direction: SIMD3<Double>,
        angle: Double, length: Double
    ) -> Shape? {
        guard let h = OCCTBRepFillDraft(
            wire.handle, direction.x, direction.y, direction.z,
            angle, length) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_Pipe

    /// Result of a pipe sweep operation.
    public struct PipeSweepResult {
        /// The swept pipe shape
        public let shape: Shape
        /// Surface approximation error
        public let errorOnSurface: Double
    }

    /// Create a pipe sweep of a profile along a spine with error reporting.
    ///
    /// Sweeps the profile wire along the spine wire using corrected Frenet trihedron.
    ///
    /// - Parameters:
    ///   - spine: Wire defining the sweep path
    ///   - profile: Wire defining the cross-section
    /// - Returns: Pipe result with shape and error metric, or nil on failure
    public static func pipeSweep(spine: Wire, profile: Wire) -> PipeSweepResult? {
        let r = OCCTBRepFillPipe(spine.handle, profile.handle)
        guard let s = r.shape else { return nil }
        return PipeSweepResult(
            shape: Shape(handle: s),
            errorOnSurface: r.errorOnSurface)
    }

    // MARK: - BRepFill_CompatibleWires

    /// Make wires compatible for lofting (same number of edges, aligned).
    ///
    /// Resamples wires so they have the same number of edges and are oriented
    /// consistently, which improves lofting quality.
    ///
    /// - Parameter wires: Array of at least 2 wires to normalize
    /// - Returns: Array of compatible wires, or nil on failure
    public static func compatibleWires(_ wires: [Wire]) -> [Wire]? {
        guard wires.count >= 2 else { return nil }
        let handles: [OCCTWireRef] = wires.map { $0.handle }
        var outHandles = [OCCTWireRef?](repeating: nil, count: wires.count)
        let count = handles.withUnsafeBufferPointer { inBuf in
            outHandles.withUnsafeMutableBufferPointer { outBuf in
                OCCTBRepFillCompatibleWires(inBuf.baseAddress!, Int32(wires.count), outBuf.baseAddress!)
            }
        }
        guard count > 0 else { return nil }
        return (0..<Int(count)).compactMap { i in
            if let h = outHandles[i] { return Wire(handle: h) }
            return nil
        }
    }

    // MARK: - ChFi2d_FilletAlgo

    /// Result of a 2D iterative fillet operation.
    public struct FilletAlgoResult {
        /// The fillet arc edge
        public let fillet: Shape
        /// Trimmed first edge
        public let edge1: Shape
        /// Trimmed second edge
        public let edge2: Shape
        /// Number of fillet solutions found
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
              let e2 = r.edge2 else { return nil }
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
              let s2 = Shape.fromEdge(edge2) else { return nil }
        return filletAlgo(edge1: s1, edge2: s2,
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
        return filletAlgo(edge1: edges[edgeIndex], edge2: edges[edgeIndex + 1],
                          planeOrigin: planeOrigin, planeNormal: planeNormal, radius: radius)
    }

    // MARK: - BRepTools_Substitution

    /// Substitute a sub-shape within this shape.
    ///
    /// Replaces one topological sub-shape (vertex, edge, face) with another
    /// and rebuilds the parent shape.
    ///
    /// - Parameters:
    ///   - oldSubShape: The sub-shape to replace
    ///   - newSubShape: The replacement sub-shape
    /// - Returns: Modified shape, or nil on failure
    public func substituted(replacing oldSubShape: Shape, with newSubShape: Shape) -> Shape? {
        guard let h = OCCTBRepToolsSubstitute(handle, oldSubShape.handle, newSubShape.handle) else {
            return nil
        }
        return Shape(handle: h)
    }

    // MARK: - ShapeUpgrade_ShellSewing

    /// Sew disconnected shells in this shape.
    ///
    /// Connects shells that share edges within the given tolerance.
    ///
    /// - Parameter tolerance: Sewing tolerance (default 1e-6)
    /// - Returns: Sewn shape, or nil on failure
    public func shellSewing(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeUpgradeShellSewing(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - LocOpe_BuildShape

    /// Build a shape from the faces of this shape.
    ///
    /// Extracts all faces and reconstructs them into a shell or solid.
    ///
    /// - Returns: Rebuilt shape, or nil on failure
    public func builtFromFaces() -> Shape? {
        guard let h = OCCTLocOpeBuildShape(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BOPAlgo Splitter (v0.61.0)

    /// Split shapes by tool shapes using BOPAlgo_Splitter.
    ///
    /// Partitions the object shapes using the tool shapes as cutting geometry.
    ///
    /// - Parameters:
    ///   - objects: Shapes to be split
    ///   - tools: Shapes used as splitting tools
    /// - Returns: Result shape containing all split fragments, or nil on failure
    public static func split(objects: [Shape], by tools: [Shape]) -> Shape? {
        let objPtrs = objects.map { $0.handle as OCCTShapeRef? }
        let toolPtrs = tools.map { $0.handle as OCCTShapeRef? }
        guard let h = objPtrs.withUnsafeBufferPointer({ objBuf in
            toolPtrs.withUnsafeBufferPointer({ toolBuf in
                OCCTBOPAlgoSplit(objBuf.baseAddress, Int32(objBuf.count),
                                 toolBuf.baseAddress, Int32(toolBuf.count))
            })
        }) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BOPAlgo ArgumentAnalyzer (v0.61.0)

    /// Boolean operation type for argument analysis.
    public enum BooleanOperation: Int32 {
        case fuse = 0
        case common = 1
        case cut = 2
        case cut21 = 3
        case section = 4
    }

    /// Analyze whether two shapes are valid for a Boolean operation.
    ///
    /// Checks for self-intersection, small edges, and argument type compatibility.
    ///
    /// - Parameters:
    ///   - shape1: First shape (object)
    ///   - shape2: Second shape (tool)
    ///   - operation: The Boolean operation to check
    /// - Returns: true if the shapes are valid for the operation
    public static func analyzeBoolean(_ shape1: Shape, _ shape2: Shape,
                                       operation: BooleanOperation = .fuse) -> Bool {
        return OCCTBOPAlgoAnalyzeArguments(shape1.handle, shape2.handle, operation.rawValue)
    }

    // MARK: - IntCurvesFace Intersection (v0.61.0)

    /// Result of a line-face intersection.
    public struct LineFaceIntersection {
        /// 3D intersection point
        public let point: SIMD3<Double>
        /// Parameter on the line
        public let parameter: Double
    }

    /// Intersect a line with this shape (must be a face).
    ///
    /// - Parameters:
    ///   - origin: Line origin point
    ///   - direction: Line direction
    ///   - paramRange: Parameter range on the line (default -1000...1000)
    /// - Returns: Array of intersection results
    public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>,
                              paramRange: ClosedRange<Double> = -1000...1000) -> [LineFaceIntersection] {
        let maxPts: Int32 = 100
        var outPoints = [Double](repeating: 0, count: Int(maxPts) * 3)
        var outParams = [Double](repeating: 0, count: Int(maxPts))
        let count = OCCTIntersectLineFace(handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            paramRange.lowerBound, paramRange.upperBound,
            &outPoints, &outParams, maxPts)
        var results: [LineFaceIntersection] = []
        for i in 0..<Int(count) {
            results.append(LineFaceIntersection(
                point: SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2]),
                parameter: outParams[i]))
        }
        return results
    }

    // MARK: - Contap Contour Analysis (v0.61.0)

    /// Contour type from analytical contour computation.
    public enum ContourType: Int32 {
        case line = 0
        case circle = 1
        case other = 2
    }

    /// Result of an analytical contour computation.
    public struct ContourResult {
        /// Type of contour
        public let type: ContourType
        /// Number of contours found
        public let count: Int
        /// For circles: center and radius. For lines: location and direction.
        public let data: [Double]
    }

    /// Compute analytical contours on a sphere with a view direction.
    ///
    /// Returns the silhouette contour of a sphere viewed from a given direction.
    /// For orthographic projection, this is typically a great circle.
    ///
    /// - Parameters:
    ///   - center: Sphere center
    ///   - radius: Sphere radius
    ///   - direction: View direction
    /// - Returns: Contour result, or nil on failure
    public static func contourSphereDir(center: SIMD3<Double>, radius: Double,
                                         direction: SIMD3<Double>) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapSphereDir(center.x, center.y, center.z, radius,
                                         direction.x, direction.y, direction.z,
                                         &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(type: ContourType(rawValue: outType) ?? .other,
                             count: Int(count), data: outData)
    }

    /// Compute analytical contours on a cylinder with a view direction.
    ///
    /// - Parameters:
    ///   - origin: Cylinder axis origin
    ///   - axis: Cylinder axis direction
    ///   - radius: Cylinder radius
    ///   - direction: View direction
    /// - Returns: Contour result, or nil on failure
    public static func contourCylinderDir(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                           radius: Double, direction: SIMD3<Double>) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapCylinderDir(origin.x, origin.y, origin.z,
                                           axis.x, axis.y, axis.z, radius,
                                           direction.x, direction.y, direction.z,
                                           &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(type: ContourType(rawValue: outType) ?? .other,
                             count: Int(count), data: outData)
    }

    /// Compute analytical contours on a sphere with a perspective eye point.
    ///
    /// - Parameters:
    ///   - center: Sphere center
    ///   - radius: Sphere radius
    ///   - eye: Eye point for perspective projection
    /// - Returns: Contour result, or nil on failure
    public static func contourSphereEye(center: SIMD3<Double>, radius: Double,
                                         eye: SIMD3<Double>) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapSphereEye(center.x, center.y, center.z, radius,
                                         eye.x, eye.y, eye.z,
                                         &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(type: ContourType(rawValue: outType) ?? .other,
                             count: Int(count), data: outData)
    }

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

    // MARK: - GeomPlate_Surface (v0.61.0)

    /// Build a plate surface through point constraints.
    ///
    /// Creates a smooth BSpline surface that passes through or near the given points.
    /// Useful for creating surfaces from scattered point data.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points to fit the surface through
    ///   - tolerance: Approximation tolerance (default 1e-3)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum BSpline segments (default 20)
    /// - Returns: Face with plate surface, or nil on failure
    public static func plateSurface(points: [SIMD3<Double>], tolerance: Double = 1e-3,
                                     maxDegree: Int = 8, maxSegments: Int = 20) -> Shape? {
        var flatPoints = [Double]()
        flatPoints.reserveCapacity(points.count * 3)
        for pt in points {
            flatPoints.append(pt.x)
            flatPoints.append(pt.y)
            flatPoints.append(pt.z)
        }
        guard let h = OCCTGeomPlateSurface(flatPoints, Int32(points.count),
                                            tolerance, Int32(maxDegree), Int32(maxSegments)) else { return nil }
        return Shape(handle: h)
    }

}

// MARK: - CellsBuilder (v0.61.0)

/// Builder for Boolean cell operations on shapes.
///
/// Partitions input shapes into cells (volumetric fragments), then lets you
/// select which cells to include in the result by material ID, and optionally
/// merge cells that share the same material.
public final class CellsBuilder: @unchecked Sendable {
    internal let handle: OCCTCellsBuilderRef

    /// Create a CellsBuilder from input shapes.
    ///
    /// The shapes are partitioned into cells during construction.
    ///
    /// - Parameter shapes: Input shapes to partition
    /// - Returns: CellsBuilder, or nil on failure
    public init?(shapes: [Shape]) {
        let ptrs = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = ptrs.withUnsafeBufferPointer({ buf in
            OCCTCellsBuilderCreate(buf.baseAddress, Int32(buf.count))
        }) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTCellsBuilderRelease(handle)
    }

    /// Add all split cells to the result with a material ID.
    ///
    /// - Parameter material: Material ID to assign (default 0)
    public func addAllToResult(material: Int32 = 0) {
        OCCTCellsBuilderAddAllToResult(handle, material)
    }

    /// Remove all cells from the result.
    public func removeAllFromResult() {
        OCCTCellsBuilderRemoveAllFromResult(handle)
    }

    /// Remove internal boundaries between cells with the same material.
    ///
    /// Merges adjacent cells that share the same material ID.
    public func removeInternalBoundaries() {
        OCCTCellsBuilderRemoveInternalBoundaries(handle)
    }

    /// Get the current result shape.
    ///
    /// - Returns: Result shape, or nil if empty
    public func result() -> Shape? {
        guard let h = OCCTCellsBuilderGetResult(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - BRepLib, LocOpe, ShapeUpgrade, ShapeCustom, CPnts, IntCurvesFace (v0.62.0)

extension Shape {

    // MARK: BRepLib_MakeEdge

    /// Create an edge from a line with parameter bounds.
    public static func edgeFromLine(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromLine(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create an edge from two 3D points (BRepLib).
    public static func edgeFromPoints(
        _ p1: SIMD3<Double>,
        _ p2: SIMD3<Double>
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromPoints(
            p1.x, p1.y, p1.z, p2.x, p2.y, p2.z
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create an edge from a circle arc with parameter bounds.
    public static func edgeFromCircle(
        center: SIMD3<Double>,
        axis: SIMD3<Double>,
        radius: Double,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromCircle(
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z,
            radius, p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_MakeFace

    /// Create a face from a plane surface with UV bounds.
    public static func faceFromPlane(
        origin: SIMD3<Double>,
        normal: SIMD3<Double>,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>,
        tolerance: Double = 1e-6
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeFaceFromPlane(
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound,
            tolerance
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create a face from a cylindrical surface with UV bounds.
    public static func faceFromCylinder(
        origin: SIMD3<Double>,
        axis: SIMD3<Double>,
        radius: Double,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>,
        tolerance: Double = 1e-6
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeFaceFromCylinder(
            origin.x, origin.y, origin.z,
            axis.x, axis.y, axis.z,
            radius,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound,
            tolerance
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_MakeShell

    /// Create a shell from a plane surface with UV bounds.
    public static func shellFromPlane(
        origin: SIMD3<Double>,
        normal: SIMD3<Double>,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeShellFromPlane(
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_ToolTriangulatedShape

    /// Compute normals on the triangulation of all faces in this shape.
    /// The shape must be meshed first.
    public func computeNormals() -> Bool {
        OCCTBRepLibComputeNormals(handle)
    }

    // MARK: BRepLib_PointCloudShape

    /// Point cloud result with positions and normals.
    public struct PointCloudResult: Sendable {
        public let points: [SIMD3<Double>]
        public let normals: [SIMD3<Double>]
    }

    /// Generate a point cloud from this shape's triangulation.
    /// The shape must be meshed first.
    public func pointCloudByTriangulation() -> PointCloudResult? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outNormals: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTBRepLibPointCloudByTriangulation(handle, &outPoints, &outNormals, &outCount),
              let pts = outPoints, let nms = outNormals, outCount > 0 else { return nil }
        defer { free(pts); free(nms) }
        var points = [SIMD3<Double>]()
        var normals = [SIMD3<Double>]()
        for i in 0..<Int(outCount) {
            points.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
            normals.append(SIMD3(nms[i*3], nms[i*3+1], nms[i*3+2]))
        }
        return PointCloudResult(points: points, normals: normals)
    }

    /// Generate a point cloud from this shape by density (points per unit area).
    /// The shape must be meshed first.
    public func pointCloudByDensity(_ density: Double) -> PointCloudResult? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outNormals: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTBRepLibPointCloudByDensity(handle, density, &outPoints, &outNormals, &outCount),
              let pts = outPoints, let nms = outNormals, outCount > 0 else { return nil }
        defer { free(pts); free(nms) }
        var points = [SIMD3<Double>]()
        var normals = [SIMD3<Double>]()
        for i in 0..<Int(outCount) {
            points.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
            normals.append(SIMD3(nms[i*3], nms[i*3+1], nms[i*3+2]))
        }
        return PointCloudResult(points: points, normals: normals)
    }

    // MARK: BRepBuilderAPI_MakeEdge2d

    /// Create a 2D edge from two 2D points.
    public static func edge2d(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Shape? {
        guard let h = OCCTMakeEdge2dFromPoints(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a circle arc with parameter bounds.
    public static func edge2dFromCircle(
        center: SIMD2<Double>,
        direction: SIMD2<Double>,
        radius: Double,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTMakeEdge2dFromCircle(
            center.x, center.y, direction.x, direction.y,
            radius, p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a line with parameter bounds.
    public static func edge2dFromLine(
        origin: SIMD2<Double>,
        direction: SIMD2<Double>,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTMakeEdge2dFromLine(
            origin.x, origin.y, direction.x, direction.y,
            p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepTools_Modifier + NurbsConvertModification

    /// Convert shape to NURBS via BRepTools_Modifier (flexible NURBS conversion).
    public func nurbsConvertViaModifier() -> Shape? {
        guard let h = OCCTBRepToolsModifierNurbsConvert(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: ShapeCustom_DirectModification

    /// Orient face normals outward using ShapeCustom_DirectModification.
    public func directModification() -> Shape? {
        guard let h = OCCTShapeCustomDirectModification(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: ShapeCustom_TrsfModification

    /// Apply a uniform scale with proper tolerance handling via ShapeCustom_TrsfModification.
    public func trsfModificationScale(_ scaleFactor: Double) -> Shape? {
        guard let h = OCCTShapeCustomTrsfModificationScale(handle, scaleFactor) else { return nil }
        return Shape(handle: h)
    }

    // MARK: LocOpe_BuildWires

    /// Build wires from the edges of a face.
    /// - Parameter faceIndex: 1-based face index (0 = all edges)
    public func buildWires(faceIndex: Int32 = 0) -> [Shape]? {
        var outWires: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard OCCTLocOpeBuildWires(handle, faceIndex, &outWires, &outCount) else { return nil }
        guard let wires = outWires else { return [] }
        defer { free(wires) }
        var result = [Shape]()
        for i in 0..<Int(outCount) {
            if let h = wires[i] {
                result.append(Shape(handle: h))
            }
        }
        return result
    }

    // MARK: LocOpe_WiresOnShape + LocOpe_Spliter

    /// Split a face of this shape by projecting a wire onto it.
    /// - Parameters:
    ///   - wire: The splitting wire
    ///   - faceIndex: 1-based index of the face to split
    public func splitByWireOnFace(_ wire: Shape, faceIndex: Int32) -> Shape? {
        guard let h = OCCTLocOpeSplitByWireOnFace(handle, wire.handle, faceIndex) else { return nil }
        return Shape(handle: h)
    }

    // MARK: LocOpe_CurveShapeIntersector

    /// Intersect a line with this shape and return parameter values.
    public func curveShapeIntersect(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> [Double]? {
        var outParams: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTLocOpeCurveShapeIntersectLine(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            &outParams, &outCount
        ) else { return nil }
        guard let params = outParams else { return [] }
        defer { free(params) }
        return Array(UnsafeBufferPointer(start: params, count: Int(outCount)))
    }

    // Note: ShapeUpgrade_ClosedFaceDivide, SplitSurfaceAngle, SplitSurfaceArea
    // already wrapped as dividedClosedFaces, splitByAngle, dividedByParts

    // MARK: CPnts_UniformDeflection

    /// Discretization result with parameters and 3D points.
    public struct DeflectionResult: Sendable {
        public let parameters: [Double]
        public let points: [SIMD3<Double>]
    }

    /// Discretize an edge by uniform deflection.
    public func uniformDeflection(_ deflection: Double) -> DeflectionResult? {
        var outParams: UnsafeMutablePointer<Double>?
        var outPoints: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTCPntsUniformDeflection(handle, deflection, &outParams, &outPoints, &outCount),
              let params = outParams, let pts = outPoints, outCount > 0 else { return nil }
        defer { free(params); free(pts) }
        var points = [SIMD3<Double>]()
        for i in 0..<Int(outCount) {
            points.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
        }
        return DeflectionResult(
            parameters: Array(UnsafeBufferPointer(start: params, count: Int(outCount))),
            points: points
        )
    }

    /// Discretize an edge by uniform deflection within a parameter range.
    public func uniformDeflection(_ deflection: Double, range: ClosedRange<Double>) -> DeflectionResult? {
        var outParams: UnsafeMutablePointer<Double>?
        var outPoints: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTCPntsUniformDeflectionRange(
            handle, deflection,
            range.lowerBound, range.upperBound,
            &outParams, &outPoints, &outCount
        ), let params = outParams, let pts = outPoints, outCount > 0 else { return nil }
        defer { free(params); free(pts) }
        var points = [SIMD3<Double>]()
        for i in 0..<Int(outCount) {
            points.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
        }
        return DeflectionResult(
            parameters: Array(UnsafeBufferPointer(start: params, count: Int(outCount))),
            points: points
        )
    }

    // MARK: IntCurvesFace_ShapeIntersector

    /// Ray intersection result.
    public struct RayIntersection: Sendable {
        public let point: SIMD3<Double>
        public let parameter: Double
    }

    /// Intersect a ray with all faces of this shape.
    public func rayIntersect(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> [RayIntersection]? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outParams: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTIntCurvesFaceShapeIntersect(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            &outPoints, &outParams, &outCount
        ), let pts = outPoints, let params = outParams, outCount > 0 else { return nil }
        defer { free(pts); free(params) }
        var results = [RayIntersection]()
        for i in 0..<Int(outCount) {
            results.append(RayIntersection(
                point: SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]),
                parameter: params[i]
            ))
        }
        return results
    }

    /// Find the nearest intersection of a ray with this shape.
    public func rayIntersectNearest(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> RayIntersection? {
        var x: Double = 0, y: Double = 0, z: Double = 0, param: Double = 0
        guard OCCTIntCurvesFaceShapeIntersectNearest(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            &x, &y, &z, &param
        ) else { return nil }
        return RayIntersection(point: SIMD3(x, y, z), parameter: param)
    }
}

// MARK: - GeomLProp, SimpleOffset, Approx, GeomInt, Contap, BRepFeat, GeomFill (v0.63.0)

/// Curve local properties at a parameter point
public struct CurveLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let tangent: SIMD3<Double>?
    public let normal: SIMD3<Double>?
    public let centerOfCurvature: SIMD3<Double>?
    public let curvature: Double
}

/// Surface local properties at a (U,V) parameter point
public struct SurfaceLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let normal: SIMD3<Double>?
    public let tangentU: SIMD3<Double>?
    public let tangentV: SIMD3<Double>?
    public let maxCurvature: Double
    public let minCurvature: Double
    public let meanCurvature: Double
    public let gaussianCurvature: Double
    public let isUmbilic: Bool
}

/// Trihedron frame (tangent, normal, binormal) at a curve parameter
public struct TrihedronFrame: Sendable {
    public let tangent: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let binormal: SIMD3<Double>
}

/// Contour line type
public enum ContourLineType: Int32, Sendable {
    case line = 0
    case circle = 1
    case walking = 2
    case restriction = 3
}

/// Filling pole grid result from GeomFill_Coons/Curved
public struct FillingPoleGrid: Sendable {
    public let poles: [SIMD3<Double>]
    public let nbU: Int
    public let nbV: Int
}

/// Evolved section shape info
public struct EvolvedSectionInfo: Sendable {
    public let nbPoles: Int
    public let nbKnots: Int
    public let degree: Int
    public let isRational: Bool
}

/// Contour computation result
public class ContapContourResult {
    let ref: OCCTContapContourRef

    init(_ ref: OCCTContapContourRef) {
        self.ref = ref
    }

    deinit {
        OCCTContapContourRelease(ref)
    }

    /// Number of contour lines
    public var lineCount: Int {
        Int(OCCTContapContourLineCount(ref))
    }

    /// Number of points on a specific contour line (1-based index)
    public func pointCount(line: Int) -> Int {
        Int(OCCTContapContourLinePointCount(ref, Int32(line)))
    }

    /// Get a point on a contour line (1-based indices)
    public func point(line: Int, index: Int) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTContapContourLinePoint(ref, Int32(line), Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get all points on a contour line (1-based line index)
    public func points(line: Int) -> [SIMD3<Double>] {
        let count = pointCount(line: line)
        guard count > 0 else { return [] }
        return (1...count).map { point(line: line, index: $0) }
    }

    /// Get the type of a contour line (1-based index)
    public func lineType(_ line: Int) -> ContourLineType? {
        let t = OCCTContapContourLineType(ref, Int32(line))
        return ContourLineType(rawValue: t)
    }
}

/// Surface-surface intersection result
public class SurfaceIntersectionResult {
    let ref: OCCTGeomIntSSRef

    init(_ ref: OCCTGeomIntSSRef) {
        self.ref = ref
    }

    deinit {
        OCCTGeomIntSSRelease(ref)
    }

    /// Number of intersection curves
    public var curveCount: Int {
        Int(OCCTGeomIntSSLineCount(ref))
    }

    /// Get an intersection curve as an edge shape (1-based index)
    public func curve(_ index: Int) -> Shape? {
        guard let h = OCCTGeomIntSSLine(ref, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Number of isolated intersection points
    public var pointCount: Int {
        Int(OCCTGeomIntSSPointCount(ref))
    }

    /// Get an intersection point (1-based index)
    public func point(_ index: Int) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTGeomIntSSPoint(ref, Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

extension Shape {

    // MARK: - GeomLProp_CLProps

    /// Compute curve local properties at a parameter on an edge
    public func curveLocalProps(at param: Double) -> CurveLocalProperties {
        let r = OCCTGeomLPropCLProps(handle, param)
        let point = SIMD3(r.px, r.py, r.pz)
        let tangent: SIMD3<Double>? = r.tangentDefined ?
            SIMD3(r.tx, r.ty, r.tz) : nil
        let normal: SIMD3<Double>? = (r.tangentDefined && r.curvature > 1e-10) ?
            SIMD3(r.nx, r.ny, r.nz) : nil
        let center: SIMD3<Double>? = (r.tangentDefined && r.curvature > 1e-10) ?
            SIMD3(r.cx, r.cy, r.cz) : nil
        return CurveLocalProperties(
            point: point, tangent: tangent, normal: normal,
            centerOfCurvature: center, curvature: r.curvature)
    }

    // MARK: - GeomLProp_SLProps

    /// Compute surface local properties at (U,V) on a face
    public func surfaceLocalProps(u: Double, v: Double) -> SurfaceLocalProperties {
        let r = OCCTGeomLPropSLProps(handle, u, v)
        let point = SIMD3(r.px, r.py, r.pz)
        let normal: SIMD3<Double>? = r.normalDefined ? SIMD3(r.nx, r.ny, r.nz) : nil
        let tu: SIMD3<Double>? = (r.tuX != 0 || r.tuY != 0 || r.tuZ != 0) ?
            SIMD3(r.tuX, r.tuY, r.tuZ) : nil
        let tv: SIMD3<Double>? = (r.tvX != 0 || r.tvY != 0 || r.tvZ != 0) ?
            SIMD3(r.tvX, r.tvY, r.tvZ) : nil
        return SurfaceLocalProperties(
            point: point, normal: normal, tangentU: tu, tangentV: tv,
            maxCurvature: r.maxCurvature, minCurvature: r.minCurvature,
            meanCurvature: r.meanCurvature, gaussianCurvature: r.gaussianCurvature,
            isUmbilic: r.isUmbilic)
    }

    // MARK: - BRepOffset_SimpleOffset

    /// Create a simple surface offset of the shape
    public func simpleOffsetShape(distance: Double, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTBRepOffsetSimpleOffset(handle, distance, tolerance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Approx_CurvilinearParameter

    /// Reparameterize an edge curve by arc length, returning a BSpline edge
    public func curvilinearParameter(tolerance: Double = 1e-3, maxDegree: Int = 8, maxSegments: Int = 50) -> Shape? {
        guard let h = OCCTApproxCurvilinearParameter(handle, tolerance, Int32(maxDegree), Int32(maxSegments)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - GeomInt_IntSS

    /// Compute surface-surface intersection between two faces
    public static func surfaceSurfaceIntersection(face1: Shape, face2: Shape, tolerance: Double = 1e-6) -> SurfaceIntersectionResult? {
        guard let ref = OCCTGeomIntSSCreate(face1.handle, face2.handle, tolerance) else { return nil }
        return SurfaceIntersectionResult(ref)
    }

    // MARK: - Contap_Contour

    /// Compute contour lines on a face with a projection direction (orthographic)
    public func contapContourDirection(_ direction: SIMD3<Double>) -> ContapContourResult? {
        guard let ref = OCCTContapContourDirection(handle, direction.x, direction.y, direction.z) else { return nil }
        let result = ContapContourResult(ref)
        return result.lineCount > 0 ? result : nil
    }

    /// Compute contour lines on a face with an eye point (perspective)
    public func contapContourEye(_ eye: SIMD3<Double>) -> ContapContourResult? {
        guard let ref = OCCTContapContourEye(handle, eye.x, eye.y, eye.z) else { return nil }
        let result = ContapContourResult(ref)
        return result.lineCount > 0 ? result : nil
    }

    // MARK: - BRepFeat_Builder

    /// Feature-based fuse (union with part selection)
    public func featFuse(with tool: Shape) -> Shape? {
        guard let h = OCCTBRepFeatBuilderFuse(handle, tool.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Feature-based cut (subtraction with part selection)
    public func featCut(with tool: Shape) -> Shape? {
        guard let h = OCCTBRepFeatBuilderCut(handle, tool.handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - GeomFill Trihedron Laws

    /// Evaluate draft trihedron frame on an edge at a parameter
    public func draftTrihedron(at param: Double, biNormal: SIMD3<Double>, angle: Double) -> TrihedronFrame? {
        let r = OCCTGeomFillDraftTrihedron(handle, param, biNormal.x, biNormal.y, biNormal.z, angle)
        let t = SIMD3(r.tx, r.ty, r.tz)
        guard simd_length(t) > 1e-10 else { return nil }
        return TrihedronFrame(tangent: t, normal: SIMD3(r.nx, r.ny, r.nz), binormal: SIMD3(r.bx, r.by, r.bz))
    }

    /// Evaluate discrete trihedron frame on an edge at a parameter
    public func discreteTrihedron(at param: Double) -> TrihedronFrame? {
        let r = OCCTGeomFillDiscreteTrihedron(handle, param)
        let t = SIMD3(r.tx, r.ty, r.tz)
        guard simd_length(t) > 1e-10 else { return nil }
        return TrihedronFrame(tangent: t, normal: SIMD3(r.nx, r.ny, r.nz), binormal: SIMD3(r.bx, r.by, r.bz))
    }

    /// Evaluate corrected Frenet frame on an edge at a parameter
    public func correctedFrenet(at param: Double) -> TrihedronFrame? {
        let r = OCCTGeomFillCorrectedFrenet(handle, param)
        let t = SIMD3(r.tx, r.ty, r.tz)
        guard simd_length(t) > 1e-10 else { return nil }
        return TrihedronFrame(tangent: t, normal: SIMD3(r.nx, r.ny, r.nz), binormal: SIMD3(r.bx, r.by, r.bz))
    }

    // MARK: - GeomFill_Coons / GeomFill_Curved

    /// Compute Coons filling pole grid from 4 boundary point arrays
    public static func coonsFilling(
        boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
        boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
    ) -> FillingPoleGrid? {
        let n = boundary1.count
        guard n >= 2, boundary2.count == n, boundary3.count == n, boundary4.count == n else { return nil }
        let b1 = boundary1.flatMap { [$0.x, $0.y, $0.z] }
        let b2 = boundary2.flatMap { [$0.x, $0.y, $0.z] }
        let b3 = boundary3.flatMap { [$0.x, $0.y, $0.z] }
        let b4 = boundary4.flatMap { [$0.x, $0.y, $0.z] }
        let maxPoles = n * n * 4
        var outPoints = [Double](repeating: 0, count: maxPoles * 3)
        var nbU: Int32 = 0, nbV: Int32 = 0
        let count = Int(OCCTGeomFillCoonsPoles(b1, b2, b3, b4, Int32(n), &outPoints, Int32(maxPoles), &nbU, &nbV))
        guard count > 0 else { return nil }
        let poles = (0..<count).map { i in
            SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2])
        }
        return FillingPoleGrid(poles: poles, nbU: Int(nbU), nbV: Int(nbV))
    }

    /// Compute curved filling pole grid from 4 boundary point arrays
    public static func curvedFilling(
        boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
        boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
    ) -> FillingPoleGrid? {
        let n = boundary1.count
        guard n >= 2, boundary2.count == n, boundary3.count == n, boundary4.count == n else { return nil }
        let b1 = boundary1.flatMap { [$0.x, $0.y, $0.z] }
        let b2 = boundary2.flatMap { [$0.x, $0.y, $0.z] }
        let b3 = boundary3.flatMap { [$0.x, $0.y, $0.z] }
        let b4 = boundary4.flatMap { [$0.x, $0.y, $0.z] }
        let maxPoles = n * n * 4
        var outPoints = [Double](repeating: 0, count: maxPoles * 3)
        var nbU: Int32 = 0, nbV: Int32 = 0
        let count = Int(OCCTGeomFillCurvedPoles(b1, b2, b3, b4, Int32(n), &outPoints, Int32(maxPoles), &nbU, &nbV))
        guard count > 0 else { return nil }
        let poles = (0..<count).map { i in
            SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2])
        }
        return FillingPoleGrid(poles: poles, nbU: Int(nbU), nbV: Int(nbV))
    }

    // MARK: - GeomFill_CoonsAlgPatch

    /// Evaluate Coons algorithmic patch from 4 boundary edges
    public static func coonsAlgPatch(
        edge1: Shape, edge2: Shape, edge3: Shape, edge4: Shape,
        evalU: Int = 10, evalV: Int = 10
    ) -> [SIMD3<Double>]? {
        var outPoints = [Double](repeating: 0, count: evalU * evalV * 3)
        OCCTGeomFillCoonsAlgPatchEval(
            edge1.handle, edge2.handle, edge3.handle, edge4.handle,
            Int32(evalU), Int32(evalV), &outPoints)
        let points = (0..<evalU * evalV).map { i in
            SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2])
        }
        // Check if any non-zero points
        guard points.contains(where: { simd_length($0) > 1e-10 }) else { return nil }
        return points
    }

    // MARK: - GeomFill_Sweep

    /// Sweep a section edge along a path edge to create a surface face
    public static func geomFillSweep(path: Shape, section: Shape) -> Shape? {
        guard let h = OCCTGeomFillSweep(path.handle, section.handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - GeomFill_EvolvedSection

    /// Get evolved section info for an edge curve
    public func evolvedSectionInfo() -> EvolvedSectionInfo {
        let r = OCCTGeomFillEvolvedSectionInfo(handle)
        return EvolvedSectionInfo(
            nbPoles: Int(r.nbPoles), nbKnots: Int(r.nbKnots),
            degree: Int(r.degree), isRational: r.isRational)
    }
}

// MARK: - ProjLib, BRepOffset_Offset, Adaptor3d IsoCurve, ShapeAnalysis Param Transfer (v0.64.0)

extension Shape {

    // MARK: - ProjLib_ComputeApprox

    /// Project this edge's 3D curve onto a face's surface → edge on surface
    public func projectOntoSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTProjLibComputeApprox(handle, face.handle, tolerance) else { return nil }
        return Shape(handle: h)
    }

    /// Project this edge's 3D curve onto a polar surface (sphere, torus) → edge on surface
    public func projectOntoPolarSurface(_ face: Shape, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTProjLibComputeApproxOnPolarSurface(handle, face.handle, tolerance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepOffset_Offset

    /// Offset a face by a distance, creating a new offset face
    public func offsetFace(distance: Double) -> Shape? {
        guard let h = OCCTBRepOffsetOffsetFace(handle, distance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Adaptor3d_IsoCurve

    /// Evaluate points along a U-iso curve on a face at given U parameter
    public func uIsoCurvePoints(u: Double, count: Int = 20) -> [SIMD3<Double>] {
        var outPoints = [Double](repeating: 0, count: count * 3)
        OCCTAdaptor3dIsoCurveEval(handle, 0, u, Int32(count), &outPoints)
        return (0..<count).map { i in
            SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2])
        }
    }

    /// Evaluate points along a V-iso curve on a face at given V parameter
    public func vIsoCurvePoints(v: Double, count: Int = 20) -> [SIMD3<Double>] {
        var outPoints = [Double](repeating: 0, count: count * 3)
        OCCTAdaptor3dIsoCurveEval(handle, 1, v, Int32(count), &outPoints)
        return (0..<count).map { i in
            SIMD3(outPoints[i*3], outPoints[i*3+1], outPoints[i*3+2])
        }
    }

    /// Extract a U-iso curve from a face as an edge
    public func uIsoCurveEdge(u: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let h = OCCTAdaptor3dIsoCurveEdge(handle, 0, u, vMin, vMax) else { return nil }
        return Shape(handle: h)
    }

    /// Extract a V-iso curve from a face as an edge
    public func vIsoCurveEdge(v: Double, uMin: Double, uMax: Double) -> Shape? {
        guard let h = OCCTAdaptor3dIsoCurveEdge(handle, 1, v, uMin, uMax) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - ShapeAnalysis_TransferParametersProj

    /// Transfer a parameter from edge to face coordinate system via projection
    public func transferParameterToFace(_ param: Double, face: Shape) -> Double {
        OCCTShapeAnalysisTransferParam(handle, face.handle, param, true)
    }

    /// Transfer a parameter from face to edge coordinate system via projection
    public func transferParameterFromFace(_ param: Double, face: Shape) -> Double {
        OCCTShapeAnalysisTransferParam(handle, face.handle, param, false)
    }

    // MARK: - v0.65.0: Shape Processing Completions + Boolean Completions

    // MARK: - BOPAlgo_RemoveFeatures

    /// Remove features (faces) from a solid shape.
    ///
    /// Uses BOPAlgo_RemoveFeatures to remove specified faces (e.g., fillets, holes)
    /// from a solid, healing the resulting shape.
    ///
    /// - Parameter faces: Array of face shapes to remove
    /// - Returns: Shape with features removed, or nil on failure
    public func removeFeatures(faces: [Shape]) -> Shape? {
        let handles = faces.map { $0.handle as OCCTShapeRef }
        guard let ref = handles.withUnsafeBufferPointer({ buf in
            OCCTBOPAlgoRemoveFeatures(handle, buf.baseAddress!, Int32(buf.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BOPAlgo_Section

    /// Compute section (intersection curves/vertices) between this shape and tools.
    ///
    /// Uses BOPAlgo_Section to find intersection edges and vertices.
    ///
    /// - Parameter tools: Tool shapes to intersect with
    /// - Returns: Compound of edges/vertices at intersections, or nil on failure
    public func section(with tools: [Shape]) -> Shape? {
        let objHandles = [handle as OCCTShapeRef]
        let toolHandles = tools.map { $0.handle as OCCTShapeRef }
        guard let ref = objHandles.withUnsafeBufferPointer({ objBuf in
            toolHandles.withUnsafeBufferPointer({ toolBuf in
                OCCTBOPAlgoSection(objBuf.baseAddress!, Int32(objBuf.count),
                                   toolBuf.baseAddress!, Int32(toolBuf.count))
            })
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Compute section between multiple shapes.
    ///
    /// - Parameter shapes: Array of shapes to compute section between
    /// - Returns: Compound of edges/vertices at intersections, or nil on failure
    public static func section(shapes: [Shape]) -> Shape? {
        let handles = shapes.map { $0.handle as OCCTShapeRef }
        guard handles.count >= 2 else { return nil }
        return handles.withUnsafeBufferPointer({ buf in
            // Pass all shapes as objects (BOPAlgo_Section treats all arguments equally)
            let empty = [OCCTShapeRef]()
            return empty.withUnsafeBufferPointer({ emptyBuf in
                guard let ref = OCCTBOPAlgoSection(buf.baseAddress!, Int32(buf.count),
                                                    emptyBuf.baseAddress!, Int32(0)) else { return nil }
                return Shape(handle: ref)
            })
        })
    }

    // MARK: - ShapeBuild_Edge

    /// Copy an edge, optionally sharing PCurves.
    ///
    /// - Parameter sharePCurves: If true, share PCurves with original (default: true)
    /// - Returns: Copied edge as shape, or nil on failure
    public func copyEdge(sharePCurves: Bool = true) -> Shape? {
        guard let ref = OCCTShapeBuildEdgeCopy(handle, sharePCurves) else { return nil }
        return Shape(handle: ref)
    }

    /// Copy an edge replacing its start and/or end vertices.
    ///
    /// - Parameters:
    ///   - startVertex: New start vertex (pass nil to keep original)
    ///   - endVertex: New end vertex (pass nil to keep original)
    /// - Returns: Edge with replaced vertices, or nil on failure
    public func copyEdgeReplacingVertices(startVertex: Shape?, endVertex: Shape?) -> Shape? {
        guard let ref = OCCTShapeBuildEdgeCopyReplaceVertices(
            handle, startVertex?.handle, endVertex?.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Set the 3D parameter range on this edge shape.
    public func setEdgeRange3d(first: Double, last: Double) {
        OCCTShapeBuildEdgeSetRange3d(handle, first, last)
    }

    /// Rebuild the 3D curve of an edge from its PCurves.
    /// - Returns: true if curve was rebuilt successfully
    @discardableResult
    public func buildEdgeCurve3d() -> Bool {
        OCCTShapeBuildEdgeBuildCurve3d(handle)
    }

    /// Remove the 3D curve from this edge.
    public func removeEdgeCurve3d() {
        OCCTShapeBuildEdgeRemoveCurve3d(handle)
    }

    /// Copy parameter ranges from another edge to this edge.
    public func copyEdgeRanges(from source: Shape) {
        OCCTShapeBuildEdgeCopyRanges(handle, source.handle)
    }

    /// Copy PCurves from another edge to this edge.
    public func copyEdgePCurves(from source: Shape) {
        OCCTShapeBuildEdgeCopyPCurves(handle, source.handle)
    }

    /// Remove the PCurve from this edge for a given face.
    public func removeEdgePCurve(onFace face: Shape) {
        OCCTShapeBuildEdgeRemovePCurve(handle, face.handle)
    }

    /// Reassign a PCurve from one face to another.
    /// - Returns: true if reassignment succeeded
    @discardableResult
    public func reassignEdgePCurve(from oldFace: Shape, to newFace: Shape) -> Bool {
        OCCTShapeBuildEdgeReassignPCurve(handle, oldFace.handle, newFace.handle)
    }

    // MARK: - ShapeBuild_Vertex

    /// Combine two vertex shapes into one at their average position.
    ///
    /// - Parameters:
    ///   - other: Other vertex shape to combine with
    ///   - tolFactor: Tolerance factor (default: 1.0001)
    /// - Returns: Combined vertex as shape, or nil on failure
    public func combineVertex(with other: Shape, tolFactor: Double = 1.0001) -> Shape? {
        guard let ref = OCCTShapeBuildVertexCombine(handle, other.handle, tolFactor) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a vertex by combining two 3D points.
    ///
    /// - Parameters:
    ///   - point1: First point
    ///   - tol1: Tolerance of first point
    ///   - point2: Second point
    ///   - tol2: Tolerance of second point
    ///   - tolFactor: Tolerance factor (default: 1.0001)
    /// - Returns: Combined vertex as shape, or nil on failure
    public static func combineVertices(
        point1: SIMD3<Double>, tol1: Double,
        point2: SIMD3<Double>, tol2: Double,
        tolFactor: Double = 1.0001
    ) -> Shape? {
        guard let ref = OCCTShapeBuildVertexCombineFromPoints(
            point1.x, point1.y, point1.z, tol1,
            point2.x, point2.y, point2.z, tol2,
            tolFactor) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeExtend_Explorer

    /// Shape type for filtering compounds
    public enum ShapeFilterType: Int32, Sendable {
        case compound = 0
        case compsolid = 1
        case solid = 2
        case shell = 3
        case face = 4
        case wire = 5
        case edge = 6
        case vertex = 7
    }

    /// Filter this compound shape, extracting only sub-shapes of the specified type.
    ///
    /// - Parameters:
    ///   - type: Shape type to extract
    ///   - explore: If true, explore sub-compounds recursively
    /// - Returns: Compound containing only shapes of the specified type, or nil on failure
    public func sortedCompound(type: ShapeFilterType, explore: Bool = true) -> Shape? {
        guard let ref = OCCTShapeExtendSortedCompound(handle, type.rawValue, explore) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the predominant shape type in this compound.
    ///
    /// - Parameter lookInsideCompounds: If true, look inside sub-compounds
    /// - Returns: The predominant shape type
    public func predominantShapeType(lookInsideCompounds: Bool = true) -> ShapeFilterType {
        let raw = OCCTShapeExtendShapeType(handle, lookInsideCompounds)
        return ShapeFilterType(rawValue: raw) ?? .compound
    }

    // MARK: - ShapeUpgrade_FaceDivide

    /// Divide a face using surface segmentation.
    ///
    /// Uses ShapeUpgrade_FaceDivide to split a face based on surface properties.
    ///
    /// - Returns: Divided shape, or nil on failure
    public func divideFace() -> Shape? {
        guard let ref = OCCTShapeUpgradeFaceDivide(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_WireDivide

    /// Divide a wire on a face.
    ///
    /// Uses ShapeUpgrade_WireDivide to split wire edges.
    ///
    /// - Parameter face: Face the wire lies on
    /// - Returns: Divided wire as shape, or nil on failure
    public func divideWire(onFace face: Shape) -> Shape? {
        guard let ref = OCCTShapeUpgradeWireDivideOnFace(handle, face.handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_EdgeDivide

    /// Result of edge divide analysis
    public struct EdgeDivideResult: Sendable {
        /// Whether the edge has a 2D curve on the face
        public let hasCurve2d: Bool
        /// Whether the edge has a 3D curve
        public let hasCurve3d: Bool
    }

    /// Analyze an edge for potential division on a face.
    ///
    /// - Parameter face: Face context for the edge
    /// - Returns: Analysis result, or nil on failure
    public func analyzeEdgeDivide(onFace face: Shape) -> EdgeDivideResult? {
        var hasCurve2d = false
        var hasCurve3d = false
        let ok = OCCTShapeUpgradeEdgeDivideCompute(handle, face.handle, &hasCurve2d, &hasCurve3d)
        guard ok else { return nil }
        return EdgeDivideResult(hasCurve2d: hasCurve2d, hasCurve3d: hasCurve3d)
    }

    // MARK: - ShapeUpgrade_ClosedEdgeDivide

    /// Check if a closed (seam) edge can be divided on a face.
    ///
    /// - Parameter face: Face context
    /// - Returns: true if the edge is closed and can be divided
    public func canDivideClosedEdge(onFace face: Shape) -> Bool {
        OCCTShapeUpgradeClosedEdgeDivideCompute(handle, face.handle)
    }

    // MARK: - ShapeUpgrade_FixSmallCurves

    /// Fix small curves in this shape.
    ///
    /// - Parameter tolerance: Tolerance for small curve detection (default: 1e-6)
    /// - Returns: Fixed shape, or nil on failure
    public func fixSmallCurves(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeUpgradeFixSmallCurves(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_FixSmallBezierCurves

    /// Fix small Bezier curves in this shape.
    ///
    /// - Parameter tolerance: Tolerance for small curve detection (default: 1e-6)
    /// - Returns: Fixed shape, or nil on failure
    public func fixSmallBezierCurves(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeUpgradeFixSmallBezierCurves(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ConvertCurve3dToBezier

    /// Convert 3D curves in this shape to Bezier representation.
    ///
    /// - Parameters:
    ///   - lineMode: Convert lines to Bezier (default: true)
    ///   - circleMode: Convert circles to Bezier (default: true)
    ///   - conicMode: Convert conics to Bezier (default: true)
    /// - Returns: Shape with Bezier curves, or nil on failure
    public func convertCurves3dToBezier(lineMode: Bool = true, circleMode: Bool = true,
                                         conicMode: Bool = true) -> Shape? {
        guard let ref = OCCTShapeUpgradeConvertCurves3dToBezier(handle, lineMode, circleMode, conicMode) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

    /// Convert surfaces in this shape to Bezier patches.
    ///
    /// - Parameters:
    ///   - planeMode: Convert planes (default: true)
    ///   - revolutionMode: Convert surfaces of revolution (default: true)
    ///   - extrusionMode: Convert extrusion surfaces (default: true)
    ///   - bsplineMode: Convert BSpline surfaces (default: true)
    /// - Returns: Shape with Bezier surfaces, or nil on failure
    public func convertSurfacesToBezier(planeMode: Bool = true, revolutionMode: Bool = true,
                                         extrusionMode: Bool = true, bsplineMode: Bool = true) -> Shape? {
        guard let ref = OCCTShapeUpgradeConvertSurfaceToBezier(handle, planeMode, revolutionMode,
                                                                extrusionMode, bsplineMode) else {
            return nil
        }
        return Shape(handle: ref)
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
        var x = v.x, y = v.y
        OCCTVector2DNormalize(&x, &y)
        return SIMD2(x, y)
    }

    /// Create a normalized 2D direction from components.
    public static func direction2DNormalized(_ v: SIMD2<Double>) -> SIMD2<Double> {
        var x = v.x, y = v.y
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

    /// Curvature special point type from LProp analysis.
    public enum CurvaturePointType: Int32 {
        case inflection = 0
        case minimumCurvature = 1
        case maximumCurvature = 2
    }

    /// Result of LProp analytic curve inflection analysis.
    public struct CurvatureSpecialPoint {
        /// Parameter on the curve.
        public let parameter: Double
        /// Type of special point.
        public let type: CurvaturePointType
    }

    /// Compute curvature special points for analytic curve types using LProp.
    /// - Parameters:
    ///   - curveType: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola
    ///   - first: First parameter of domain
    ///   - last: Last parameter of domain
    /// - Returns: Array of special points (inflections, min/max curvature)
    public static func analyticCurvaturePoints(curveType: Int32, first: Double,
                                                last: Double) -> [CurvatureSpecialPoint] {
        let maxResults: Int32 = 100
        var params = [Double](repeating: 0, count: Int(maxResults))
        var types = [Int32](repeating: 0, count: Int(maxResults))
        let count = OCCTLPropAnalyticCurInf(curveType, first, last, &params, &types, maxResults)
        var results: [CurvatureSpecialPoint] = []
        for i in 0..<Int(count) {
            if let t = CurvaturePointType(rawValue: types[i]) {
                results.append(CurvatureSpecialPoint(parameter: params[i], type: t))
            }
        }
        return results
    }

    // MARK: - TopTrans Surface Transition

    /// TopAbs_State values for surface transition analysis.
    public enum TopologicalState: Int32, Sendable {
        case `in` = 0
        case out = 1
        case on = 2
        case unknown = 3
    }

    /// Result of a surface transition analysis.
    public struct SurfaceTransitionResult: Sendable {
        /// State before crossing the surface
        public let stateBefore: TopologicalState
        /// State after crossing the surface
        public let stateAfter: TopologicalState
    }

    /// Analyze a surface transition along a curve crossing a surface boundary.
    ///
    /// Determines the topological state (IN/OUT) before and after crossing a surface,
    /// given the curve tangent, boundary normal, and surface normal at the crossing point.
    ///
    /// - Parameters:
    ///   - tangent: Tangent direction of the curve at the crossing
    ///   - normal: Normal of the boundary at the crossing
    ///   - surfaceNormal: Normal of the surface being crossed
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface (0=FORWARD, 1=REVERSED)
    ///   - boundaryOrientation: Orientation of the boundary (0=FORWARD, 1=REVERSED)
    /// - Returns: Transition result with states before and after
    public static func surfaceTransition(
        tangent: SIMD3<Double>, normal: SIMD3<Double>,
        surfaceNormal: SIMD3<Double>, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransSurfaceTransition(
            tangent.x, tangent.y, tangent.z,
            normal.x, normal.y, normal.z,
            surfaceNormal.x, surfaceNormal.y, surfaceNormal.z,
            tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    /// Analyze a surface transition with curvature information.
    ///
    /// Extended version that accounts for surface curvature at the crossing point,
    /// providing more accurate transition analysis for curved surfaces.
    ///
    /// - Parameters:
    ///   - tangent: Tangent direction of the curve
    ///   - normal: Normal of the boundary
    ///   - maxDirection: Direction of maximum curvature of the boundary
    ///   - minDirection: Direction of minimum curvature of the boundary
    ///   - maxCurvature: Maximum curvature of the boundary
    ///   - minCurvature: Minimum curvature of the boundary
    ///   - surfaceNormal: Normal of the surface
    ///   - surfaceMaxDirection: Direction of maximum curvature of the surface
    ///   - surfaceMinDirection: Direction of minimum curvature of the surface
    ///   - surfaceMaxCurvature: Maximum curvature of the surface
    ///   - surfaceMinCurvature: Minimum curvature of the surface
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface
    ///   - boundaryOrientation: Orientation of the boundary
    /// - Returns: Transition result with states before and after
    public static func surfaceTransitionWithCurvature(
        tangent: SIMD3<Double>, normal: SIMD3<Double>,
        maxDirection: SIMD3<Double>, minDirection: SIMD3<Double>,
        maxCurvature: Double, minCurvature: Double,
        surfaceNormal: SIMD3<Double>,
        surfaceMaxDirection: SIMD3<Double>, surfaceMinDirection: SIMD3<Double>,
        surfaceMaxCurvature: Double, surfaceMinCurvature: Double,
        tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransSurfaceTransitionCurvature(
            tangent.x, tangent.y, tangent.z,
            normal.x, normal.y, normal.z,
            maxDirection.x, maxDirection.y, maxDirection.z,
            minDirection.x, minDirection.y, minDirection.z,
            maxCurvature, minCurvature,
            surfaceNormal.x, surfaceNormal.y, surfaceNormal.z,
            surfaceMaxDirection.x, surfaceMaxDirection.y, surfaceMaxDirection.z,
            surfaceMinDirection.x, surfaceMinDirection.y, surfaceMinDirection.z,
            surfaceMaxCurvature, surfaceMinCurvature,
            tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    // MARK: - TopTrans Curve Transition

    /// Analyze a curve transition at a boundary crossing.
    ///
    /// Determines the topological state (IN/OUT) before and after a curve crosses
    /// a boundary element, given directions and curvature.
    ///
    /// - Parameters:
    ///   - tangent: Tangent of the curve at the crossing
    ///   - boundaryTangent: Tangent of the boundary element
    ///   - boundaryNormal: Normal of the boundary element
    ///   - curvature: Curvature of the boundary at the crossing
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface (0=FORWARD, 1=REVERSED)
    ///   - boundaryOrientation: Orientation of the boundary
    /// - Returns: Transition result with states before and after
    public static func curveTransition(
        tangent: SIMD3<Double>,
        boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
        curvature: Double = 0.0, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransCurveTransition(
            tangent.x, tangent.y, tangent.z,
            boundaryTangent.x, boundaryTangent.y, boundaryTangent.z,
            boundaryNormal.x, boundaryNormal.y, boundaryNormal.z,
            curvature, tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    /// Analyze a curve transition with curvature on the boundary curve.
    public static func curveTransitionWithCurvature(
        tangent: SIMD3<Double>,
        curveNormal: SIMD3<Double>, curveCurvature: Double,
        boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
        surfaceCurvature: Double, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransCurveTransitionWithCurvature(
            tangent.x, tangent.y, tangent.z,
            curveNormal.x, curveNormal.y, curveNormal.z,
            curveCurvature,
            boundaryTangent.x, boundaryTangent.y, boundaryTangent.z,
            boundaryNormal.x, boundaryNormal.y, boundaryNormal.z,
            surfaceCurvature, tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    // MARK: - GeomFill Trihedrons (v0.68.0)

    /// Evaluate a Frenet trihedron on an edge at a parameter.
    public func frenetTrihedron(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)? {
        let f = OCCTGeomFillFrenetTrihedron(handle, param)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a constant-binormal trihedron on an edge at a parameter.
    public func constantBiNormalTrihedron(at param: Double, biNormal: SIMD3<Double>) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)? {
        let f = OCCTGeomFillConstantBiNormalTrihedron(handle, param, biNormal.x, biNormal.y, biNormal.z)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a fixed (constant) trihedron at any parameter.
    public static func fixedTrihedron(tangent: SIMD3<Double>, normal: SIMD3<Double>, at param: Double = 0) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>) {
        let f = OCCTGeomFillFixedTrihedron(tangent.x, tangent.y, tangent.z, normal.x, normal.y, normal.z, param)
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a Darboux trihedron on an edge lying on a face.
    public func darbouxTrihedron(onFace face: Shape, at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)? {
        let f = OCCTGeomFillDarbouxTrihedron(handle, face.handle, param)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    // MARK: - Polygon Interference (v0.68.0)

    /// Result of 2D polygon interference (intersection).
    public struct PolygonIntersection: Sendable {
        /// Intersection point coordinates
        public let points: [SIMD2<Double>]
    }

    /// Compute interference (intersection) between two 2D polylines.
    ///
    /// - Parameters:
    ///   - poly1: Array of 2D points forming first polyline
    ///   - poly2: Array of 2D points forming second polyline
    /// - Returns: Intersection result with points
    public static func polygonInterference(
        poly1: [SIMD2<Double>], poly2: [SIMD2<Double>]
    ) -> PolygonIntersection {
        let flat1 = poly1.flatMap { [$0.x, $0.y] }
        let flat2 = poly2.flatMap { [$0.x, $0.y] }
        let maxPts: Int32 = 100
        var outPts = [OCCTIntfPoint2D](repeating: OCCTIntfPoint2D(x: 0, y: 0), count: Int(maxPts))
        let count = flat1.withUnsafeBufferPointer { p1 in
            flat2.withUnsafeBufferPointer { p2 in
                OCCTIntfInterferencePolygon2d(p1.baseAddress!, Int32(poly1.count),
                    p2.baseAddress!, Int32(poly2.count),
                    &outPts, maxPts)
            }
        }
        var points: [SIMD2<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD2(outPts[i].x, outPts[i].y))
        }
        return PolygonIntersection(points: points)
    }

    /// Compute self-interference of a 2D polyline.
    public static func polygonSelfInterference(
        polygon: [SIMD2<Double>]
    ) -> PolygonIntersection {
        let flat = polygon.flatMap { [$0.x, $0.y] }
        let maxPts: Int32 = 100
        var outPts = [OCCTIntfPoint2D](repeating: OCCTIntfPoint2D(x: 0, y: 0), count: Int(maxPts))
        let count = flat.withUnsafeBufferPointer { p in
            OCCTIntfSelfInterferencePolygon2d(p.baseAddress!, Int32(polygon.count),
                &outPts, maxPts)
        }
        var points: [SIMD2<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD2(outPts[i].x, outPts[i].y))
        }
        return PolygonIntersection(points: points)
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
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanPoints(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    /// Find circles tangent to 3 lines.
    public static func circleTangent3Lines(
        l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
        l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
        l3Point: SIMD2<Double>, l3Dir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanLines(
            l1Point.x, l1Point.y, l1Dir.x, l1Dir.y,
            l2Point.x, l2Point.y, l2Dir.x, l2Dir.y,
            l3Point.x, l3Point.y, l3Dir.x, l3Dir.y,
            tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    /// Find circles tangent to 3 circles.
    public static func circleTangent3Circles(
        c1Center: SIMD2<Double>, c1Radius: Double,
        c2Center: SIMD2<Double>, c2Radius: Double,
        c3Center: SIMD2<Double>, c3Radius: Double,
        tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d3TanCircles(
            c1Center.x, c1Center.y, c1Radius,
            c2Center.x, c2Center.y, c2Radius,
            c3Center.x, c3Center.y, c3Radius,
            tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    /// Find circles tangent to 2 circles through 1 point.
    public static func circleTangent2CirclesPoint(
        c1Center: SIMD2<Double>, c1Radius: Double,
        c2Center: SIMD2<Double>, c2Radius: Double,
        point: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d2CirclesPoint(
            c1Center.x, c1Center.y, c1Radius,
            c2Center.x, c2Center.y, c2Radius,
            point.x, point.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    /// Find circles tangent to 1 circle through 2 points.
    public static func circleTangentCircle2Points(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        p1: SIMD2<Double>, p2: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2dCircle2Points(
            circleCenter.x, circleCenter.y, circleRadius,
            p1.x, p1.y, p2.x, p2.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    /// Find circles tangent to 2 lines through 1 point.
    public static func circleTangent2LinesPoint(
        l1Point: SIMD2<Double>, l1Dir: SIMD2<Double>,
        l2Point: SIMD2<Double>, l2Dir: SIMD2<Double>,
        point: SIMD2<Double>, tolerance: Double = 1e-6
    ) -> [Circle2DSolution] {
        let maxSols: Int32 = 16
        var sols = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(centerX: 0, centerY: 0, radius: 0), count: Int(maxSols))
        let count = OCCTGccAnaCirc2d2LinesPoint(
            l1Point.x, l1Point.y, l1Dir.x, l1Dir.y,
            l2Point.x, l2Point.y, l2Dir.x, l2Dir.y,
            point.x, point.y, tolerance, &sols, maxSols)
        return (0..<Int(count)).map { Circle2DSolution(centerX: sols[$0].centerX, centerY: sols[$0].centerY, radius: sols[$0].radius) }
    }

    // MARK: - IntTools (v0.70.0)

    /// Type of intersection common part.
    public enum CommonPartType: Int32, Sendable {
        case vertex = 0
        case edge = 1
    }

    /// Result of an edge-edge or edge-face intersection.
    public struct CommonPart: Sendable {
        /// Type of intersection (vertex or edge overlap).
        public let type: CommonPartType
        /// Parameter range on edge 1 (first, last). Same values for vertex type.
        public let param1Range: (first: Double, last: Double)
        /// Parameter range on edge 2 (first, last). Same values for vertex type.
        public let param2Range: (first: Double, last: Double)
        /// Representative 3D point of the intersection.
        public let point: SIMD3<Double>
    }

    /// Intersect two edges to find common vertices and edge overlaps.
    ///
    /// Uses IntTools_EdgeEdge to compute precise intersections.
    ///
    /// - Parameter other: Edge to intersect with
    /// - Returns: Array of common parts, or nil if intersection failed
    public func edgeEdgeIntersection(with other: Shape) -> [CommonPart]? {
        var parts: UnsafeMutablePointer<OCCTCommonPart>?
        var count: Int32 = 0
        guard OCCTIntToolsEdgeEdge(handle, other.handle, &parts, &count) else { return nil }
        defer { parts?.deallocate() }
        return (0..<Int(count)).map { i in
            let p = parts![i]
            return CommonPart(
                type: CommonPartType(rawValue: p.type) ?? .vertex,
                param1Range: (p.param1First, p.param1Last),
                param2Range: (p.param2First, p.param2Last),
                point: SIMD3(p.pointX, p.pointY, p.pointZ)
            )
        }
    }

    /// Intersect an edge with a face to find common vertices and edge overlaps.
    ///
    /// Uses IntTools_EdgeFace to compute edge-face intersections.
    ///
    /// - Parameter face: Face to intersect with
    /// - Returns: Array of common parts, or nil if intersection failed
    public func edgeFaceIntersection(with face: Shape) -> [CommonPart]? {
        var parts: UnsafeMutablePointer<OCCTCommonPart>?
        var count: Int32 = 0
        guard OCCTIntToolsEdgeFace(handle, face.handle, &parts, &count) else { return nil }
        defer { parts?.deallocate() }
        return (0..<Int(count)).map { i in
            let p = parts![i]
            return CommonPart(
                type: CommonPartType(rawValue: p.type) ?? .vertex,
                param1Range: (p.param1First, p.param1Last),
                param2Range: (p.param2First, p.param2Last),
                point: SIMD3(p.pointX, p.pointY, p.pointZ)
            )
        }
    }

    /// Result of a face-face intersection curve.
    public struct FaceFaceCurve: Sendable {
        /// Start point of the intersection curve (if bounded).
        public let start: SIMD3<Double>?
        /// End point of the intersection curve (if bounded).
        public let end: SIMD3<Double>?
    }

    /// Result of a face-face intersection point.
    public struct FaceFacePoint: Sendable {
        /// Point on face 1.
        public let pointOnFace1: SIMD3<Double>
        /// Point on face 2.
        public let pointOnFace2: SIMD3<Double>
    }

    /// Result of face-face intersection.
    public struct FaceFaceResult: Sendable {
        /// Intersection curves.
        public let curves: [FaceFaceCurve]
        /// Intersection points.
        public let points: [FaceFacePoint]
        /// Whether the faces are tangent.
        public let isTangent: Bool
    }

    /// Intersect two faces to find intersection curves and points.
    ///
    /// Uses IntTools_FaceFace with full approximation.
    ///
    /// - Parameters:
    ///   - other: Face to intersect with
    ///   - tolerance: Approximation tolerance (default 1e-7)
    /// - Returns: Face-face intersection result, or nil if failed
    public func faceFaceIntersection(with other: Shape, tolerance: Double = 1e-7) -> FaceFaceResult? {
        var curves: UnsafeMutablePointer<OCCTFaceFaceCurve>?
        var curveCount: Int32 = 0
        var points: UnsafeMutablePointer<OCCTFaceFacePoint>?
        var pointCount: Int32 = 0
        var tangent = false
        guard OCCTIntToolsFaceFace(handle, other.handle, tolerance,
                                   &curves, &curveCount,
                                   &points, &pointCount,
                                   &tangent) else { return nil }
        defer {
            curves?.deallocate()
            points?.deallocate()
        }

        let curveArray = (0..<Int(curveCount)).map { i in
            let c = curves![i]
            return FaceFaceCurve(
                start: c.hasStart ? SIMD3(c.startX, c.startY, c.startZ) : nil,
                end: c.hasEnd ? SIMD3(c.endX, c.endY, c.endZ) : nil
            )
        }

        let pointArray = (0..<Int(pointCount)).map { i in
            let p = points![i]
            return FaceFacePoint(
                pointOnFace1: SIMD3(p.x1, p.y1, p.z1),
                pointOnFace2: SIMD3(p.x2, p.y2, p.z2)
            )
        }

        return FaceFaceResult(curves: curveArray, points: pointArray, isTangent: tangent)
    }

    /// Classify a 2D point relative to a face boundary in parameter space.
    ///
    /// Uses IntTools_FClass2d to determine if a point in the face's UV parameter
    /// space is inside, on, or outside the face boundary.
    ///
    /// - Parameters:
    ///   - u: U parameter coordinate
    ///   - v: V parameter coordinate
    ///   - tolerance: Classification tolerance (default 1e-7)
    /// - Returns: Point classification
    public func classifyPoint2d(u: Double, v: Double, tolerance: Double = 1e-7) -> OCCTSwift.PointClassification {
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

    // MARK: - BOPAlgo Builder (v0.70.0)

    /// Build faces from edges on a base face surface.
    ///
    /// Uses BOPAlgo_BuilderFace to construct faces from a set of edges
    /// that lie on this face's surface.
    ///
    /// - Parameter edges: Array of edge shapes to build faces from
    /// - Returns: Array of result face shapes, or nil on failure
    public func buildFaces(from edges: [Shape]) -> [Shape]? {
        let edgeHandles = edges.map { $0.handle as OCCTShapeRef }
        var outFaces: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard edgeHandles.withUnsafeBufferPointer({ buf in
            OCCTBOPAlgoBuilderFace(handle, buf.baseAddress!, Int32(buf.count), &outFaces, &outCount)
        }) else { return nil }
        defer { outFaces?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outFaces?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Build solids from faces.
    ///
    /// Uses BOPAlgo_BuilderSolid to construct solids from a closed set of faces.
    ///
    /// - Parameter faces: Array of face shapes forming closed volumes
    /// - Returns: Array of result solid shapes, or nil on failure
    public static func buildSolids(from faces: [Shape]) -> [Shape]? {
        let faceHandles = faces.map { $0.handle as OCCTShapeRef }
        var outSolids: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard faceHandles.withUnsafeBufferPointer({ buf in
            OCCTBOPAlgoBuilderSolid(buf.baseAddress!, Int32(buf.count), &outSolids, &outCount)
        }) else { return nil }
        defer { outSolids?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outSolids?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Split a shell into connected components.
    ///
    /// Uses BOPAlgo_ShellSplitter to separate disjoint parts of a shell.
    ///
    /// - Returns: Array of shell shapes (connected components), or nil on failure
    public func splitShell() -> [Shape]? {
        var outShells: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard OCCTBOPAlgoShellSplitter(handle, &outShells, &outCount) else { return nil }
        defer { outShells?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outShells?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Convert a compound of edges into wires.
    ///
    /// Uses BOPAlgo_Tools::EdgesToWires to connect edges into wires.
    ///
    /// - Parameter tolerance: Connection tolerance (default 1e-7)
    /// - Returns: Compound of wires, or nil on failure
    public func edgesToWires(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTBOPAlgoEdgesToWires(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Convert a compound of wires into faces.
    ///
    /// Uses BOPAlgo_Tools::WiresToFaces to build planar faces from wires.
    ///
    /// - Parameter tolerance: Face building tolerance (default 1e-7)
    /// - Returns: Compound of faces, or nil on failure
    public func wiresToFaces(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTBOPAlgoWiresToFaces(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BOPTools (v0.70.0)

    /// Get the normal to a face at an edge location.
    ///
    /// Uses BOPTools_AlgoTools3D::GetNormalToFaceOnEdge.
    ///
    /// - Parameters:
    ///   - edge: Edge on the face
    ///   - face: Face containing the edge
    /// - Returns: Normal direction, or nil on failure
    public static func normalOnEdge(edge: Shape, face: Shape) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTBOPToolsNormalOnEdge(edge.handle, face.handle, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    /// Find a point strictly inside a face.
    ///
    /// Uses BOPTools_AlgoTools3D::PointInFace.
    ///
    /// - Returns: A 3D point inside this face, or nil on failure
    public func pointInFace() -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTBOPToolsPointInFace(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Check if this shape is empty (has no sub-shapes).
    ///
    /// Uses BOPTools_AlgoTools3D::IsEmptyShape.
    public var isEmpty: Bool {
        OCCTBOPToolsIsEmptyShape(handle)
    }

    /// Check if this shell is open (not all edges shared by two faces).
    ///
    /// Uses BOPTools_AlgoTools::IsOpenShell.
    public var isOpenShell: Bool {
        OCCTBOPToolsIsOpenShell(handle)
    }

    // MARK: - IntTools_BeanFaceIntersector (v0.71.0)

    /// Result of edge-face intersection using IntTools_BeanFaceIntersector.
    public struct BeanFaceIntersection: Sendable {
        /// Coincident parameter ranges on the edge curve.
        public let ranges: [(first: Double, last: Double)]
        /// Minimum square distance between edge and face.
        public let minSquareDistance: Double
    }

    /// Intersect an edge curve with a face surface to find coincident ranges.
    ///
    /// Uses IntTools_BeanFaceIntersector to find where the edge lies on the face.
    /// - Parameters:
    ///   - edge: Edge shape to test.
    ///   - face: Face shape to test against.
    /// - Returns: Intersection result with ranges and minimum distance, or nil on failure.
    public static func beanFaceIntersect(edge: Shape, face: Shape) -> BeanFaceIntersection? {
        var ranges: UnsafeMutablePointer<OCCTParameterRange>?
        var count: Int32 = 0
        var minDist: Double = 0
        guard OCCTIntToolsBeanFaceIntersect(edge.handle, face.handle, &ranges, &count, &minDist) else {
            return nil
        }
        var result: [(first: Double, last: Double)] = []
        if let ranges = ranges {
            for i in 0..<Int(count) {
                result.append((first: ranges[i].first, last: ranges[i].last))
            }
            free(ranges)
        }
        return BeanFaceIntersection(ranges: result, minSquareDistance: minDist)
    }

    // MARK: - BOPAlgo_WireSplitter (v0.71.0)

    /// Build a wire from a list of edges using BOPAlgo_WireSplitter::MakeWire.
    ///
    /// This static utility assembles edges into a connected wire.
    /// - Parameter edges: Array of edge shapes to connect.
    /// - Returns: Result wire as a shape, or nil on failure.
    public static func makeWire(from edges: [Shape]) -> Shape? {
        let handles = edges.map { $0.handle as OCCTShapeRef }
        guard let ref = handles.withUnsafeBufferPointer({ buf in
            OCCTBOPAlgoMakeWire(buf.baseAddress!, Int32(edges.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BRepFeat_SplitShape (v0.71.0)

    /// Split this shape by adding an edge to a face.
    ///
    /// Uses BRepFeat_SplitShape to split the face that the edge lies on.
    /// - Parameters:
    ///   - edge: Edge to add as split line.
    ///   - face: Face on which to add the edge.
    /// - Returns: Result shape with split face, or nil on failure.
    public func splitByEdge(_ edge: Shape, onFace face: Shape) -> Shape? {
        guard let ref = OCCTBRepFeatSplitShapeEdge(handle, edge.handle, face.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Split this shape by adding a wire to a face.
    ///
    /// Uses BRepFeat_SplitShape to split the face along the wire.
    /// - Parameters:
    ///   - wire: Wire to add as split line.
    ///   - face: Face on which to add the wire.
    /// - Returns: Result shape with split face, or nil on failure.
    public func splitByWire(_ wire: Shape, onFace face: Shape) -> Shape? {
        guard let ref = OCCTBRepFeatSplitShapeWire(handle, wire.handle, face.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Result of a split-shape operation with left/right face information.
    public struct SplitShapeResult: Sendable {
        /// The resulting split shape.
        public let shape: Shape
        /// Faces on the left side of the split.
        public let leftFaces: [Shape]
        /// Faces on the right side of the split.
        public let rightFaces: [Shape]
    }

    /// Split this shape with multiple edge-on-face pairs, returning left/right faces.
    ///
    /// Uses BRepFeat_SplitShape with Left()/Right() queries.
    /// - Parameter edgesOnFaces: Array of (edge, face) pairs. Each edge is added to the corresponding face.
    /// - Returns: Split result with left and right faces, or nil on failure.
    public func splitWithSides(edgesOnFaces: [(edge: Shape, face: Shape)]) -> SplitShapeResult? {
        var handles: [OCCTShapeRef] = []
        for pair in edgesOnFaces {
            handles.append(pair.edge.handle)
            handles.append(pair.face.handle)
        }
        var outLeft: UnsafeMutablePointer<OCCTShapeRef?>?
        var outLeftCount: Int32 = 0
        var outRight: UnsafeMutablePointer<OCCTShapeRef?>?
        var outRightCount: Int32 = 0
        guard let ref = handles.withUnsafeBufferPointer({ buf in
            OCCTBRepFeatSplitShapeWithSides(handle,
                buf.baseAddress!.withMemoryRebound(to: OCCTShapeRef.self, capacity: handles.count) { $0 },
                Int32(edgesOnFaces.count),
                &outLeft, &outLeftCount, &outRight, &outRightCount)
        }) else { return nil }

        var leftShapes: [Shape] = []
        if let outLeft = outLeft {
            for i in 0..<Int(outLeftCount) {
                if let h = outLeft[i] { leftShapes.append(Shape(handle: h)) }
            }
            free(outLeft)
        }
        var rightShapes: [Shape] = []
        if let outRight = outRight {
            for i in 0..<Int(outRightCount) {
                if let h = outRight[i] { rightShapes.append(Shape(handle: h)) }
            }
            free(outRight)
        }
        return SplitShapeResult(shape: Shape(handle: ref), leftFaces: leftShapes, rightFaces: rightShapes)
    }

    // MARK: - BRepFeat_MakeCylindricalHole (v0.71.0)

    /// Drill a through cylindrical hole in this shape.
    ///
    /// Uses BRepFeat_MakeCylindricalHole::Perform to create a through-all hole.
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHole(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> Shape? {
        guard let ref = OCCTBRepFeatCylindricalHole(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            radius) else { return nil }
        return Shape(handle: ref)
    }

    /// Drill a blind cylindrical hole in this shape.
    ///
    /// Uses BRepFeat_MakeCylindricalHole::PerformBlind for a partial-depth hole.
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    ///   - depth: Hole depth.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHoleBlind(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double, depth: Double) -> Shape? {
        guard let ref = OCCTBRepFeatCylindricalHoleBlind(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            radius, depth) else { return nil }
        return Shape(handle: ref)
    }

    /// Drill a cylindrical hole through to the next face.
    ///
    /// Uses BRepFeat_MakeCylindricalHole::PerformThruNext.
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHoleThruNext(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> Shape? {
        guard let ref = OCCTBRepFeatCylindricalHoleThruNext(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            radius) else { return nil }
        return Shape(handle: ref)
    }

    /// Status result for cylindrical hole operations.
    public enum CylindricalHoleStatus: Int32, Sendable {
        case noError = 0
        case invalidPlacement = 1
        case holeTooLong = 2
        case unknown = 3
    }

    /// Check the status of a cylindrical hole operation without modifying the shape.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Status indicating whether the hole can be drilled.
    public func cylindricalHoleStatus(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double) -> CylindricalHoleStatus {
        let raw = OCCTBRepFeatCylindricalHoleStatus(handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            radius)
        return CylindricalHoleStatus(rawValue: raw) ?? .unknown
    }

    // MARK: - BRepFeat_Gluer (v0.71.0)

    /// Glue another shape onto this shape by binding matching faces.
    ///
    /// Uses BRepFeat_Gluer to merge shapes along coincident faces.
    /// - Parameters:
    ///   - gluedShape: Shape to glue onto this shape.
    ///   - facePairs: Matching face pairs — (base face from this shape, glued face from gluedShape).
    /// - Returns: Result glued shape, or nil on failure.
    public func glue(_ gluedShape: Shape, facePairs: [(base: Shape, glued: Shape)]) -> Shape? {
        let baseFaces = facePairs.map { $0.base.handle as OCCTShapeRef }
        let gluedFaces = facePairs.map { $0.glued.handle as OCCTShapeRef }
        guard let ref = baseFaces.withUnsafeBufferPointer({ baseBuf in
            gluedFaces.withUnsafeBufferPointer({ gluedBuf in
                OCCTBRepFeatGluer(handle, gluedShape.handle,
                    baseBuf.baseAddress!, gluedBuf.baseAddress!,
                    Int32(facePairs.count))
            })
        }) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_WiresOnShape + LocOpe_Spliter (v0.71.0)

    /// Result of LocOpe_Spliter split operation.
    public struct LocOpeSplitResult: Sendable {
        /// The resulting split shape.
        public let shape: Shape
        /// Faces directly on the left of the split.
        public let directLeftFaces: [Shape]
    }

    /// Split this shape by projecting wires onto faces using LocOpe_Spliter.
    ///
    /// Uses LocOpe_WiresOnShape to bind wires to faces, then LocOpe_Spliter to split.
    /// - Parameter wiresOnFaces: Array of (wire, face) pairs to bind.
    /// - Returns: Split result with direct-left faces, or nil on failure.
    public func locOpeSplit(wiresOnFaces: [(wire: Shape, face: Shape)]) -> LocOpeSplitResult? {
        var handles: [OCCTShapeRef] = []
        for pair in wiresOnFaces {
            handles.append(pair.wire.handle)
            handles.append(pair.face.handle)
        }
        var outDirectLeft: UnsafeMutablePointer<OCCTShapeRef?>?
        var outDirectLeftCount: Int32 = 0
        guard let ref = handles.withUnsafeBufferPointer({ buf in
            OCCTLocOpeSplitByWires(handle,
                buf.baseAddress!.withMemoryRebound(to: OCCTShapeRef.self, capacity: handles.count) { $0 },
                Int32(wiresOnFaces.count),
                &outDirectLeft, &outDirectLeftCount)
        }) else { return nil }

        var dlShapes: [Shape] = []
        if let outDirectLeft = outDirectLeft {
            for i in 0..<Int(outDirectLeftCount) {
                if let h = outDirectLeft[i] { dlShapes.append(Shape(handle: h)) }
            }
            free(outDirectLeft)
        }
        return LocOpeSplitResult(shape: Shape(handle: ref), directLeftFaces: dlShapes)
    }

    /// Split this shape by automatically binding wire edges to shape faces.
    ///
    /// Uses LocOpe_WiresOnShape::Add + BindAll, then LocOpe_Spliter.
    /// - Parameter wires: Wires to project and split by.
    /// - Returns: Result shape, or nil on failure.
    public func locOpeSplitAuto(wires: [Shape]) -> Shape? {
        let wireHandles = wires.map { $0.handle as OCCTShapeRef }
        guard let ref = wireHandles.withUnsafeBufferPointer({ buf in
            OCCTLocOpeSplitByWiresAuto(handle, buf.baseAddress!, Int32(wires.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_Gluer (v0.72.0)

    /// Glue another shape onto this shape using LocOpe_Gluer with face and edge binding.
    ///
    /// - Parameters:
    ///   - gluedShape: Shape to glue.
    ///   - facePairs: At least one matching face pair required (base from this shape, glued from gluedShape).
    ///     Empty array will return nil.
    ///   - edgePairs: Optional matching edge pairs for precise alignment.
    /// - Returns: Result shape, or nil on failure (including empty facePairs).
    public func locOpeGlue(_ gluedShape: Shape,
                           facePairs: [(base: Shape, glued: Shape)],
                           edgePairs: [(base: Shape, glued: Shape)] = []) -> Shape? {
        let baseFaces = facePairs.map { $0.base.handle as OCCTShapeRef }
        let gluedFaces = facePairs.map { $0.glued.handle as OCCTShapeRef }
        let baseEdges = edgePairs.map { $0.base.handle as OCCTShapeRef? }
        let gluedEdges = edgePairs.map { $0.glued.handle as OCCTShapeRef? }

        let ref: OCCTShapeRef? = baseFaces.withUnsafeBufferPointer { baseFBuf in
            gluedFaces.withUnsafeBufferPointer { gluedFBuf in
                if edgePairs.isEmpty {
                    return OCCTLocOpeGlue(handle, gluedShape.handle,
                        baseFBuf.baseAddress!, gluedFBuf.baseAddress!,
                        Int32(facePairs.count), nil, nil, 0)
                } else {
                    return baseEdges.withUnsafeBufferPointer { baseEBuf in
                        gluedEdges.withUnsafeBufferPointer { gluedEBuf in
                            OCCTLocOpeGlue(handle, gluedShape.handle,
                                baseFBuf.baseAddress!, gluedFBuf.baseAddress!,
                                Int32(facePairs.count),
                                baseEBuf.baseAddress!, gluedEBuf.baseAddress!,
                                Int32(edgePairs.count))
                        }
                    }
                }
            }
        }
        guard let ref else { return nil }
        return Shape(handle: ref)
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
        guard let ref = OCCTChFi2dAddChamfer(handle, Int32(edge1Index), Int32(edge2Index), d1, d2) else { return nil }
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
    public func addChamfer2dAngle(edgeIndex: Int, vertexIndex: Int, distance: Double, angle: Double) -> Shape? {
        guard let ref = OCCTChFi2dAddChamferAngle(handle, Int32(edgeIndex), Int32(vertexIndex), distance, angle) else { return nil }
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
    public func modifyFillet2d(originalFace: Shape, filletEdgeIndex: Int, newRadius: Double) -> Shape? {
        guard let ref = OCCTChFi2dModifyFillet(originalFace.handle, handle, Int32(filletEdgeIndex), newRadius) else { return nil }
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
        guard let ref = OCCTChFi2dRemoveFillet(originalFace.handle, handle, Int32(filletEdgeIndex)) else { return nil }
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
        guard let ref = OCCTChFi2dRemoveChamfer(originalFace.handle, handle, Int32(chamferEdgeIndex)) else { return nil }
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
    public static func chamfer2dEdges(edge1: Shape, edge2: Shape, d1: Double, d2: Double) -> Chamfer2DEdgeResult? {
        let result = OCCTChFi2dChamferEdges(edge1.handle, edge2.handle, d1, d2)
        guard let ce = result.chamferEdge, let me1 = result.modifiedEdge1, let me2 = result.modifiedEdge2 else { return nil }
        return Chamfer2DEdgeResult(chamferEdge: Shape(handle: ce), modifiedEdge1: Shape(handle: me1), modifiedEdge2: Shape(handle: me2))
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
    public static func fillet2dEdges(edge1: Shape, edge2: Shape,
                                     planeNormal: SIMD3<Double>,
                                     radius: Double,
                                     nearPoint: SIMD3<Double>) -> Fillet2DEdgeResult? {
        let result = OCCTChFi2dFilletEdges(edge1.handle, edge2.handle,
            planeNormal.x, planeNormal.y, planeNormal.z,
            radius, nearPoint.x, nearPoint.y, nearPoint.z)
        guard let fe = result.filletEdge, let me1 = result.modifiedEdge1, let me2 = result.modifiedEdge2 else { return nil }
        return Fillet2DEdgeResult(filletEdge: Shape(handle: fe), modifiedEdge1: Shape(handle: me1),
                                  modifiedEdge2: Shape(handle: me2), solutionCount: Int(result.solutionCount))
    }

    // MARK: - FilletSurf_Builder (v0.72.0)

    /// Information about a computed fillet surface.
    public struct FilletSurfaceInfo: Sendable {
        /// The fillet surface geometry.
        public let surface: Surface
        /// First support face.
        public let supportFace1: Shape
        /// Second support face.
        public let supportFace2: Shape
        /// Approximation tolerance achieved.
        public let tolerance: Double
        /// First parameter on edge.
        public let firstParameter: Double
        /// Last parameter on edge.
        public let lastParameter: Double
        /// Start section status.
        public let startStatus: Int
        /// End section status.
        public let endStatus: Int
    }

    /// Result of fillet surface computation.
    public struct FilletSurfaceResult: Sendable {
        /// Fillet surface info for each computed surface.
        public let surfaces: [FilletSurfaceInfo]
        /// Status: 0=ok, 1=notOk, 2=partial.
        public let status: Int
    }

    /// Compute fillet surfaces on this shape using FilletSurf_Builder.
    ///
    /// Returns geometric fillet surface info (NURBS surfaces, support faces, curves)
    /// without modifying the shape topology.
    /// - Parameters:
    ///   - edges: Edges to fillet.
    ///   - radius: Fillet radius.
    /// - Returns: Fillet surface result, or nil on failure.
    public func filletSurfaces(edges: [Shape], radius: Double) -> FilletSurfaceResult? {
        let edgeHandles = edges.map { $0.handle as OCCTShapeRef }
        var outSurfaces: UnsafeMutablePointer<OCCTFilletSurfInfo>?
        var outCount: Int32 = 0
        let status = edgeHandles.withUnsafeBufferPointer { buf in
            OCCTFilletSurfBuild(handle, buf.baseAddress!, Int32(edges.count), radius, &outSurfaces, &outCount)
        }
        if status == 1 && outCount == 0 { return nil }

        var infos: [FilletSurfaceInfo] = []
        if let outSurfaces {
            for i in 0..<Int(outCount) {
                let info = outSurfaces[i]
                guard let surfH = info.surface, let sf1 = info.supportFace1, let sf2 = info.supportFace2 else { continue }
                infos.append(FilletSurfaceInfo(
                    surface: Surface(handle: surfH),
                    supportFace1: Shape(handle: sf1),
                    supportFace2: Shape(handle: sf2),
                    tolerance: info.tolerance,
                    firstParameter: info.firstParam,
                    lastParameter: info.lastParam,
                    startStatus: Int(info.startStatus),
                    endStatus: Int(info.endStatus)
                ))
            }
            free(outSurfaces)
        }
        return FilletSurfaceResult(surfaces: infos, status: Int(status))
    }

    // MARK: - v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv

    /// Fine-grained HLR edge categories for exact and polygon-based hidden line removal.
    public enum HLREdgeCategory: Int32, Sendable {
        case visibleSharp = 0       /// Visible C0-continuity (sharp) edges
        case visibleSmooth = 1      /// Visible G1-continuity (smooth) edges
        case visibleSewn = 2        /// Visible CN-continuity (sewn) edges
        case visibleOutline = 3     /// Visible silhouette/outline edges
        case visibleIso = 4         /// Visible isoparameter lines (exact HLR only)
        case visibleOutline3d = 5   /// Visible outline edges in 3D (exact HLR only)
        case hiddenSharp = 6        /// Hidden C0-continuity (sharp) edges
        case hiddenSmooth = 7       /// Hidden G1-continuity (smooth) edges
        case hiddenSewn = 8         /// Hidden CN-continuity (sewn) edges
        case hiddenOutline = 9      /// Hidden silhouette/outline edges
        case hiddenIso = 10         /// Hidden isoparameter lines (exact HLR only)
    }

    /// HLR resulting edge type for generic CompoundOfEdges and ReflectLines APIs.
    public enum HLREdgeType: Int32, Sendable {
        case undefined = 0
        case isoLine = 1
        case outLine = 2
        case rg1Line = 3   /// G1-continuity smooth
        case rgNLine = 4   /// CN-continuity sewn
        case sharp = 5     /// C0-continuity sharp
    }

    /// Get edges by fine-grained category using exact HLR (hidden line removal).
    public func hlrEdges(direction: SIMD3<Double>, category: HLREdgeCategory) -> Shape? {
        guard let h = OCCTHLRGetEdgesByCategory(handle, direction.x, direction.y, direction.z,
            OCCTHLREdgeCategory(rawValue: UInt32(category.rawValue))) else { return nil }
        return Shape(handle: h)
    }

    /// Get edges by fine-grained category using fast polygon-based HLR.
    ///
    /// Polyhedral HLR projects the shape's *triangulation*, so it is dramatically faster than
    /// exact `hlrEdges` on curved surfaces — e.g. ~48× on an analytic helicoid thread (#196).
    /// Prefer this for 2D drawings of threaded / curved solids.
    ///
    /// - Parameters:
    ///   - direction: View direction.
    ///   - category: Edge category to extract.
    ///   - deflection: Linear mesh deflection (mm) for the internal triangulation. Smaller = finer
    ///     drawing (more, shorter edges); larger = coarser and faster. Default `0.1`. Meshing is
    ///     *incremental* (`BRepMesh_IncrementalMesh`): it refines but never coarsens an existing
    ///     triangulation, so on a shape already meshed more finely (e.g. by a prior export) this
    ///     value is a floor, not an override.
    /// - Note: `.visibleIso`, `.hiddenIso`, and `.visibleOutline3d` are not available for poly HLR.
    public func hlrPolyEdges(direction: SIMD3<Double>, category: HLREdgeCategory,
                             deflection: Double = 0.1) -> Shape? {
        guard let h = OCCTHLRPolyGetEdgesByCategory(handle, direction.x, direction.y, direction.z,
            OCCTHLREdgeCategory(rawValue: UInt32(category.rawValue)), deflection) else { return nil }
        return Shape(handle: h)
    }

    /// Get edges using the generic CompoundOfEdges API from exact HLR.
    public func hlrCompoundOfEdges(direction: SIMD3<Double>, edgeType: HLREdgeType,
                                    visible: Bool, in3d: Bool) -> Shape? {
        guard let h = OCCTHLRCompoundOfEdges(handle, direction.x, direction.y, direction.z,
            edgeType.rawValue, visible, in3d) else { return nil }
        return Shape(handle: h)
    }

    /// Compute reflect (silhouette) lines on a shape.
    /// - Parameters:
    ///   - normal: View plane normal direction
    ///   - viewPoint: View target point (eye position)
    ///   - up: Up direction
    /// - Returns: Compound of reflect line edges in 3D, or nil on failure
    public func reflectLines(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                             up: SIMD3<Double>) -> Shape? {
        guard let h = OCCTHLRReflectLines(handle,
            normal.x, normal.y, normal.z,
            viewPoint.x, viewPoint.y, viewPoint.z,
            up.x, up.y, up.z) else { return nil }
        return Shape(handle: h)
    }

    /// Compute reflect lines and get specific edge types.
    public func reflectLinesFiltered(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                                      up: SIMD3<Double>, edgeType: HLREdgeType,
                                      visible: Bool, in3d: Bool) -> Shape? {
        guard let h = OCCTHLRReflectLinesFiltered(handle,
            normal.x, normal.y, normal.z,
            viewPoint.x, viewPoint.y, viewPoint.z,
            up.x, up.y, up.z,
            edgeType.rawValue, visible, in3d) else { return nil }
        return Shape(handle: h)
    }

    /// Result of edge-face transition computation.
    public struct EdgeFaceTransitionResult: Sendable {
        /// TopAbs_Orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
        public let transition: Int
        /// TopAbs_Orientation for boundary
        public let boundaryTransition: Int
    }

    /// Face interference description for edge-face transition computation.
    public struct FaceInterference: Sendable {
        public let tangent: SIMD3<Double>
        public let normal: SIMD3<Double>
        public let curvature: Double
        public let orientation: Int32      // TopAbs_Orientation
        public let transition: Int32       // TopAbs_Orientation
        public let boundaryTransition: Int32 // TopAbs_Orientation
        public let tolerance: Double

        public init(tangent: SIMD3<Double>, normal: SIMD3<Double>, curvature: Double,
                    orientation: Int32, transition: Int32, boundaryTransition: Int32,
                    tolerance: Double) {
            self.tangent = tangent
            self.normal = normal
            self.curvature = curvature
            self.orientation = orientation
            self.transition = transition
            self.boundaryTransition = boundaryTransition
            self.tolerance = tolerance
        }
    }

    /// Compute cumulated edge-face transition for multiple face interferences on an edge.
    /// - Parameters:
    ///   - edgeTangent: Edge tangent direction
    ///   - edgeNormal: Edge normal direction (zero vector for linear edges)
    ///   - edgeCurvature: Edge curvature (0 for linear edges)
    ///   - faces: Array of face interference descriptions
    /// - Returns: Transition result with cumulated orientation
    public static func edgeFaceTransition(edgeTangent: SIMD3<Double>,
                                          edgeNormal: SIMD3<Double>,
                                          edgeCurvature: Double,
                                          faces: [FaceInterference]) -> EdgeFaceTransitionResult {
        var faceTangents: [Double] = []
        var faceNormals: [Double] = []
        var faceCurvatures: [Double] = []
        var faceOrientations: [Int32] = []
        var faceTransitions: [Int32] = []
        var faceBoundaryTr: [Int32] = []
        var tolerances: [Double] = []

        for face in faces {
            faceTangents.append(contentsOf: [face.tangent.x, face.tangent.y, face.tangent.z])
            faceNormals.append(contentsOf: [face.normal.x, face.normal.y, face.normal.z])
            faceCurvatures.append(face.curvature)
            faceOrientations.append(face.orientation)
            faceTransitions.append(face.transition)
            faceBoundaryTr.append(face.boundaryTransition)
            tolerances.append(face.tolerance)
        }

        let r = OCCTTopCnxEdgeFaceTransition(
            edgeTangent.x, edgeTangent.y, edgeTangent.z,
            edgeNormal.x, edgeNormal.y, edgeNormal.z,
            edgeCurvature,
            faceTangents, faceNormals, faceCurvatures,
            faceOrientations, faceTransitions, faceBoundaryTr,
            tolerances, Int32(faces.count))

        return EdgeFaceTransitionResult(
            transition: Int(r.transition),
            boundaryTransition: Int(r.boundaryTransition))
    }
}

// MARK: - Intrv_Interval (Interval with Tolerances)

/// A real interval [start, end] with optional start/end tolerances.
public final class Interval: @unchecked Sendable {
    public let handle: OCCTIntrvIntervalRef

    /// Create an interval with bounds and optional tolerances.
    public init(start: Double, end: Double, tolStart: Float = 0, tolEnd: Float = 0) {
        handle = OCCTIntrvIntervalCreate(start, end, tolStart, tolEnd)
    }

    deinit {
        OCCTIntrvIntervalRelease(handle)
    }

    /// Interval bounds.
    public struct Bounds: Sendable {
        public let start: Double
        public let end: Double
        public let tolStart: Float
        public let tolEnd: Float
    }

    /// Get interval bounds and tolerances.
    public var bounds: Bounds {
        let b = OCCTIntrvIntervalBounds(handle)
        return Bounds(start: b.start, end: b.end, tolStart: b.tolStart, tolEnd: b.tolEnd)
    }

    /// True if the interval is probably empty (start + tolStart > end - tolEnd).
    public var isProbablyEmpty: Bool {
        OCCTIntrvIntervalIsProbablyEmpty(handle)
    }

    /// Position of this interval relative to another.
    /// Returns Intrv_Position enum value (0=Before, ..., 12=After).
    public func position(relativeTo other: Interval) -> Int {
        Int(OCCTIntrvIntervalPosition(handle, other.handle))
    }

    /// True if this interval is entirely before the other.
    public func isBefore(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsBefore(handle, other.handle)
    }

    /// True if this interval is entirely after the other.
    public func isAfter(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsAfter(handle, other.handle)
    }

    /// True if this interval is entirely inside the other.
    public func isInside(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsInside(handle, other.handle)
    }

    /// True if this interval entirely encloses the other.
    public func isEnclosing(_ other: Interval) -> Bool {
        OCCTIntrvIntervalIsEnclosing(handle, other.handle)
    }

    /// True if this interval has the same bounds as the other.
    public func isSimilar(to other: Interval) -> Bool {
        OCCTIntrvIntervalIsSimilar(handle, other.handle)
    }

    /// Set the start bound.
    public func setStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalSetStart(handle, start, tolerance)
    }

    /// Set the end bound.
    public func setEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalSetEnd(handle, end, tolerance)
    }

    /// Extend start bound outward (fuse).
    public func fuseAtStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalFuseAtStart(handle, start, tolerance)
    }

    /// Extend end bound outward (fuse).
    public func fuseAtEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalFuseAtEnd(handle, end, tolerance)
    }

    /// Cut (trim) start bound inward.
    public func cutAtStart(_ start: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalCutAtStart(handle, start, tolerance)
    }

    /// Cut (trim) end bound inward.
    public func cutAtEnd(_ end: Double, tolerance: Float = 0) {
        OCCTIntrvIntervalCutAtEnd(handle, end, tolerance)
    }
}

// MARK: - Intrv_Intervals (Sorted Non-Overlapping Interval Sequence)

/// A sorted sequence of non-overlapping intervals with set-theoretic operations.
public final class IntervalSet: @unchecked Sendable {
    public let handle: OCCTIntrvIntervalsRef

    /// Create an interval set containing a single interval.
    public init(start: Double, end: Double) {
        handle = OCCTIntrvIntervalsCreate(start, end)
    }

    /// Create an empty interval set.
    public init() {
        handle = OCCTIntrvIntervalsCreateEmpty()
    }

    deinit {
        OCCTIntrvIntervalsRelease(handle)
    }

    /// Number of intervals in the set.
    public var count: Int {
        Int(OCCTIntrvIntervalsCount(handle))
    }

    /// Get bounds of interval at index (0-based).
    public func bounds(at index: Int) -> Interval.Bounds {
        let b = OCCTIntrvIntervalsValue(handle, Int32(index + 1)) // 1-based in OCCT
        return Interval.Bounds(start: b.start, end: b.end, tolStart: b.tolStart, tolEnd: b.tolEnd)
    }

    /// Add an interval (union).
    public func unite(start: Double, end: Double) {
        OCCTIntrvIntervalsUnite(handle, start, end)
    }

    /// Subtract an interval.
    public func subtract(start: Double, end: Double) {
        OCCTIntrvIntervalsSubtract(handle, start, end)
    }

    /// Intersect with an interval.
    public func intersect(start: Double, end: Double) {
        OCCTIntrvIntervalsIntersect(handle, start, end)
    }

    /// Symmetric difference (exclusive union) with an interval.
    public func xUnite(start: Double, end: Double) {
        OCCTIntrvIntervalsXUnite(handle, start, end)
    }
}

// MARK: - ShapeRayIntersection (BRepIntCurveSurface_Inter)

/// Iterator for line/curve–shape intersection results.
public final class ShapeRayIntersection: @unchecked Sendable {
    let handle: OCCTCurveSurfaceInterRef

    /// A single intersection hit.
    public struct Hit {
        public let x: Double, y: Double, z: Double
        public let u: Double, v: Double
        public let w: Double
    }

    /// Create intersection of a line with a shape.
    public init?(shape: Shape, originX: Double, originY: Double, originZ: Double,
                 dirX: Double, dirY: Double, dirZ: Double, tolerance: Double = 1e-6) {
        guard let h = OCCTCurveSurfaceInterCreateLine(
            shape.handle, originX, originY, originZ, dirX, dirY, dirZ, tolerance) else { return nil }
        self.handle = h
    }

    /// Create intersection of a curve with a shape.
    public init?(shape: Shape, curve: Curve3D, tolerance: Double = 1e-6) {
        guard let h = OCCTCurveSurfaceInterCreateCurve(shape.handle, curve.handle, tolerance) else { return nil }
        self.handle = h
    }

    deinit { OCCTCurveSurfaceInterRelease(handle) }

    /// Check if more results are available.
    public var hasMore: Bool { OCCTCurveSurfaceInterMore(handle) }

    /// Advance to next result.
    public func next() { OCCTCurveSurfaceInterNext(handle) }

    /// Get current hit data.
    public var currentHit: Hit {
        let h = OCCTCurveSurfaceInterHit(handle)
        return Hit(x: h.x, y: h.y, z: h.z, u: h.u, v: h.v, w: h.w)
    }

    /// Get face at current hit.
    public var currentFace: Face? {
        guard let f = OCCTCurveSurfaceInterFace(handle) else { return nil }
        return Face(handle: f)
    }

    /// Collect all hits.
    public func allHits() -> [Hit] {
        var hits: [Hit] = []
        while hasMore {
            hits.append(currentHit)
            next()
        }
        return hits
    }
}

// MARK: - ShapeConstruct (Triangulation)

extension Shape {
    /// Create a triangulated face from 3D points.
    public static func triangulationFromPoints(_ points: [(Double, Double, Double)]) -> Shape? {
        var coords: [Double] = []
        for p in points {
            coords.append(p.0); coords.append(p.1); coords.append(p.2)
        }
        guard let ref = OCCTShapeConstructTriangulationFromPoints(coords, Int32(points.count)) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a triangulated face from a wire.
    public static func triangulationFromWire(_ wire: Wire) -> Shape? {
        guard let ref = OCCTShapeConstructTriangulationFromWire(wire.handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Surface Extensions (ShapeCustom_Surface periodic + gap)

extension Surface {
    /// Convert surface to periodic form. Returns nil if already periodic or not convertible.
    public func convertToPeriodic() -> Surface? {
        guard let ref = OCCTSurfaceConvertToPeriodic(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get conversion gap (distance between original and converted surface).
    public var conversionGap: Double {
        OCCTSurfaceConversionGap(handle)
    }
}

// MARK: - MeshCinert (Linear Mass Properties from Mesh)

/// Linear mass properties computed from mesh polygon points.
public struct MeshCinertResult {
    public let mass: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}

extension Edge {
    /// Prepare polygon points from a meshed edge.
    public func meshPolygonPoints() -> [(Double, Double, Double)] {
        var coords = [Double](repeating: 0, count: 3000) // up to 1000 points
        let count = OCCTMeshCinertPreparePolygon(handle, &coords, 1000)
        var points: [(Double, Double, Double)] = []
        for i in 0..<Int(count) {
            points.append((coords[i*3], coords[i*3+1], coords[i*3+2]))
        }
        return points
    }
}

/// Compute linear mass properties from polygon points.
public func meshCinertCompute(points: [(Double, Double, Double)]) -> MeshCinertResult {
    var coords: [Double] = []
    for p in points {
        coords.append(p.0); coords.append(p.1); coords.append(p.2)
    }
    let r = OCCTMeshCinertCompute(coords, Int32(points.count))
    return MeshCinertResult(mass: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ)
}

// MARK: - MeshProps (Surface/Volume Properties from Mesh)

/// Mesh property type.
public enum MeshPropsType {
    case volume
    case surface
}

/// Mesh surface/volume properties result.
public struct MeshPropsResult {
    public let mass: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}

extension Face {
    /// Compute mesh properties for a triangulated face.
    public func meshProps(type: MeshPropsType) -> MeshPropsResult {
        let t: OCCTMeshPropsType = (type == .surface) ? OCCTMeshPropsSurface : OCCTMeshPropsVolume
        let r = OCCTMeshPropsCompute(handle, t)
        return MeshPropsResult(mass: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ)
    }
}

// MARK: - MeshShapeTool (Static Mesh Utilities)

extension Face {
    /// Maximum tolerance of edges/vertices on this face.
    public var maxMeshTolerance: Double {
        OCCTMeshShapeToolMaxFaceTolerance(handle)
    }

    /// Get UV parameter points of an edge on this face.
    public func uvPoints(edge: Edge) -> (u1: Double, v1: Double, u2: Double, v2: Double)? {
        let r = OCCTMeshShapeToolUVPoints(edge.handle, handle)
        guard r.success else { return nil }
        return (r.u1, r.v1, r.u2, r.v2)
    }
}

extension Shape {
    /// Maximum dimension of the shape's bounding box (for mesh sizing).
    public var meshMaxDimension: Double {
        OCCTMeshShapeToolBoxMaxDimension(handle)
    }
}

// MARK: - ValidateEdge (BRepLib_ValidateEdge)

/// Edge validation result (3D curve vs curve-on-surface consistency).
public struct ValidateEdgeResult {
    public let isDone: Bool
    public let isWithinTolerance: Bool
    public let maxDistance: Double
    public let tolerance: Double
}

extension Edge {
    /// Validate edge geometry on a face (3D curve vs curve-on-surface consistency).
    public func validate(on face: Face, tolerance: Double = 1e-3) -> ValidateEdgeResult {
        let r = OCCTValidateEdge(handle, face.handle, tolerance)
        return ValidateEdgeResult(isDone: r.isDone, isWithinTolerance: r.isWithinTolerance,
                                   maxDistance: r.maxDistance, tolerance: r.tolerance)
    }
}

// MARK: - BiTgte_Blend (Rolling-Ball Blend)

extension Shape {
    /// Create a rolling-ball blend on specified edges.
    public func biTgteBlend(edgeIndices: [Int], radius: Double, tolerance: Double = 1e-3, nubs: Bool = false) -> Shape? {
        let indices = edgeIndices.map { Int32($0) }
        guard let ref = indices.withUnsafeBufferPointer({ buf in
            OCCTBiTgteBlend(handle, buf.baseAddress!, Int32(edgeIndices.count), radius, tolerance, nubs)
        }) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - GeomConvert_ApproxCurve/Surface

/// Continuity level for approximation.
public enum ApproxContinuity: Int32 {
    case c0 = 0, c1 = 1, c2 = 2, c3 = 3
}

/// Result of curve approximation as BSpline.
public struct ApproxCurveResult {
    public let curve: Curve3D?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}

extension Curve3D {
    /// Approximate this curve as a BSpline with detailed result (error, status).
    public func approxWithDetails(tolerance: Double, continuity: ApproxContinuity = .c2,
                                   maxSegments: Int = 100, maxDegree: Int = 8) -> ApproxCurveResult {
        let r = OCCTGeomConvertApproxCurve(handle, tolerance, continuity.rawValue,
                                            Int32(maxSegments), Int32(maxDegree))
        let curve: Curve3D? = r.curve.map { Curve3D(handle: $0) }
        return ApproxCurveResult(curve: curve, maxError: r.maxError, isDone: r.isDone, hasResult: r.hasResult)
    }
}

/// Result of surface approximation as BSpline.
public struct ApproxSurfaceResult {
    public let surface: Surface?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}

extension Surface {
    /// Approximate this surface as a BSpline with detailed result (error, status).
    public func approxWithDetails(tolerance: Double, uContinuity: ApproxContinuity = .c1,
                                   vContinuity: ApproxContinuity = .c1,
                                   maxDegree: Int = 8, maxSegments: Int = 100) -> ApproxSurfaceResult {
        let r = OCCTGeomConvertApproxSurface(handle, tolerance, uContinuity.rawValue,
                                              vContinuity.rawValue, Int32(maxDegree), Int32(maxSegments))
        let surf: Surface? = r.surface.map { Surface(handle: $0) }
        return ApproxSurfaceResult(surface: surf, maxError: r.maxError, isDone: r.isDone, hasResult: r.hasResult)
    }
}

// MARK: - GCPnts_QuasiUniformAbscissa

extension Edge {
    /// Compute quasi-uniform parameter distribution on this edge.
    public func quasiUniformParameters(count: Int) -> [Double] {
        var params = [Double](repeating: 0, count: count)
        let n = OCCTGCPntsQuasiUniform(handle, Int32(count), &params, Int32(count))
        return Array(params.prefix(Int(n)))
    }
}

// MARK: - GCPnts_TangentialDeflection

/// A sampled point from tangential deflection.
public struct TangentialDeflectionPoint {
    public let parameter: Double
    public let x: Double, y: Double, z: Double
}

extension Edge {
    /// Sample this edge using tangential deflection criteria.
    public func tangentialDeflectionPoints(angularDeflection: Double = 0.1,
                                           curvatureDeflection: Double = 0.1,
                                           minPoints: Int = 2) -> [TangentialDeflectionPoint] {
        let maxPts: Int32 = 10000
        var params = [Double](repeating: 0, count: Int(maxPts))
        var coords = [Double](repeating: 0, count: Int(maxPts) * 3)
        let n = OCCTGCPntsTangentialDeflection(handle, angularDeflection, curvatureDeflection,
                                                Int32(minPoints), &params, &coords, maxPts)
        return (0..<Int(n)).map { i in
            TangentialDeflectionPoint(parameter: params[i], x: coords[i*3], y: coords[i*3+1], z: coords[i*3+2])
        }
    }
}

// MARK: - BRepGProp_Cinert (Curve Inertia per Edge)

/// Curve inertia properties (length and center of mass).
public struct CurveInertia {
    public let length: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}

extension Edge {
    /// Compute curve linear inertia (length and center of mass).
    public var curveInertia: CurveInertia {
        let r = OCCTBRepGPropCinert(handle)
        return CurveInertia(length: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ)
    }
}

// MARK: - BRepGProp_Sinert (Surface Inertia per Face)

/// Face surface inertia properties (area and center of mass).
public struct FaceSurfaceInertia {
    public let area: Double
    public let centerX: Double, centerY: Double, centerZ: Double
    public let epsilon: Double
}

extension Face {
    /// Compute surface inertia (area and center of mass).
    public var surfaceInertia: FaceSurfaceInertia {
        let r = OCCTBRepGPropSinert(handle)
        return FaceSurfaceInertia(area: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ, epsilon: 0)
    }

    /// Compute surface inertia with adaptive integration.
    public func surfaceInertia(epsilon: Double) -> FaceSurfaceInertia {
        let r = OCCTBRepGPropSinertAdaptive(handle, epsilon)
        return FaceSurfaceInertia(area: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ, epsilon: r.epsilon)
    }
}

// MARK: - BRepGProp_Vinert (Volume Inertia per Face)

/// Face volume inertia contribution.
public struct FaceVolumeInertia {
    public let volume: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}

extension Face {
    /// Compute volume inertia contribution from this face.
    public var volumeInertia: FaceVolumeInertia {
        let r = OCCTBRepGPropVinert(handle)
        return FaceVolumeInertia(volume: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ)
    }

    /// Compute volume inertia with reference plane.
    public func volumeInertia(planeNormal: SIMD3<Double>, planeDistance: Double = 0) -> FaceVolumeInertia {
        let r = OCCTBRepGPropVinertPlane(handle, planeNormal.x, planeNormal.y, planeNormal.z, planeDistance)
        return FaceVolumeInertia(volume: r.mass, centerX: r.centerX, centerY: r.centerY, centerZ: r.centerZ)
    }
}

// MARK: - ShapeConstruct_ProjectCurveOnSurface

extension Curve3D {
    /// Project this 3D curve onto a surface as a 2D curve.
    public func projectOnSurface(_ surface: Surface, firstParam: Double? = nil,
                                  lastParam: Double? = nil, precision: Double = 1e-6) -> Curve2D? {
        let domain = self.domain
        let f = firstParam ?? domain.lowerBound
        let l = lastParam ?? domain.upperBound
        guard let ref = OCCTProjectCurveOnSurface(handle, surface.handle, f, l, precision) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - BRepPreviewAPI_MakeBox

extension Shape {
    /// Create a preview box shape (handles degenerate dimensions: face, edge, vertex).
    public static func previewBox(width: Double, height: Double, depth: Double) -> Shape? {
        guard let ref = OCCTPreviewBox(width, height, depth) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Geom 3D Entities, ShapeConstruct_Curve, Bisector (v0.76.0)

// MARK: - GeomPoint3D (Geom_CartesianPoint)

/// A 3D geometric point with Handle-based memory management.
public final class GeomPoint3D: @unchecked Sendable {
    public let handle: OCCTGeomPoint3DRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomPoint3DCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomPoint3DCreate(simd.x, simd.y, simd.z)
    }

    deinit { OCCTGeomPoint3DRelease(handle) }

    public var x: Double { OCCTGeomPoint3DX(handle) }
    public var y: Double { OCCTGeomPoint3DY(handle) }
    public var z: Double { OCCTGeomPoint3DZ(handle) }

    public var coordinates: SIMD3<Double> { SIMD3(x, y, z) }

    public func setCoordinates(x: Double, y: Double, z: Double) {
        OCCTGeomPoint3DSetCoord(handle, x, y, z)
    }

    public func distance(to other: GeomPoint3D) -> Double {
        OCCTGeomPoint3DDistance(handle, other.handle)
    }

    public func squareDistance(to other: GeomPoint3D) -> Double {
        OCCTGeomPoint3DSquareDistance(handle, other.handle)
    }

    public func translate(dx: Double, dy: Double, dz: Double) {
        OCCTGeomPoint3DTranslate(handle, dx, dy, dz)
    }
}

// MARK: - GeomDirection (Geom_Direction)

/// A 3D unit vector (always normalized).
public final class GeomDirection: @unchecked Sendable {
    public let handle: OCCTGeomDirectionRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomDirectionCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomDirectionCreate(simd.x, simd.y, simd.z)
    }

    internal init(handle: OCCTGeomDirectionRef) {
        self.handle = handle
    }

    deinit { OCCTGeomDirectionRelease(handle) }

    public var coordinates: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTGeomDirectionCoords(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public func setCoordinates(x: Double, y: Double, z: Double) {
        OCCTGeomDirectionSetCoord(handle, x, y, z)
    }

    /// Cross product with another direction. Returns nil if parallel.
    public func crossed(with other: GeomDirection) -> GeomDirection? {
        guard let ref = OCCTGeomDirectionCrossed(handle, other.handle) else { return nil }
        return GeomDirection(handle: ref)
    }
}

// MARK: - GeomVector3D (Geom_VectorWithMagnitude)

/// A 3D vector with magnitude (can have zero length).
public final class GeomVector3D: @unchecked Sendable {
    public let handle: OCCTGeomVector3DRef

    public init(x: Double, y: Double, z: Double) {
        handle = OCCTGeomVector3DCreate(x, y, z)
    }

    public init(simd: SIMD3<Double>) {
        handle = OCCTGeomVector3DCreate(simd.x, simd.y, simd.z)
    }

    public init(from p1: SIMD3<Double>, to p2: SIMD3<Double>) {
        handle = OCCTGeomVector3DFromPoints(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)
    }

    internal init(handle: OCCTGeomVector3DRef) {
        self.handle = handle
    }

    deinit { OCCTGeomVector3DRelease(handle) }

    public var coordinates: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTGeomVector3DCoords(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var magnitude: Double { OCCTGeomVector3DMagnitude(handle) }

    public func dot(_ other: GeomVector3D) -> Double {
        OCCTGeomVector3DDot(handle, other.handle)
    }

    public func added(_ other: GeomVector3D) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DAdded(handle, other.handle))
    }

    public func multiplied(by scalar: Double) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DMultiplied(handle, scalar))
    }

    /// Returns normalized copy. Nil if magnitude is near zero.
    public func normalized() -> GeomVector3D? {
        guard let ref = OCCTGeomVector3DNormalized(handle) else { return nil }
        return GeomVector3D(handle: ref)
    }

    public func crossed(_ other: GeomVector3D) -> GeomVector3D {
        GeomVector3D(handle: OCCTGeomVector3DCrossed(handle, other.handle))
    }
}

// MARK: - Axis1Placement (Geom_Axis1Placement)

/// A 3D axis defined by an origin point and a direction.
public final class Axis1Placement: @unchecked Sendable {
    public let handle: OCCTAxis1PlacementRef

    public init(origin: SIMD3<Double>, direction: SIMD3<Double>) {
        handle = OCCTAxis1PlacementCreate(origin.x, origin.y, origin.z,
                                           direction.x, direction.y, direction.z)
    }

    internal init(handle: OCCTAxis1PlacementRef) {
        self.handle = handle
    }

    deinit { OCCTAxis1PlacementRelease(handle) }

    public var location: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis1PlacementLocation(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var direction: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis1PlacementDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Reverse the direction in place.
    public func reverse() {
        OCCTAxis1PlacementReverse(handle)
    }

    /// Return a new axis with reversed direction.
    public func reversed() -> Axis1Placement {
        Axis1Placement(handle: OCCTAxis1PlacementReversed(handle))
    }

    public func setDirection(_ dir: SIMD3<Double>) {
        OCCTAxis1PlacementSetDirection(handle, dir.x, dir.y, dir.z)
    }

    public func setLocation(_ loc: SIMD3<Double>) {
        OCCTAxis1PlacementSetLocation(handle, loc.x, loc.y, loc.z)
    }
}

// MARK: - Axis2Placement (Geom_Axis2Placement)

/// A 3D right-handed coordinate system (origin, main direction, X direction).
public final class Axis2Placement: @unchecked Sendable {
    public let handle: OCCTAxis2PlacementRef

    public init(origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>) {
        handle = OCCTAxis2PlacementCreate(origin.x, origin.y, origin.z,
                                           normal.x, normal.y, normal.z,
                                           xDirection.x, xDirection.y, xDirection.z)
    }

    deinit { OCCTAxis2PlacementRelease(handle) }

    public var location: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis2PlacementLocation(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var mainDirection: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis2PlacementDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var xDirection: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis2PlacementXDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public var yDirection: SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTAxis2PlacementYDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    public func setDirection(_ dir: SIMD3<Double>) {
        OCCTAxis2PlacementSetDirection(handle, dir.x, dir.y, dir.z)
    }

    public func setXDirection(_ dir: SIMD3<Double>) {
        OCCTAxis2PlacementSetXDirection(handle, dir.x, dir.y, dir.z)
    }
}

// MARK: - ShapeConstruct_Curve extensions

extension Curve3D {
    /// Convert this curve segment to a BSpline using ShapeConstruct_Curve.
    public func convertSegmentToBSpline(first: Double, last: Double, precision: Double = 1e-6) -> Curve3D? {
        guard let ref = OCCTShapeConstructConvertToBSpline3D(handle, first, last, precision) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Adjust curve endpoints to match given points.
    public func adjustEndpoints(start: SIMD3<Double>, end: SIMD3<Double>) -> Bool {
        OCCTShapeConstructAdjustCurve3D(handle, start.x, start.y, start.z, end.x, end.y, end.z)
    }
}

extension Curve2D {
    /// Convert this 2D curve segment to a BSpline using ShapeConstruct_Curve.
    public func convertSegmentToBSpline(first: Double, last: Double, precision: Double = 1e-6) -> Curve2D? {
        guard let ref = OCCTShapeConstructConvertToBSpline2D(handle, first, last, precision) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Adjust 2D curve endpoints to match given points.
    public func adjustEndpoints(start: (Double, Double), end: (Double, Double)) -> Bool {
        OCCTShapeConstructAdjustCurve2D(handle, start.0, start.1, end.0, end.1)
    }
}

// MARK: - Bisector utilities

/// Point on a bisector curve with parameter and distance information.
public struct BisectorPoint {
    public let paramOnC1: Double
    public let paramOnC2: Double
    public let paramOnBis: Double
    public let distance: Double
    public let x: Double
    public let y: Double
    public let isInfinite: Bool
}

/// Result of bisector intersection computation.
public struct BisectorIntersection {
    public let x: Double
    public let y: Double
    public let paramOnFirst: Double
    public let paramOnSecond: Double
}

/// Compute intersections between perpendicular bisectors of two point pairs.
/// The bisector of (a,b) is intersected with the bisector of (c,d).
/// Returns intersection points (the circumcenter for triangle problems).
public func bisectorIntersections(
    a: (Double, Double), b: (Double, Double),
    c: (Double, Double), d: (Double, Double)
) -> [BisectorIntersection] {
    var points = [OCCTBisectorIntersectionPoint](repeating: OCCTBisectorIntersectionPoint(), count: 10)
    let count = points.withUnsafeMutableBufferPointer { buf in
        OCCTBisectorInterPointPoint(a.0, a.1, b.0, b.1,
                                     c.0, c.1, d.0, d.1,
                                     buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(count)).map { i in
        BisectorIntersection(x: points[i].x, y: points[i].y,
                             paramOnFirst: points[i].paramOnFirst,
                             paramOnSecond: points[i].paramOnSecond)
    }
}

// MARK: - GeomLib_Tool (Parameter Finding)

extension Curve3D {
    /// Find the parameter of a 3D point on this curve.
    /// Returns nil if the point is beyond maxDistance from the curve.
    public func parameterOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> Double? {
        var param: Double = 0
        let ok = OCCTGeomLibToolParameter3D(handle, point.x, point.y, point.z, maxDistance, &param)
        return ok ? param : nil
    }
}

extension Surface {
    /// Find the UV parameters of a 3D point on this surface.
    /// Returns nil if the point is beyond maxDistance from the surface.
    public func parametersOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> (u: Double, v: Double)? {
        var u: Double = 0, v: Double = 0
        let ok = OCCTGeomLibToolParametersSurface(handle, point.x, point.y, point.z, maxDistance, &u, &v)
        return ok ? (u, v) : nil
    }
}

extension Curve2D {
    /// Find the parameter of a 2D point on this curve.
    /// Returns nil if the point is beyond maxDistance from the curve.
    public func parameterOf(point: SIMD2<Double>, maxDistance: Double = 1.0) -> Double? {
        var param: Double = 0
        let ok = OCCTGeomLibToolParameter2D(handle, point.x, point.y, maxDistance, &param)
        return ok ? param : nil
    }
}

// MARK: - GeomLib_IsPlanarSurface

extension Surface {
    /// Check if this surface is planar within tolerance.
    public func isPlanar(tolerance: Double = 1e-7) -> Bool {
        OCCTGeomLibIsPlanarSurface(handle, tolerance)
    }

    /// If planar, returns the plane parameters: origin, normal, X direction.
    /// Returns nil if the surface is not planar.
    public func planarPlane(tolerance: Double = 1e-7) -> (origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>)? {
        var ox: Double = 0, oy: Double = 0, oz: Double = 0
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        var xx: Double = 0, xy: Double = 0, xz: Double = 0
        let ok = OCCTGeomLibPlanarSurfacePlane(handle, tolerance,
                                                &ox, &oy, &oz, &nx, &ny, &nz, &xx, &xy, &xz)
        guard ok else { return nil }
        return (SIMD3(ox, oy, oz), SIMD3(nx, ny, nz), SIMD3(xx, xy, xz))
    }
}

// MARK: - GeomLib_CheckBSplineCurve / Check2dBSplineCurve

extension Curve3D {
    /// Check if this BSpline curve has reversed end tangents.
    /// Returns (needFixFirst, needFixLast) or nil if not a BSpline or check failed.
    public func checkBSplineTangents(tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> (fixFirst: Bool, fixLast: Bool)? {
        var first = false, last = false
        let ok = OCCTGeomLibCheckBSpline3D(handle, tolerance, angularTolerance, &first, &last)
        return ok ? (first, last) : nil
    }

    /// Fix reversed end tangents on a BSpline curve. Returns new curve or nil.
    public func fixBSplineTangents(fixFirst: Bool, fixLast: Bool,
                                    tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> Curve3D? {
        guard let ref = OCCTGeomLibFixBSpline3D(handle, tolerance, angularTolerance, fixFirst, fixLast) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve2D {
    /// Check if this BSpline 2D curve has reversed end tangents.
    /// Returns (needFixFirst, needFixLast) or nil if not a BSpline or check failed.
    public func checkBSplineTangents(tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> (fixFirst: Bool, fixLast: Bool)? {
        var first = false, last = false
        let ok = OCCTGeomLibCheckBSpline2D(handle, tolerance, angularTolerance, &first, &last)
        return ok ? (first, last) : nil
    }

    /// Fix reversed end tangents on a BSpline 2D curve. Returns new curve or nil.
    public func fixBSplineTangents(fixFirst: Bool, fixLast: Bool,
                                    tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> Curve2D? {
        guard let ref = OCCTGeomLibFixBSpline2D(handle, tolerance, angularTolerance, fixFirst, fixLast) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GeomLib_Interpolate

extension Curve3D {
    /// Create a BSpline curve by polynomial interpolation of points at given parameters.
    public static func polynomialInterpolation(degree: Int, points: [SIMD3<Double>], parameters: [Double]) -> Curve3D? {
        guard points.count == parameters.count, points.count >= 2 else { return nil }
        var xyz = [Double]()
        xyz.reserveCapacity(points.count * 3)
        for p in points { xyz.append(p.x); xyz.append(p.y); xyz.append(p.z) }
        guard let ref = OCCTGeomLibInterpolate(Int32(degree), Int32(points.count), xyz, parameters) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GccAna_Circ2d2TanRad

/// Circle solution in 2D (center + radius).
public struct Circle2DSolution: Sendable {
    public let center: SIMD2<Double>
    public let radius: Double
}

/// Find circles tangent to two lines with given radius.
public func circlesTangentToLines(_ l1Origin: SIMD2<Double>, _ l1Direction: SIMD2<Double>,
                                   _ l2Origin: SIMD2<Double>, _ l2Direction: SIMD2<Double>,
                                   radius: Double, tolerance: Double = 1e-6) -> [Circle2DSolution] {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 8)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2d2TanRadLineLin(l1Origin.x, l1Origin.y, l1Direction.x, l1Direction.y,
                                        l2Origin.x, l2Origin.y, l2Direction.x, l2Direction.y,
                                        radius, tolerance, buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Circle2DSolution(center: SIMD2(solutions[i].centerX, solutions[i].centerY),
                         radius: solutions[i].radius)
    }
}

/// Find circles through two points with given radius.
public func circlesThroughPointsWithRadius(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                                            radius: Double, tolerance: Double = 1e-6) -> [Circle2DSolution] {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 8)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2d2TanRadPntPnt(p1.x, p1.y, p2.x, p2.y, radius, tolerance,
                                       buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Circle2DSolution(center: SIMD2(solutions[i].centerX, solutions[i].centerY),
                         radius: solutions[i].radius)
    }
}

// MARK: - GccAna_Circ2dTanCen

/// Find circle centered at a point passing through another point.
public func circleThroughPointCentered(point: SIMD2<Double>, center: SIMD2<Double>) -> Circle2DSolution? {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2dTanCenPntPnt(point.x, point.y, center.x, center.y,
                                      buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Circle2DSolution(center: SIMD2(solutions[0].centerX, solutions[0].centerY),
                            radius: solutions[0].radius)
}

/// Find circle tangent to a line centered at a point.
public func circleTangentToLineCentered(lineOrigin: SIMD2<Double>, lineDirection: SIMD2<Double>,
                                         center: SIMD2<Double>) -> Circle2DSolution? {
    var solutions = [OCCTCircle2DSolution](repeating: OCCTCircle2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaCirc2dTanCenLinPnt(lineOrigin.x, lineOrigin.y, lineDirection.x, lineDirection.y,
                                      center.x, center.y, buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Circle2DSolution(center: SIMD2(solutions[0].centerX, solutions[0].centerY),
                            radius: solutions[0].radius)
}

// MARK: - GccAna_Lin2d2Tan

/// Line solution in 2D (origin + direction).
public struct Line2DSolution: Sendable {
    public let origin: SIMD2<Double>
    public let direction: SIMD2<Double>
}

/// Find line through two points.
public func lineThroughPoints(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                               tolerance: Double = 1e-6) -> Line2DSolution? {
    var solutions = [OCCTLine2DSolution](repeating: OCCTLine2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaLin2d2TanPntPnt(p1.x, p1.y, p2.x, p2.y, tolerance,
                                   buf.baseAddress, Int32(buf.count))
    }
    guard n > 0 else { return nil }
    return Line2DSolution(origin: SIMD2(solutions[0].originX, solutions[0].originY),
                          direction: SIMD2(solutions[0].dirX, solutions[0].dirY))
}

/// Find lines tangent to a circle through a point.
public func linesTangentToCircleThroughPoint(circleCenter: SIMD2<Double>, circleRadius: Double,
                                              point: SIMD2<Double>,
                                              tolerance: Double = 1e-6) -> [Line2DSolution] {
    var solutions = [OCCTLine2DSolution](repeating: OCCTLine2DSolution(), count: 4)
    let n = solutions.withUnsafeMutableBufferPointer { buf in
        OCCTGccAnaLin2d2TanCircPnt(circleCenter.x, circleCenter.y, circleRadius,
                                    point.x, point.y, tolerance,
                                    buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(n)).map { i in
        Line2DSolution(origin: SIMD2(solutions[i].originX, solutions[i].originY),
                       direction: SIMD2(solutions[i].dirX, solutions[i].dirY))
    }
}

// MARK: - Approx_SameParameter

/// Result of same-parameter check between 3D and 2D curves on a surface.
public struct SameParameterResult: Sendable {
    /// True if the curves already have the same parameterization.
    public let isSameParameter: Bool
    /// Maximum distance between the 3D curve and the surface evaluation of the 2D curve.
    public let toleranceReached: Double
}

extension Curve3D {
    /// Check if a 2D curve on a surface has the same parameterization as this 3D curve.
    public func checkSameParameter(curve2D: Curve2D, surface: Surface,
                                    tolerance: Double = 1e-6) -> SameParameterResult? {
        var isSame = false
        var tolReached: Double = 0
        let ok = OCCTApproxSameParameter(handle, curve2D.handle, surface.handle,
                                          tolerance, &isSame, &tolReached)
        guard ok else { return nil }
        return SameParameterResult(isSameParameter: isSame, toleranceReached: tolReached)
    }
}

// MARK: - ShapeUpgrade Curve Splitting

extension Curve3D {
    /// Split this 3D curve at continuity breaks.
    /// Criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve3D] {
        var refs = [OCCTCurve3DRef?](repeating: nil, count: 32)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTSplitCurve3dContinuity(handle, Int32(criterion), tolerance,
                                        buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve3D(handle: ref)
        }
    }
}

extension Curve2D {
    /// Split this 2D curve at continuity breaks.
    /// Criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 32)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTSplitCurve2dContinuity(handle, Int32(criterion), tolerance,
                                        buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }

    /// Convert this 2D curve to Bezier segments (via ShapeUpgrade).
    public func convertToBezierSegments() -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 64)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTConvertCurve2dToBezier(handle, buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }

    /// Approximate this 2D curve as arcs and line segments.
    public func approxArcsAndSegments(tolerance: Double, angleTolerance: Double) -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 256)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTGeom2dConvertApproxArcsSegments(handle, tolerance, angleTolerance,
                                                  buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }
}

// MARK: - Shape Modifications, Surface Recognition, Polygon Data (v0.78.0)

// MARK: - Shape Modifications

extension Shape {
    /// Apply a transformation matrix via BRepTools_TrsfModification.
    /// The 3x4 matrix is specified as row-major (a11..a14, a21..a24, a31..a34).
    public static func trsfModification(_ shape: Shape,
                                          a11: Double, a12: Double, a13: Double, a14: Double,
                                          a21: Double, a22: Double, a23: Double, a24: Double,
                                          a31: Double, a32: Double, a33: Double, a34: Double) -> Shape? {
        guard let ref = OCCTShapeTrsfModification(shape.handle,
                                                    a11, a12, a13, a14,
                                                    a21, a22, a23, a24,
                                                    a31, a32, a33, a34) else { return nil }
        return Shape(handle: ref)
    }

    /// Apply a general transformation matrix via BRepTools_GTrsfModification.
    /// Supports non-uniform scaling. Shape should be NURBS-converted first for non-affine transforms.
    public static func gtrsfModification(_ shape: Shape,
                                           a11: Double, a12: Double, a13: Double, a14: Double,
                                           a21: Double, a22: Double, a23: Double, a24: Double,
                                           a31: Double, a32: Double, a33: Double, a34: Double) -> Shape? {
        guard let ref = OCCTShapeGTrsfModification(shape.handle,
                                                     a11, a12, a13, a14,
                                                     a21, a22, a23, a24,
                                                     a31, a32, a33, a34) else { return nil }
        return Shape(handle: ref)
    }

    /// Deep copy a shape via BRepTools_CopyModification.
    public static func deepCopy(_ shape: Shape, copyGeometry: Bool = true, copyMesh: Bool = true) -> Shape? {
        guard let ref = OCCTShapeCopyModification(shape.handle, copyGeometry, copyMesh) else { return nil }
        return Shape(handle: ref)
    }

    /// Restrict BSpline degree and segments with full control (advanced version).
    public static func bsplineRestrictionAdvanced(_ shape: Shape,
                                                    approxSurface: Bool = true,
                                                    approxCurve3d: Bool = true,
                                                    approxCurve2d: Bool = true,
                                                    tol3d: Double = 0.01,
                                                    tol2d: Double = 0.01,
                                                    continuity3d: Int = 2,
                                                    continuity2d: Int = 2,
                                                    maxDegree: Int = 5,
                                                    maxSegments: Int = 20,
                                                    priorityDegree: Bool = true,
                                                    convertRational: Bool = false) -> Shape? {
        guard let ref = OCCTShapeBSplineRestrictionAdvanced(shape.handle,
                                                              approxSurface, approxCurve3d, approxCurve2d,
                                                              tol3d, tol2d,
                                                              Int32(continuity3d), Int32(continuity2d),
                                                              Int32(maxDegree), Int32(maxSegments),
                                                              priorityDegree, convertRational) else { return nil }
        return Shape(handle: ref)
    }

    /// Convert surfaces to BSpline with per-type control.
    public static func convertToBSplineAdvanced(_ shape: Shape,
                                                  extrusionMode: Bool = true,
                                                  revolutionMode: Bool = true,
                                                  offsetMode: Bool = true,
                                                  planeMode: Bool = false) -> Shape? {
        guard let ref = OCCTShapeConvertToBSplineAdvanced(shape.handle,
                                                            extrusionMode, revolutionMode,
                                                            offsetMode, planeMode) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Surface Splitting

extension Surface {
    /// Result of surface splitting.
    public struct SplitResult: Sendable {
        public let uSplitCount: Int
        public let vSplitCount: Int
    }

    /// Split this surface by continuity criterion (ShapeUpgrade variant).
    /// criterion: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN
    /// Returns split counts for U and V directions.
    public func splitSurfaceByContinuity(criterion: Int, tolerance: Double) -> SplitResult? {
        var uCount: Int32 = 0
        var vCount: Int32 = 0
        let n = OCCTSplitSurfaceContinuity(handle, Int32(criterion), tolerance, &uCount, &vCount)
        if n == 0 { return nil }
        return SplitResult(uSplitCount: Int(uCount), vSplitCount: Int(vCount))
    }

    /// Split this surface by maximum angle (radians).
    public func splitByAngle(_ maxAngle: Double) -> SplitResult? {
        var uCount: Int32 = 0
        var vCount: Int32 = 0
        let n = OCCTSplitSurfaceAngle(handle, maxAngle, &uCount, &vCount)
        if n == 0 { return nil }
        return SplitResult(uSplitCount: Int(uCount), vSplitCount: Int(vCount))
    }

    /// Split this surface into approximately equal-area parts.
    public func splitByArea(parts: Int, intoSquares: Bool = false) -> SplitResult? {
        var uCount: Int32 = 0
        var vCount: Int32 = 0
        let n = OCCTSplitSurfaceArea(handle, Int32(parts), intoSquares, &uCount, &vCount)
        if n == 0 { return nil }
        return SplitResult(uSplitCount: Int(uCount), vSplitCount: Int(vCount))
    }
}

// MARK: - Curve/Surface Recognition

/// Result of converting a curve to its analytical form.
public struct CurveToAnalyticalResult: Sendable {
    public let curve: Curve3D
    public let newFirst: Double
    public let newLast: Double
    public let gap: Double
}

extension Curve3D {
    /// Attempt to convert this curve to an analytical form (line, circle, ellipse).
    public func toAnalytical(tolerance: Double, first: Double, last: Double) -> CurveToAnalyticalResult? {
        let result = OCCTGeomConvertCurveToAnalytical(handle, tolerance, first, last)
        guard result.success, let curveRef = result.curve else { return nil }
        return CurveToAnalyticalResult(
            curve: Curve3D(handle: curveRef),
            newFirst: result.newFirst,
            newLast: result.newLast,
            gap: result.gap
        )
    }

    /// Check if a set of 3D points are collinear within tolerance.
    public static func arePointsLinear(_ points: [SIMD3<Double>], tolerance: Double) -> (isLinear: Bool, deviation: Double) {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
        }
        var deviation: Double = 0
        let result = flat.withUnsafeBufferPointer { buf in
            OCCTGeomConvertIsLinear(buf.baseAddress!, Int32(points.count), tolerance, &deviation)
        }
        return (result, deviation)
    }
}

/// Result of converting a surface to its analytical form.
public struct SurfaceToAnalyticalResult: Sendable {
    public let surface: Surface
    public let gap: Double
}

extension Surface {
    /// Attempt to convert this surface to an analytical form with detailed result.
    public func toAnalyticalWithGap(tolerance: Double) -> SurfaceToAnalyticalResult? {
        let result = OCCTGeomConvertSurfToAnalytical(handle, tolerance)
        guard result.success, let surfRef = result.surface else { return nil }
        return SurfaceToAnalyticalResult(surface: Surface(handle: surfRef), gap: result.gap)
    }

    /// Attempt to convert this surface to analytical form within UV bounds.
    public func toAnalyticalWithGap(tolerance: Double,
                                      uMin: Double, uMax: Double,
                                      vMin: Double, vMax: Double) -> SurfaceToAnalyticalResult? {
        let result = OCCTGeomConvertSurfToAnalyticalBounded(handle, tolerance, uMin, uMax, vMin, vMax)
        guard result.success, let surfRef = result.surface else { return nil }
        return SurfaceToAnalyticalResult(surface: Surface(handle: surfRef), gap: result.gap)
    }

    /// Check if this surface is already a canonical (analytical) form.
    public var isCanonical: Bool {
        OCCTGeomConvertIsCanonical(handle)
    }
}

// MARK: - Polygon2D

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
            flat.append(p.x); flat.append(p.y)
        }
        guard let ref = flat.withUnsafeBufferPointer({ buf in
            OCCTPolyPolygon2DCreate(buf.baseAddress!, Int32(points.count))
        }) else { return nil }
        return Polygon2D(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int {
        Int(OCCTPolyPolygon2DNbNodes(handle))
    }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD2<Double>? {
        var x: Double = 0, y: Double = 0
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
}

// MARK: - Triangulation (v0.160.0)

/// A `Poly_Triangulation` — a 3D mesh defined by node positions and triangle vertex indices.
///
/// Used as input to `TopologyGraph.createTriangulationRep(_:)` when populating the cached
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
            flatNodes.append(n.x); flatNodes.append(n.y); flatNodes.append(n.z)
        }
        let triInts = triangles.map { Int32($0) }
        guard let ref = flatNodes.withUnsafeBufferPointer({ nodeBuf in
            triInts.withUnsafeBufferPointer { triBuf in
                OCCTPolyTriangulationCreate(
                    nodeBuf.baseAddress!, Int32(nodes.count),
                    triBuf.baseAddress!, Int32(triangles.count / 3))
            }
        }) else { return nil }
        return Triangulation(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int { Int(OCCTPolyTriangulationNbNodes(handle)) }

    /// Number of triangles.
    public var triangleCount: Int { Int(OCCTPolyTriangulationNbTriangles(handle)) }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTPolyTriangulationNode(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get triangle's three node indices at the given triangle index (0-based; returns 0-based vertex indices).
    public func triangle(at index: Int) -> (Int, Int, Int)? {
        var n1: Int32 = 0, n2: Int32 = 0, n3: Int32 = 0
        guard OCCTPolyTriangulationTriangle(handle, Int32(index), &n1, &n2, &n3) else { return nil }
        return (Int(n1), Int(n2), Int(n3))
    }

    /// Deflection value.
    public var deflection: Double {
        get { OCCTPolyTriangulationDeflection(handle) }
        set { OCCTPolyTriangulationSetDeflection(handle, newValue) }
    }
}

// MARK: - Polygon3D

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
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
        }
        guard let ref = flat.withUnsafeBufferPointer({ buf in
            OCCTPolyPolygon3DCreate(buf.baseAddress!, Int32(points.count))
        }) else { return nil }
        return Polygon3D(handle: ref)
    }

    /// Create a 3D polygon from points with parameters.
    public static func create(points: [SIMD3<Double>], parameters: [Double]) -> Polygon3D? {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
        }
        guard let ref = flat.withUnsafeBufferPointer({ ptsBuf in
            parameters.withUnsafeBufferPointer { paramBuf in
                OCCTPolyPolygon3DCreateWithParams(ptsBuf.baseAddress!, Int32(points.count), paramBuf.baseAddress!)
            }
        }) else { return nil }
        return Polygon3D(handle: ref)
    }

    /// Number of nodes.
    public var nodeCount: Int {
        Int(OCCTPolyPolygon3DNbNodes(handle))
    }

    /// Get node at index (0-based).
    public func node(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
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

// MARK: - PolygonOnTriangulation

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
        guard let ref = nodeIndices.withUnsafeBufferPointer({ buf in
            OCCTPolyPolygonOnTriCreate(buf.baseAddress!, Int32(nodeIndices.count))
        }) else { return nil }
        return PolygonOnTriangulation(handle: ref)
    }

    /// Create from node indices with parameters.
    public static func create(nodeIndices: [Int32], parameters: [Double]) -> PolygonOnTriangulation? {
        guard let ref = nodeIndices.withUnsafeBufferPointer({ idxBuf in
            parameters.withUnsafeBufferPointer { paramBuf in
                OCCTPolyPolygonOnTriCreateWithParams(idxBuf.baseAddress!, Int32(nodeIndices.count), paramBuf.baseAddress!)
            }
        }) else { return nil }
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
}

// MARK: - Mesh Node Merging

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
public func mergedMeshNodes(from shape: Shape,
                              smoothAngle: Double,
                              mergeTolerance: Double = 0.0) -> MergedMeshData? {
    let maxVerts: Int32 = 1_000_000
    let maxIdx: Int32 = 3_000_000
    var vertices = [Float](repeating: 0, count: Int(maxVerts) * 3)
    var normals = [Float](repeating: 0, count: Int(maxVerts) * 3)
    var indices = [UInt32](repeating: 0, count: Int(maxIdx))
    var triCount: Int32 = 0

    let nVerts = vertices.withUnsafeMutableBufferPointer { vBuf in
        normals.withUnsafeMutableBufferPointer { nBuf in
            indices.withUnsafeMutableBufferPointer { iBuf in
                OCCTPolyMergeNodes(shape.handle, smoothAngle, mergeTolerance,
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
    var verts = [SIMD3<Float>]()
    verts.reserveCapacity(nv)
    var norms = [SIMD3<Float>]()
    norms.reserveCapacity(nv)
    for i in 0..<nv {
        verts.append(SIMD3(vertices[i*3], vertices[i*3+1], vertices[i*3+2]))
        norms.append(SIMD3(normals[i*3], normals[i*3+1], normals[i*3+2]))
    }
    let idxSlice = Array(indices.prefix(nt * 3))

    return MergedMeshData(vertices: verts, normals: norms, indices: idxSlice,
                            triangleCount: nt, vertexCount: nv)
}

// MARK: - Poly_CoherentTriangulation, BRepFill, BRepExtrema, BRepGProp, GeomFill, ShapeFix (v0.79.0)

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
    public static func createFromMesh(_ shape: Shape, deflection: Double = 0.1) -> CoherentTriangulation? {
        guard let ref = OCCTCoherentTriangulationCreateFromMesh(shape.handle, deflection) else { return nil }
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
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTCoherentTriangulationNodeCoords(handle, Int32(index), &x, &y, &z) else { return nil }
        return (x, y, z)
    }
}

// MARK: - BRepFill_Evolved

extension Shape {
    /// Create an evolved shape from a face spine and wire profile.
    public static func evolved(spineFace: Shape, profileWire: Shape,
                               axisOrigin: SIMD3<Double> = SIMD3(0, 0, 0),
                               axisNormal: SIMD3<Double> = SIMD3(0, 0, 1),
                               axisXDir: SIMD3<Double> = SIMD3(1, 0, 0),
                               joinType: Int = 0, makeSolid: Bool = false) -> Shape? {
        guard let ref = OCCTBRepFillEvolved(spineFace.handle, profileWire.handle,
                                             axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                             axisNormal.x, axisNormal.y, axisNormal.z,
                                             axisXDir.x, axisXDir.y, axisXDir.z,
                                             Int32(joinType), makeSolid) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepFill_OffsetAncestors

/// Traces ancestry of edges in an offset wire back to original edges.
public final class OffsetAncestors: @unchecked Sendable {
    let handle: OCCTOffsetAncestorsRef

    init(handle: OCCTOffsetAncestorsRef) {
        self.handle = handle
    }

    deinit {
        OCCTBRepFillOffsetAncestorsRelease(handle)
    }

    /// Create offset ancestors from a face with given offset distance.
    /// joinType: 0=Arc, 1=Tangent, 2=Intersection
    public static func create(face: Shape, offset: Double, joinType: Int = 0) -> OffsetAncestors? {
        guard let ref = OCCTBRepFillOffsetAncestorsCreate(face.handle, offset, Int32(joinType)) else { return nil }
        return OffsetAncestors(handle: ref)
    }

    /// Whether the offset and ancestry computation succeeded.
    public var isDone: Bool {
        OCCTBRepFillOffsetAncestorsIsDone(handle)
    }

    /// Check if an edge has an ancestor in the original wire.
    public func hasAncestor(_ edge: Shape) -> Bool {
        OCCTBRepFillOffsetAncestorsHasAncestor(handle, edge.handle)
    }

    /// Get the ancestor shape of an offset edge.
    public func ancestor(of edge: Shape) -> Shape? {
        guard let ref = OCCTBRepFillOffsetAncestorsGetAncestor(handle, edge.handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepExtrema_DistanceSS

extension Shape {
    /// Result of shape-to-shape distance computation.
    public struct DistanceSSResult {
        public let distance: Double
        public let point1: SIMD3<Double>
        public let point2: SIMD3<Double>
        public let solutionCount: Int
        public let isDone: Bool
    }

    /// Compute the minimum distance between two sub-shapes using BRepExtrema_DistanceSS.
    public func distanceSS(to other: Shape, deflection: Double = 100.0) -> DistanceSSResult {
        let r = OCCTBRepExtremaDistanceSS(handle, other.handle, deflection)
        return DistanceSSResult(distance: r.distance,
                                point1: SIMD3(r.point1X, r.point1Y, r.point1Z),
                                point2: SIMD3(r.point2X, r.point2Y, r.point2Z),
                                solutionCount: Int(r.solutionCount),
                                isDone: r.isDone)
    }
}

// MARK: - BRepGProp_VinertGK

extension Shape {
    /// Result of Gauss-Kronrod volume integration on a face.
    public struct VinertGKResult {
        public let mass: Double
        public let errorReached: Double
        public let absoluteError: Double
        public let center: SIMD3<Double>
    }

    /// Compute volume properties of a face using Gauss-Kronrod integration.
    public func vinertGK(location: SIMD3<Double> = SIMD3(0, 0, 0),
                         tolerance: Double = 0.001, computeCG: Bool = true) -> VinertGKResult {
        let r = OCCTBRepGPropVinertGK(handle, location.x, location.y, location.z,
                                       tolerance, computeCG)
        return VinertGKResult(mass: r.mass, errorReached: r.errorReached,
                              absoluteError: r.absoluteError,
                              center: SIMD3(r.centerX, r.centerY, r.centerZ))
    }
}

// MARK: - GeomFill_Profiler

/// Homogenizes a set of curves to the same BSpline representation.
public final class CurveProfiler: @unchecked Sendable {
    let handle: OCCTGeomFillProfilerRef

    init(handle: OCCTGeomFillProfilerRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillProfilerRelease(handle)
    }

    /// Create a new curve profiler.
    public static func create() -> CurveProfiler {
        let ref = OCCTGeomFillProfilerCreate()!
        return CurveProfiler(handle: ref)
    }

    /// Add a curve to the profiler.
    public func addCurve(_ curve: Curve3D) {
        OCCTGeomFillProfilerAddCurve(handle, curve.handle)
    }

    /// Perform the homogenization. Returns true on success.
    @discardableResult
    public func perform(tolerance: Double = 1e-6) -> Bool {
        OCCTGeomFillProfilerPerform(handle, tolerance)
    }

    /// Degree of the homogenized curves.
    public var degree: Int { Int(OCCTGeomFillProfilerDegree(handle)) }

    /// Number of poles per curve.
    public var poleCount: Int { Int(OCCTGeomFillProfilerNbPoles(handle)) }

    /// Number of knots.
    public var knotCount: Int { Int(OCCTGeomFillProfilerNbKnots(handle)) }

    /// Whether the curves are periodic.
    public var isPeriodic: Bool { OCCTGeomFillProfilerIsPeriodic(handle) }

    /// Get poles for a curve at 1-based index.
    public func poles(curveIndex: Int) -> [SIMD3<Double>] {
        let n = poleCount
        guard n > 0 else { return [] }
        var xs = [Double](repeating: 0, count: n)
        var ys = [Double](repeating: 0, count: n)
        var zs = [Double](repeating: 0, count: n)
        guard OCCTGeomFillProfilerPoles(handle, Int32(curveIndex), &xs, &ys, &zs, Int32(n)) else { return [] }
        return (0..<n).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Get knots and multiplicities.
    public func knotsAndMults() -> (knots: [Double], mults: [Int]) {
        let n = knotCount
        guard n > 0 else { return ([], []) }
        var knots = [Double](repeating: 0, count: n)
        var mults = [Int32](repeating: 0, count: n)
        guard OCCTGeomFillProfilerKnotsAndMults(handle, &knots, &mults, Int32(n)) else { return ([], []) }
        return (knots, mults.map { Int($0) })
    }
}

// MARK: - GeomFill_Stretch

extension Surface {
    /// Result of stretch fill operation.
    public struct StretchFillResult {
        public let nbUPoles: Int
        public let nbVPoles: Int
        public let isRational: Bool
        public let poles: [SIMD3<Double>]
    }

    /// Create a stretch-filled surface from 4 boundary point arrays.
    public static func stretchFill(p1: [SIMD3<Double>], p2: [SIMD3<Double>],
                                   p3: [SIMD3<Double>], p4: [SIMD3<Double>]) -> StretchFillResult? {
        let count = p1.count
        guard count == p2.count && count == p3.count && count == p4.count && count >= 2 else { return nil }

        let flat1 = p1.flatMap { [$0.x, $0.y, $0.z] }
        let flat2 = p2.flatMap { [$0.x, $0.y, $0.z] }
        let flat3 = p3.flatMap { [$0.x, $0.y, $0.z] }
        let flat4 = p4.flatMap { [$0.x, $0.y, $0.z] }

        let maxPoles = 1000
        var outPoles = [Double](repeating: 0, count: maxPoles * 3)
        let r = OCCTGeomFillStretch(flat1, flat2, flat3, flat4, Int32(count), &outPoles, Int32(maxPoles))

        guard r.nbUPoles > 0 && r.nbVPoles > 0 else { return nil }
        let totalPoles = Int(r.nbUPoles) * Int(r.nbVPoles)
        let poles = (0..<totalPoles).map { i in
            SIMD3(outPoles[i * 3], outPoles[i * 3 + 1], outPoles[i * 3 + 2])
        }
        return StretchFillResult(nbUPoles: Int(r.nbUPoles), nbVPoles: Int(r.nbVPoles),
                                 isRational: r.isRational, poles: poles)
    }
}

// MARK: - GeomFill_LocationDraft

/// Draft angle location law for sweep operations.
public final class LocationDraft: @unchecked Sendable {
    let handle: OCCTLocationDraftRef

    init(handle: OCCTLocationDraftRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillLocationDraftRelease(handle)
    }

    /// Create a location draft with given direction and angle (radians).
    public static func create(direction: SIMD3<Double>, angle: Double) -> LocationDraft {
        let ref = OCCTGeomFillLocationDraftCreate(direction.x, direction.y, direction.z, angle)!
        return LocationDraft(handle: ref)
    }

    /// Set the sweep path curve. Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillLocationDraftSetCurve(handle, curve.handle)
    }

    /// Evaluate the frame at a parameter. Returns (matrix3x3, translation) or nil.
    public func evaluate(at param: Double) -> (matrix: [Double], translation: SIMD3<Double>)? {
        var mat = [Double](repeating: 0, count: 9)
        var vx = 0.0, vy = 0.0, vz = 0.0
        guard OCCTGeomFillLocationDraftD0(handle, param, &mat, &vx, &vy, &vz) else { return nil }
        return (mat, SIMD3(vx, vy, vz))
    }

    /// Set the draft angle (radians).
    public func setAngle(_ angle: Double) {
        OCCTGeomFillLocationDraftSetAngle(handle, angle)
    }

    /// Get the draft direction.
    public var direction: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTGeomFillLocationDraftDirection(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

// MARK: - GeomFill_GuideTrihedronAC

/// Arc-length corrected guide trihedron for sweep operations.
public final class GuideTrihedronAC: @unchecked Sendable {
    let handle: OCCTGuideTrihedronACRef

    init(handle: OCCTGuideTrihedronACRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillGuideTrihedronACRelease(handle)
    }

    /// Create from a guide curve.
    public static func create(guideCurve: Curve3D) -> GuideTrihedronAC {
        let ref = OCCTGeomFillGuideTrihedronACCreate(guideCurve.handle)!
        return GuideTrihedronAC(handle: ref)
    }

    /// Set the sweep path curve. Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillGuideTrihedronACSetCurve(handle, curve.handle)
    }

    /// Evaluate the trihedron frame at a parameter.
    public func evaluate(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)? {
        var tx = 0.0, ty = 0.0, tz = 0.0
        var nx = 0.0, ny = 0.0, nz = 0.0
        var bx = 0.0, by = 0.0, bz = 0.0
        guard OCCTGeomFillGuideTrihedronACD0(handle, param, &tx, &ty, &tz, &nx, &ny, &nz, &bx, &by, &bz) else { return nil }
        return (SIMD3(tx, ty, tz), SIMD3(nx, ny, nz), SIMD3(bx, by, bz))
    }
}

// MARK: - GeomFill_GuideTrihedronPlan

/// Planar guide trihedron for sweep operations.
public final class GuideTrihedronPlan: @unchecked Sendable {
    let handle: OCCTGuideTrihedronPlanRef

    init(handle: OCCTGuideTrihedronPlanRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillGuideTrihedronPlanRelease(handle)
    }

    /// Create from a guide curve.
    public static func create(guideCurve: Curve3D) -> GuideTrihedronPlan {
        let ref = OCCTGeomFillGuideTrihedronPlanCreate(guideCurve.handle)!
        return GuideTrihedronPlan(handle: ref)
    }

    /// Set the sweep path curve. Returns true on success.
    @discardableResult
    public func setCurve(_ curve: Curve3D) -> Bool {
        OCCTGeomFillGuideTrihedronPlanSetCurve(handle, curve.handle)
    }

    /// Evaluate the trihedron frame at a parameter.
    public func evaluate(at param: Double) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>)? {
        var tx = 0.0, ty = 0.0, tz = 0.0
        var nx = 0.0, ny = 0.0, nz = 0.0
        var bx = 0.0, by = 0.0, bz = 0.0
        guard OCCTGeomFillGuideTrihedronPlanD0(handle, param, &tx, &ty, &tz, &nx, &ny, &nz, &bx, &by, &bz) else { return nil }
        return (SIMD3(tx, ty, tz), SIMD3(nx, ny, nz), SIMD3(bx, by, bz))
    }
}

// MARK: - GeomFill_SectionPlacement

extension Curve3D {
    /// Result of section placement on a path.
    public struct SectionPlacementResult {
        public let parameterOnPath: Double
        public let parameterOnSection: Double
        public let distance: Double
        public let angle: Double
        public let isDone: Bool
    }

    /// Place a section curve on a path using a draft location law.
    public func sectionPlacement(section: Curve3D,
                                 direction: SIMD3<Double> = SIMD3(0, 0, 1),
                                 draftAngle: Double = 0,
                                 tolerance: Double = 1e-3) -> SectionPlacementResult {
        let r = OCCTGeomFillSectionPlacement(handle, section.handle,
                                              direction.x, direction.y, direction.z,
                                              draftAngle, tolerance)
        return SectionPlacementResult(parameterOnPath: r.parameterOnPath,
                                      parameterOnSection: r.parameterOnSection,
                                      distance: r.distance, angle: r.angle, isDone: r.isDone)
    }
}

// MARK: - BRepFill_NSections

/// N-section law for sweep/loft operations with multiple wire cross-sections.
public final class NSections: @unchecked Sendable {
    let handle: OCCTNSectionsRef

    init(handle: OCCTNSectionsRef) {
        self.handle = handle
    }

    deinit {
        OCCTBRepFillNSectionsRelease(handle)
    }

    /// Create from an array of wire shapes.
    public static func create(wires: [Shape]) -> NSections? {
        let refs = wires.map { $0.handle as OCCTShapeRef }
        return refs.withUnsafeBufferPointer { buf in
            guard let ref = OCCTBRepFillNSectionsCreate(buf.baseAddress!, Int32(wires.count)) else { return nil }
            return NSections(handle: ref)
        }
    }

    /// Number of section laws.
    public var lawCount: Int { Int(OCCTBRepFillNSectionsNbLaw(handle)) }

    /// Whether the section is constant along the path.
    public var isConstant: Bool { OCCTBRepFillNSectionsIsConstant(handle) }

    /// Whether the section degenerates to a vertex.
    public var isVertex: Bool { OCCTBRepFillNSectionsIsVertex(handle) }
}

// MARK: - GeomFill_AppSurf

extension Surface {
    /// Result of surface approximation from section curves.
    public struct AppSurfResult {
        public let uDegree: Int
        public let vDegree: Int
        public let nbUPoles: Int
        public let nbVPoles: Int
        public let nbUKnots: Int
        public let nbVKnots: Int
        public let isDone: Bool
    }

    /// Approximate a surface from N section curves using GeomFill_AppSurf.
    public static func appSurf(curves: [Curve3D], degMin: Int = 3, degMax: Int = 8,
                               tol3d: Double = 1e-3, tol2d: Double = 1e-3) -> AppSurfResult? {
        let refs = curves.map { $0.handle as OCCTCurve3DRef }
        return refs.withUnsafeBufferPointer { buf in
            let r = OCCTGeomFillAppSurf(buf.baseAddress!, Int32(curves.count),
                                         Int32(degMin), Int32(degMax), tol3d, tol2d)
            guard r.isDone else { return nil }
            return AppSurfResult(uDegree: Int(r.uDegree), vDegree: Int(r.vDegree),
                                 nbUPoles: Int(r.nbUPoles), nbVPoles: Int(r.nbVPoles),
                                 nbUKnots: Int(r.nbUKnots), nbVKnots: Int(r.nbVKnots),
                                 isDone: r.isDone)
        }
    }
}

// MARK: - ShapeFix_ComposeShell

extension Shape {
    /// Compose shell: split a face into sub-faces using composite surface grid.
    public func composeShell(precision: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFixComposeShell(handle, precision) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Transform, Boolean, Shape Query expansions (v0.115.0)

extension Shape {
    /// Apply a general affine transformation (3x3 rotation + translation).
    /// matrix12 = [r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]
    public func transformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Apply a general affine transformation (non-uniform scaling).
    /// matrix12 = row-major 3x4 affine matrix [r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]
    public func gTransformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeGTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Boolean section with fuzzy tolerance.
    public func section(with other: Shape, tolerance: Double) -> Shape? {
        guard let ref = OCCTBooleanSectionWithTolerance(handle, other.handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Split this shape by multiple tool shapes.
    public func split(tools: [Shape], tolerance: Double = 0) -> Shape? {
        let toolRefs = tools.map { $0.handle as OCCTShapeRef }
        guard let ref = toolRefs.withUnsafeBufferPointer({ buf in
            OCCTBooleanSplitMulti(handle, buf.baseAddress!, Int32(tools.count), tolerance)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Result of a boolean operation with history tracking.
    public struct BooleanHistoryResult: Sendable {
        public let shape: Shape
        public let hasDeleted: Bool
        public let hasModified: Bool
        public let hasGenerated: Bool
    }

    /// Boolean cut with history tracking.
    public func subtractedWithHistory(_ tool: Shape, tolerance: Double = 0) -> BooleanHistoryResult? {
        var hasDel = false, hasMod = false, hasGen = false
        guard let ref = OCCTBooleanCutWithHistory(handle, tool.handle, tolerance,
                                                   &hasDel, &hasMod, &hasGen) else { return nil }
        return BooleanHistoryResult(shape: Shape(handle: ref),
                                     hasDeleted: hasDel, hasModified: hasMod, hasGenerated: hasGen)
    }

    /// Remove faces from a shape with fuzzy tolerance (defeaturing).
    public func defeature(faces: [Shape], tolerance: Double = 0) -> Shape? {
        let faceRefs = faces.map { $0.handle as OCCTShapeRef }
        guard let ref = faceRefs.withUnsafeBufferPointer({ buf in
            OCCTDefeatureWithTolerance(handle, buf.baseAddress!, Int32(faces.count), tolerance)
        }) else { return nil }
        return Shape(handle: ref)
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

    // --- GCPnts_AbscissaPoint expansion ---

    /// Find parameter on an edge at a given arc length from startParam.
    public func edgeParameterAtArcLength(_ arcLength: Double, from startParam: Double) -> Double {
        OCCTEdgeParameterAtArcLength(handle, arcLength, startParam)
    }

    /// Compute total arc length of this edge.
    public var edgeArcLength: Double {
        OCCTEdgeArcLength(handle)
    }

    /// Compute arc length between two parameters on this edge.
    public func edgeArcLength(from u1: Double, to u2: Double) -> Double {
        OCCTEdgeArcLengthBetween(handle, u1, u2)
    }

    /// Find parameter at a fraction (0..1) of total edge length.
    public func edgeParameterAtFraction(_ fraction: Double) -> Double {
        OCCTEdgeParameterAtFraction(handle, fraction)
    }

    // --- BRepAdaptor exposure ---

    /// Get the parameter domain of an edge curve.
    public var edgeAdaptorDomain: ClosedRange<Double> {
        var first = 0.0, last = 0.0
        OCCTEdgeAdaptorDomain(handle, &first, &last)
        return first...last
    }

    /// Evaluate the edge curve at a parameter.
    public func edgeAdaptorValue(at param: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeAdaptorValue(handle, param, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Curve type of the edge (GeomAbs_CurveType: 0=Line, 1=Circle, etc.).
    public var edgeAdaptorCurveType: Int32 {
        OCCTEdgeAdaptorCurveType(handle)
    }

    /// Get the UV bounds of a face surface.
    public var faceAdaptorBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin = 0.0, uMax = 0.0, vMin = 0.0, vMax = 0.0
        OCCTFaceAdaptorBounds(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Evaluate the face surface at (u,v).
    public func faceAdaptorValue(u: Double, v: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTFaceAdaptorValue(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Surface type of the face (GeomAbs_SurfaceType: 0=Plane, 1=Cylinder, etc.).
    public var faceAdaptorSurfaceType: Int32 {
        OCCTFaceAdaptorSurfaceType(handle)
    }

    // --- Additional shape queries ---

    /// Volume of the oriented bounding box (OBB).
    public var obbVolume: Double {
        OCCTShapeOBBVolume(handle)
    }

    /// Maximum edge tolerance in this shape.
    public var maxEdgeTolerance: Double {
        OCCTShapeMaxEdgeTolerance(handle)
    }

    /// Maximum face tolerance in this shape.
    public var maxFaceTolerance: Double {
        OCCTShapeMaxFaceTolerance(handle)
    }

    /// Maximum vertex tolerance in this shape.
    public var maxVertexTolerance: Double {
        OCCTShapeMaxVertexTolerance(handle)
    }

    /// Whether this shape has free (non-shared) edges.
    public var hasFreeEdges: Bool {
        OCCTShapeHasFreeEdges(handle)
    }

    /// Whether this shape has free (non-shared) wires.
    public var hasFreeWires: Bool {
        OCCTShapeHasFreeWires(handle)
    }

    /// Whether this shape has free (non-shared) faces.
    public var hasFreeFaces: Bool {
        OCCTShapeHasFreeFaces(handle)
    }

    /// Length of the bounding box diagonal.
    public var boundingDiagonal: Double {
        OCCTShapeBoundingDiagonal(handle)
    }

    /// Volumetric centroid of this shape.
    public var centroid: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTShapeCentroid(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Total length of all edges in this shape.
    public var totalEdgeLength: Double {
        OCCTShapeTotalEdgeLength(handle)
    }
}

// MARK: - ThruSections builder (v0.115.0)

/// Builder for lofted shapes through multiple wire sections.
public final class ThruSectionsBuilder: @unchecked Sendable {
    internal let ref: OCCTThruSectionsRef

    /// Create a ThruSections builder.
    /// - Parameters:
    ///   - isSolid: Whether to create a solid (true) or shell (false)
    ///   - isRuled: Whether to use ruled surfaces
    ///   - precision: 3D tolerance
    public init(isSolid: Bool = true, isRuled: Bool = false, precision: Double = 1e-6) {
        ref = OCCTThruSectionsCreate(isSolid, isRuled, precision)
    }

    deinit {
        OCCTThruSectionsRelease(ref)
    }

    /// Add a wire profile.
    public func addWire(_ wire: Shape) {
        OCCTThruSectionsAddWire(ref, wire.handle)
    }

    /// Add a vertex (point) as a degenerate section.
    public func addVertex(_ vertex: Shape) {
        OCCTThruSectionsAddVertex(ref, vertex.handle)
    }

    /// Enable/disable smoothing.
    public func setSmoothing(_ smoothing: Bool) {
        OCCTThruSectionsSetSmoothing(ref, smoothing)
    }

    /// Set the maximum BSpline degree.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTThruSectionsSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set the continuity (0=C0, 1=C1, 2=C2).
    public func setContinuity(_ continuity: Int) {
        OCCTThruSectionsSetContinuity(ref, Int32(continuity))
    }

    /// Build the lofted shape.
    @discardableResult
    public func build() -> Bool {
        OCCTThruSectionsBuild(ref)
    }

    /// Get the result shape.
    public var shape: Shape? {
        guard let h = OCCTThruSectionsShape(ref) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - ShapeFixer builder (v0.115.0)

/// Configurable shape repair using ShapeFix_Shape.
public final class ShapeFixer: @unchecked Sendable {
    private let ref: OCCTShapeFixerRef

    /// Create a shape fixer for the given shape.
    public init(shape: Shape) {
        ref = OCCTShapeFixerCreate(shape.handle)
    }

    deinit {
        OCCTShapeFixerRelease(ref)
    }

    /// Set the precision for shape fixing.
    public func setPrecision(_ precision: Double) {
        OCCTShapeFixerSetPrecision(ref, precision)
    }

    /// Set the maximum tolerance.
    public func setMaxTolerance(_ maxTol: Double) {
        OCCTShapeFixerSetMaxTolerance(ref, maxTol)
    }

    /// Set the minimum tolerance.
    public func setMinTolerance(_ minTol: Double) {
        OCCTShapeFixerSetMinTolerance(ref, minTol)
    }

    /// Perform the shape fix. Returns true if something was fixed.
    @discardableResult
    public func perform() -> Bool {
        OCCTShapeFixerPerform(ref)
    }

    /// Get the result shape after fixing.
    public var shape: Shape? {
        guard let h = OCCTShapeFixerShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Query status: 1=OK, 2=DONE, 3=FAIL.
    public func status(_ type: Int) -> Bool {
        OCCTShapeFixerStatus(ref, Int32(type))
    }
}

// MARK: - BRep_Tool completions (v0.126.0)

extension Shape {
    /// Get the 2D curve (pcurve) of an edge on a face, with parameter range.
    public static func curveOnSurface(edge: Shape, face: Shape) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let c = OCCTBRepToolCurveOnSurface(edge.handle, face.handle, &first, &last) else { return nil }
        return (Curve2D(handle: c), first, last)
    }

    /// Check if edge has continuity regularity between two faces.
    public static func hasContinuity(edge: Shape, face1: Shape, face2: Shape) -> Bool {
        OCCTBRepToolHasContinuity(edge.handle, face1.handle, face2.handle)
    }

    /// Get the continuity of edge between two faces. Returns GeomAbs_Shape as int.
    public static func continuity(edge: Shape, face1: Shape, face2: Shape) -> Int {
        Int(OCCTBRepToolContinuity(edge.handle, face1.handle, face2.handle))
    }

    /// Check if edge has any regularity on some two surfaces.
    public static func hasAnyContinuity(edge: Shape) -> Bool {
        OCCTBRepToolHasAnyContinuity(edge.handle)
    }

    /// Get the maximum continuity of edge between all its surfaces.
    public static func maxContinuity(edge: Shape) -> Int {
        Int(OCCTBRepToolMaxContinuity(edge.handle))
    }

    /// Check if edge is degenerated.
    public static func isDegenerated(edge: Shape) -> Bool {
        OCCTBRepToolDegenerated(edge.handle)
    }

    /// Check if face has the NaturalRestriction flag set.
    public static func naturalRestriction(face: Shape) -> Bool {
        OCCTBRepToolNaturalRestriction(face.handle)
    }

    /// Get the parameter range of edge on a face (pcurve range).
    public static func rangeOnFace(edge: Shape, face: Shape) -> (first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard OCCTBRepToolRangeOnFace(edge.handle, face.handle, &first, &last) else { return nil }
        return (first, last)
    }

    /// Get the parameter of vertex on pcurve of edge on face.
    public static func parameterOnFace(vertex: Shape, edge: Shape, face: Shape) -> Double? {
        var param = 0.0
        guard OCCTBRepToolParameterOnFace(vertex.handle, edge.handle, face.handle, &param) else { return nil }
        return param
    }

    /// Get the UV parameters of vertex on face.
    public static func parametersOnFace(vertex: Shape, face: Shape) -> (u: Double, v: Double)? {
        var u = 0.0, v = 0.0
        guard OCCTBRepToolParametersOnFace(vertex.handle, face.handle, &u, &v) else { return nil }
        return (u, v)
    }

    /// Get UV points at extremities of edge on face.
    public static func uvPoints(edge: Shape, face: Shape) -> (firstU: Double, firstV: Double, lastU: Double, lastV: Double)? {
        var fU = 0.0, fV = 0.0, lU = 0.0, lV = 0.0
        guard OCCTBRepToolUVPoints(edge.handle, face.handle, &fU, &fV, &lU, &lV) else { return nil }
        return (fU, fV, lU, lV)
    }

    /// Get maximum tolerance of sub-shapes of given type. type: 6=EDGE, 4=FACE, 7=VERTEX.
    public func maxTolerance(subShapeType: Int) -> Double {
        OCCTBRepToolMaxTolerance(handle, Int32(subShapeType))
    }
}

// MARK: - Section with plane/surface, BRep_Tool Polygon queries (v0.127.0)

extension Shape {

    /// Compute the section (intersection curves) of this shape with a plane.
    /// - Parameters:
    ///   - normal: Plane normal direction
    ///   - origin: A point on the plane
    /// - Returns: Shape containing section edges, or nil on failure
    public func sectionWithPlane(normal: SIMD3<Double>, origin: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeSectionWithPlane(handle,
                                                 normal.x, normal.y, normal.z,
                                                 origin.x, origin.y, origin.z) else { return nil }
        return Shape(handle: h)
    }

    /// Compute the section (intersection curves) of this shape with a surface.
    /// - Parameter surface: The surface to intersect with
    /// - Returns: Shape containing section edges, or nil on failure
    public func sectionWithSurface(_ surface: Surface) -> Shape? {
        guard let h = OCCTShapeSectionWithSurface(handle, surface.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get the 2D curve of an edge computed on a plane surface.
    /// Uses BRep_Tool::CurveOnPlane.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - surface: The surface (typically planar)
    /// - Returns: The 2D curve and parameter range, or nil
    public static func curveOnPlane(edge: Shape, surface: Surface) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTBRepToolCurveOnPlane(edge.handle, surface.handle, &first, &last) else { return nil }
        return (Curve2D(handle: ref), first, last)
    }

    /// Get the 3D polygon of a meshed edge (from BRep_Tool::Polygon3D).
    /// The shape should be meshed first (e.g., via `mesh(deflection:)`).
    /// - Parameter edge: The edge shape
    /// - Returns: Array of 3D points, or nil if no polygon available
    public static func polygon3D(edge: Shape) -> [SIMD3<Double>]? {
        var pointsPtr: UnsafeMutablePointer<Double>?
        let count = OCCTBRepToolPolygon3D(edge.handle, &pointsPtr)
        guard count > 0, let pts = pointsPtr else { return nil }
        defer { free(pts) }
        var result = [SIMD3<Double>]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
        }
        return result
    }

    /// Get the polygon-on-triangulation indices of a meshed edge.
    /// Returns 1-based node indices into the triangulation.
    /// The shape should be meshed first.
    /// - Parameter edge: The edge shape
    /// - Returns: Array of 1-based node indices, or nil if not available
    public static func polygonOnTriangulation(edge: Shape) -> [Int]? {
        var indicesPtr: UnsafeMutablePointer<Int32>?
        let count = OCCTBRepToolPolygonOnTriangulation(edge.handle, &indicesPtr)
        guard count > 0, let indices = indicesPtr else { return nil }
        defer { free(indices) }
        var result = [Int]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(Int(indices[i]))
        }
        return result
    }
}

// MARK: - BRep_Tool completions (v0.128.0)

extension Shape {

    /// Check if an edge is closed on a face (has two PCurves with different orientations).
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    /// - Returns: true if the edge is closed on the face
    public static func isClosedOnFace(edge: Shape, face: Shape) -> Bool {
        OCCTBRepToolIsClosedOnFace(edge.handle, face.handle)
    }

    /// Get the 2D polygon of an edge on a face (from BRep_Tool::PolygonOnSurface).
    /// The shape should be meshed first.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    /// - Returns: Array of 2D UV points, or nil if not available
    public static func polygonOnSurface(edge: Shape, face: Shape) -> [SIMD2<Double>]? {
        var pointsPtr: UnsafeMutablePointer<Double>?
        let count = OCCTBRepToolPolygonOnSurface(edge.handle, face.handle, &pointsPtr)
        guard count > 0, let pts = pointsPtr else { return nil }
        defer { free(pts) }
        var result = [SIMD2<Double>]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(SIMD2(pts[i*2], pts[i*2+1]))
        }
        return result
    }

    /// Set the UV endpoint coordinates of an edge on a face.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    ///   - first: UV coordinates of the first point
    ///   - last: UV coordinates of the last point
    /// - Returns: true on success
    @discardableResult
    public static func setUVPoints(edge: Shape, face: Shape,
                                    first: SIMD2<Double>, last: SIMD2<Double>) -> Bool {
        OCCTBRepToolSetUVPoints(edge.handle, face.handle, first.x, first.y, last.x, last.y)
    }
}

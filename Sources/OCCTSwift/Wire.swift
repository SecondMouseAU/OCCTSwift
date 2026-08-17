import Foundation
import simd
import OCCTBridge

/// A wire represents a connected sequence of edges (curves).
///
/// Wires are used for two main purposes:
/// 1. **2D Profiles**: Cross-sections to be swept, extruded, or revolved into solids
/// 2. **3D Paths**: Curves along which profiles are swept
///
/// ## Creating 2D Profiles
///
/// ```swift
/// // Simple rectangle
/// let rect = Wire.rectangle(width: 10, height: 5)
///
/// // Custom polygon (rail cross-section)
/// let railProfile = Wire.polygon([
///     SIMD2(0, 0),
///     SIMD2(2.5, 0),
///     SIMD2(2.5, 1),
///     SIMD2(1.5, 7),
///     SIMD2(0, 7)
/// ])
/// ```
///
/// ## Creating 3D Paths
///
/// ```swift
/// // Straight line
/// let straight = Wire.line(from: .zero, to: SIMD3(100, 0, 0))
///
/// // Circular arc
/// let curve = Wire.arc(
///     center: .zero,
///     radius: 500,
///     startAngle: 0,
///     endAngle: .pi / 4
/// )
/// ```
///
/// ## Sweeping Profiles Along Paths
///
/// ```swift
/// let rail = Shape.sweep(profile: railProfile, along: curve)
/// ```
public final class Wire: @unchecked Sendable {
    internal let handle: OCCTWireRef

    internal init(handle: OCCTWireRef) {
        self.handle = handle
    }

    /// Construct a Wire from a Shape that wraps a TopoDS_Wire. Returns nil
    /// if `shape` is null or wraps a non-wire topology type.
    ///
    /// Inverse of getting a wire-typed `Shape` (e.g. via `Shape.wires` or
    /// `Shape.subShapes(ofType: .wire)`). Round-trips with `Shape.fromWire(_:)`.
    public convenience init?(_ shape: Shape) {
        guard let h = OCCTWireFromShape(shape.handle) else { return nil }
        self.init(handle: h)
    }

    deinit {
        OCCTWireRelease(handle)
    }

    // MARK: - 2D Profiles (for Extrusion/Sweep)

    /// Create a rectangular profile centered at origin in XY plane.
    ///
    /// - Parameters:
    ///   - width: Width of rectangle (X dimension)
    ///   - height: Height of rectangle (Y dimension)
    /// - Returns: A closed rectangular wire, or nil if creation fails
    ///
    /// The rectangle is centered at origin with corners at (±width/2, ±height/2).
    public static func rectangle(width: Double, height: Double) -> Wire? {
        guard width > 0, height > 0 else { return nil }
        guard let handle = OCCTWireCreateRectangle(width, height) else { return nil }
        return Wire(handle: handle)
    }

    /// Create a circular wire.
    ///
    /// - Parameters:
    ///   - origin: Center of the circle (default: origin)
    ///   - normal: Normal direction of the circle plane (default: Z axis)
    ///   - radius: Radius of the circle
    /// - Returns: A closed circular wire, or nil if creation fails
    public static func circle(
        origin: SIMD3<Double> = .zero,
        normal: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> Wire? {
        guard radius > 0 else { return nil }
        guard let handle = OCCTWireCreateCircleEx(radius,
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z) else { return nil }
        return Wire(handle: handle)
    }

    /// Create a polygon from 2D points in XY plane.
    ///
    /// - Parameters:
    ///   - points: Array of 2D points defining vertices (minimum 2 points required)
    ///   - closed: If true, connects last point to first
    /// - Returns: A polygonal wire, or nil if creation fails
    ///
    /// Points are connected in order. For a closed profile (suitable for
    /// extrusion), pass `closed: true`.
    ///
    /// ## Example: Rail Profile
    ///
    /// ```swift
    /// let railProfile = Wire.polygon([
    ///     SIMD2(0, 0),       // Base left
    ///     SIMD2(2.5, 0),     // Base right
    ///     SIMD2(2.5, 0.8),   // Web start right
    ///     SIMD2(1.8, 0.8),   // Web right
    ///     SIMD2(1.8, 6.5),   // Head start right
    ///     SIMD2(1.0, 7.0),   // Head right
    ///     SIMD2(0, 7.0),     // Head left
    ///     SIMD2(0, 0.8),     // Web left
    /// ])
    /// ```
    ///
    /// - Note: Returns nil if fewer than 2 points are provided, or if the
    ///   underlying OCCT operation fails (e.g., degenerate edges from
    ///   duplicate or nearly-coincident points).
    public static func polygon(_ points: [SIMD2<Double>], closed: Bool = true) -> Wire? {
        guard points.count >= 2 else { return nil }

        // Flatten to array of doubles: [x1, y1, x2, y2, ...]
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 2)
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreatePolygon(buffer.baseAddress, Int32(points.count), closed)
        }
        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a polygon wire from 3D points with straight-line edges.
    ///
    /// Uses BRepBuilderAPI_MakePolygon for fast construction of rectilinear polygon wires
    /// in 3D space. For 2D polygons, use ``polygon(_:closed:)`` instead.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 2)
    ///   - closed: Whether to close the polygon by adding an edge from last to first point
    /// - Returns: Wire shape, or nil if the operation fails
    public static func polygon3D(_ points: [SIMD3<Double>], closed: Bool = true) -> Wire? {
        guard points.count >= 2 else { return nil }
        var coords: [Double] = []
        coords.reserveCapacity(points.count * 3)
        for p in points {
            coords.append(p.x)
            coords.append(p.y)
            coords.append(p.z)
        }
        let handle = coords.withUnsafeBufferPointer { buffer in
            OCCTWireCreateFastPolygon(buffer.baseAddress, Int32(points.count), closed)
        }
        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    // MARK: - 3D Paths (for Pipe Sweep)

    /// Create a straight line segment in 3D space.
    ///
    /// - Parameters:
    ///   - from: Start point
    ///   - to: End point
    /// - Returns: A wire consisting of a single straight edge, or nil if creation fails
    public static func line(from start: SIMD3<Double>, to end: SIMD3<Double>) -> Wire? {
        // Check for degenerate edge (start == end)
        let dist = simd_distance(start, end)
        guard dist > 1e-10 else { return nil }

        guard let handle = OCCTWireCreateLine(
            start.x, start.y, start.z,
            end.x, end.y, end.z
        ) else { return nil }
        return Wire(handle: handle)
    }

    /// Create a circular arc in 3D space.
    ///
    /// - Parameters:
    ///   - center: Center point of the arc
    ///   - radius: Radius of the arc
    ///   - startAngle: Starting angle in radians (0 = positive X direction)
    ///   - endAngle: Ending angle in radians
    ///   - normal: Normal vector defining the arc plane (default: Z-up)
    /// - Returns: A wire consisting of a single arc edge, or nil if creation fails
    ///
    /// The arc is created in a plane perpendicular to the normal vector.
    /// Angles are measured from the X-axis direction rotated into the plane.
    ///
    /// ## Example: Quarter Circle for Track Curve
    ///
    /// ```swift
    /// let curve = Wire.arc(
    ///     center: SIMD3(0, 0, 0),
    ///     radius: 500,              // 500mm radius
    ///     startAngle: 0,
    ///     endAngle: .pi / 2,        // 90 degrees
    ///     normal: SIMD3(0, 1, 0)    // Horizontal plane (Y-up)
    /// )
    /// ```
    public static func arc(
        center: SIMD3<Double>,
        radius: Double,
        startAngle: Double,
        endAngle: Double,
        normal: SIMD3<Double> = SIMD3(0, 0, 1)
    ) -> Wire? {
        guard radius > 0 else { return nil }
        guard abs(endAngle - startAngle) > 1e-10 else { return nil }

        guard let handle = OCCTWireCreateArc(
            center.x, center.y, center.z,
            radius,
            startAngle, endAngle,
            normal.x, normal.y, normal.z
        ) else { return nil }
        return Wire(handle: handle)
    }

    /// Build an arc-wire passing through three points (start, midpoint
    /// on the arc, end). Uses OCCT's `GC_MakeArcOfCircle` so the centre
    /// and radius are derived from the points; the midpoint resolves
    /// the curvature direction. Avoids the X-direction ambiguity of the
    /// angle-based `arc(center:radius:startAngle:endAngle:normal:)`
    /// constructor when the bend axis isn't a canonical world axis.
    public static func arc(
        start: SIMD3<Double>,
        midpoint: SIMD3<Double>,
        end: SIMD3<Double>
    ) -> Wire? {
        guard let handle = OCCTWireCreateArcThroughPoints(
            start.x, start.y, start.z,
            midpoint.x, midpoint.y, midpoint.z,
            end.x, end.y, end.z
        ) else { return nil }
        return Wire(handle: handle)
    }

    /// Create a 3D path from points in 3D space.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 2 points required)
    ///   - closed: If true, connects last point to first
    /// - Returns: A wire with straight edges between points, or nil if creation fails
    ///
    /// For a smooth path, use `bspline(_:)` instead.
    public static func path(_ points: [SIMD3<Double>], closed: Bool = false) -> Wire? {
        guard points.count >= 2 else { return nil }

        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 3)
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreateFromPoints3D(buffer.baseAddress, Int32(points.count), closed)
        }
        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a smooth B-spline curve through control points.
    ///
    /// - Parameter controlPoints: Array of 3D control points (minimum 2 points required)
    /// - Returns: A smooth curve wire, or nil if creation fails
    ///
    /// The curve will pass near (but not necessarily through) the control points.
    /// For a curve that passes exactly through points, more sophisticated
    /// interpolation is needed.
    ///
    /// ## Example: Easement Curve
    ///
    /// ```swift
    /// let easement = Wire.bspline([
    ///     SIMD3(0, 0, 0),      // Start (straight)
    ///     SIMD3(50, 0, 0),     // Transition begins
    ///     SIMD3(100, 10, 0),   // Curve develops
    ///     SIMD3(150, 30, 0),   // Full curve
    ///     SIMD3(180, 50, 0)    // Continues curving
    /// ])
    /// ```
    public static func bspline(_ controlPoints: [SIMD3<Double>]) -> Wire? {
        guard controlPoints.count >= 2 else { return nil }

        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(controlPoints.count * 3)
        for point in controlPoints {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreateBSpline(buffer.baseAddress, Int32(controlPoints.count))
        }
        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    // MARK: - NURBS Curves

    /// Create a NURBS (Non-Uniform Rational B-Spline) curve with full control.
    ///
    /// - Parameters:
    ///   - poles: Control points (poles) defining the curve shape
    ///   - weights: Weight for each control point (nil for uniform weights = B-spline)
    ///   - knots: Knot values defining parameterization
    ///   - multiplicities: Multiplicity of each knot (nil for all 1s)
    ///   - degree: Curve degree (1=linear, 2=quadratic, 3=cubic)
    /// - Returns: A NURBS curve wire, or nil if parameters are invalid
    ///
    /// NURBS curves provide exact representation of conic sections (circles, ellipses)
    /// and are the standard for CAD data exchange. Use this when you need precise
    /// control over the curve shape, especially for importing/exporting to CAD formats.
    ///
    /// ## Example: Weighted Curve
    ///
    /// ```swift
    /// // A rational quadratic B-spline (can represent exact circle arcs)
    /// let poles = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(1, 1, 0),  // Off-curve control point
    ///     SIMD3(2, 0, 0)
    /// ]
    /// let weights = [1.0, 0.707, 1.0]  // sqrt(2)/2 for quarter circle
    /// let knots = [0.0, 1.0]
    /// let mults = [3, 3]  // Clamped at endpoints
    ///
    /// let arc = Wire.nurbs(poles: poles, weights: weights,
    ///                      knots: knots, multiplicities: mults, degree: 2)
    /// ```
    public static func nurbs(
        poles: [SIMD3<Double>],
        weights: [Double]? = nil,
        knots: [Double],
        multiplicities: [Int32]? = nil,
        degree: Int32
    ) -> Wire? {
        guard poles.count >= 2, knots.count >= 2, degree >= 1 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { polesBuffer in
            knots.withUnsafeBufferPointer { knotsBuffer in
                if let weights = weights {
                    return weights.withUnsafeBufferPointer { weightsBuffer in
                        if let mults = multiplicities {
                            return mults.withUnsafeBufferPointer { multsBuffer in
                                OCCTWireCreateNURBS(
                                    polesBuffer.baseAddress,
                                    Int32(poles.count),
                                    weightsBuffer.baseAddress,
                                    knotsBuffer.baseAddress,
                                    Int32(knots.count),
                                    multsBuffer.baseAddress,
                                    degree
                                )
                            }
                        } else {
                            return OCCTWireCreateNURBS(
                                polesBuffer.baseAddress,
                                Int32(poles.count),
                                weightsBuffer.baseAddress,
                                knotsBuffer.baseAddress,
                                Int32(knots.count),
                                nil,
                                degree
                            )
                        }
                    }
                } else {
                    if let mults = multiplicities {
                        return mults.withUnsafeBufferPointer { multsBuffer in
                            OCCTWireCreateNURBS(
                                polesBuffer.baseAddress,
                                Int32(poles.count),
                                nil,
                                knotsBuffer.baseAddress,
                                Int32(knots.count),
                                multsBuffer.baseAddress,
                                degree
                            )
                        }
                    } else {
                        return OCCTWireCreateNURBS(
                            polesBuffer.baseAddress,
                            Int32(poles.count),
                            nil,
                            knotsBuffer.baseAddress,
                            Int32(knots.count),
                            nil,
                            degree
                        )
                    }
                }
            }
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a NURBS curve with uniform (clamped) knot vector.
    ///
    /// - Parameters:
    ///   - poles: Control points defining the curve shape
    ///   - weights: Weight for each control point (nil for uniform = B-spline)
    ///   - degree: Curve degree (1=linear, 2=quadratic, 3=cubic)
    /// - Returns: A NURBS curve wire, or nil if parameters are invalid
    ///
    /// This is a simplified NURBS creation that automatically generates a
    /// clamped uniform knot vector. The curve starts at the first control
    /// point and ends at the last.
    ///
    /// ## Example: Cubic B-Spline with Control Polygon
    ///
    /// ```swift
    /// let controlPolygon = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(10, 5, 0),
    ///     SIMD3(20, 0, 0),
    ///     SIMD3(30, 5, 0),
    ///     SIMD3(40, 0, 0)
    /// ]
    /// let curve = Wire.nurbsUniform(poles: controlPolygon, degree: 3)
    /// ```
    public static func nurbsUniform(
        poles: [SIMD3<Double>],
        weights: [Double]? = nil,
        degree: Int32
    ) -> Wire? {
        guard poles.count >= Int(degree) + 1, degree >= 1 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { polesBuffer in
            if let weights = weights {
                return weights.withUnsafeBufferPointer { weightsBuffer in
                    OCCTWireCreateNURBSUniform(
                        polesBuffer.baseAddress,
                        Int32(poles.count),
                        weightsBuffer.baseAddress,
                        degree
                    )
                }
            } else {
                return OCCTWireCreateNURBSUniform(
                    polesBuffer.baseAddress,
                    Int32(poles.count),
                    nil,
                    degree
                )
            }
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a cubic B-spline curve (non-rational, degree 3).
    ///
    /// - Parameter poles: Control points (minimum 4 for cubic)
    /// - Returns: A cubic B-spline wire, or nil if fewer than 4 points
    ///
    /// Cubic B-splines are the most common choice for smooth curves.
    /// They provide C² continuity (smooth curvature) and good local control.
    ///
    /// ## Example: Transition Curve Path
    ///
    /// ```swift
    /// let transitionPoles = [
    ///     SIMD3(0, 0, 0),      // Start tangent to straight
    ///     SIMD3(20, 0, 0),
    ///     SIMD3(40, 2, 0),     // Begin curving
    ///     SIMD3(60, 8, 0),
    ///     SIMD3(80, 20, 0),    // Full curve
    ///     SIMD3(90, 30, 0)
    /// ]
    /// let easement = Wire.cubicBSpline(poles: transitionPoles)
    /// ```
    public static func cubicBSpline(poles: [SIMD3<Double>]) -> Wire? {
        guard poles.count >= 4 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { buffer in
            OCCTWireCreateCubicBSpline(buffer.baseAddress, Int32(poles.count))
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    // MARK: - Wire From Edges (v0.51.0)

    /// Create a wire by connecting individual edges in order.
    ///
    /// Uses BRepLib_MakeWire to assemble edges into a connected wire.
    /// Edges should be geometrically connectable (shared vertices or within tolerance).
    ///
    /// - Parameter edges: Array of edge shapes (minimum 1)
    /// - Returns: A wire connecting the edges, or nil if construction fails
    public static func wireFromEdges(_ edges: [Edge]) -> Wire? {
        guard !edges.isEmpty else { return nil }
        let handles: [OCCTEdgeRef] = edges.map { $0.handle }
        return handles.withUnsafeBufferPointer { buffer in
            guard let wireRef = OCCTWireMakeWireFromEdgeRefs(buffer.baseAddress!, Int32(edges.count)) else {
                return nil
            }
            return Wire(handle: wireRef)
        }
    }

    // MARK: - Wire From Curve2D on Plane (Issue #39)

    /// Create a 3D wire by embedding a 2D curve into a geometric plane.
    ///
    /// This lifts the exact parametric representation of a `Curve2D` into 3D space
    /// without discretizing it to points, preserving the original curve geometry.
    /// The resulting wire is suitable for sweep/extrude/loft operations.
    ///
    /// The plane is defined by its origin point, outward normal direction, and
    /// x-axis direction (which maps the 2D U axis into 3D space).
    ///
    /// - Parameters:
    ///   - curve: The 2D curve to embed. Any `Curve2D` type is accepted.
    ///   - origin: The 3D origin of the plane (where the 2D origin maps to).
    ///   - normal: The outward normal of the plane (default Z axis = XY plane).
    ///   - xAxis: The direction in 3D that the 2D X axis maps to (default X axis).
    /// - Returns: A 3D wire on the given plane, or `nil` on failure.
    /// - Note: Resolves GitHub issue #39.
    ///
    /// ## Example: Arc on XY plane at Z=5
    /// ```swift
    /// let arc = Curve2D.arcOfCircle(center: .zero, radius: 10,
    ///                               startAngle: 0, endAngle: .pi)!
    /// let wire3D = Wire.fromCurve2D(arc,
    ///                               origin: SIMD3(0, 0, 5),
    ///                               normal: SIMD3(0, 0, 1),
    ///                               xAxis:  SIMD3(1, 0, 0))!
    /// // Use wire3D as a profile for Shape.pipeShell(spine:profile:)
    /// ```
    public static func fromCurve2D(_ curve: Curve2D,
                                   origin: SIMD3<Double> = .zero,
                                   normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                   xAxis:  SIMD3<Double> = SIMD3(1, 0, 0)) -> Wire? {
        guard let h = OCCTWireFromCurve2DOnPlane(
            curve.handle,
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            xAxis.x,  xAxis.y,  xAxis.z) else { return nil }
        return Wire(handle: h)
    }

    // MARK: - Wire Composition

    /// Join multiple wires into a single connected wire.
    ///
    /// - Parameter wires: Array of wires to join (minimum 1 wire required)
    /// - Returns: A single wire containing all edges, or nil if joining fails
    ///
    /// Wires should be geometrically connected (end of one near start of next).
    /// OCCT will attempt to connect them within tolerance.
    ///
    /// ## Example: Complex Path
    ///
    /// ```swift
    /// let straight1 = Wire.line(from: .zero, to: SIMD3(100, 0, 0))
    /// let curve = Wire.arc(center: SIMD3(100, 50, 0), radius: 50, ...)
    /// let straight2 = Wire.line(from: curveEnd, to: finalPoint)
    ///
    /// let fullPath = Wire.join([straight1, curve, straight2])
    /// ```
    public static func join(_ wires: [Wire]) -> Wire? {
        guard !wires.isEmpty else { return nil }

        let handles: [OCCTWireRef?] = wires.map { $0.handle }
        let handle = handles.withUnsafeBufferPointer { buffer in
            OCCTWireJoin(buffer.baseAddress, Int32(wires.count))
        }
        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }
}

// MARK: - Curve Analysis (v0.9.0)

/// Information about a wire/curve
public struct CurveInfo: Sendable, Equatable {
    /// Total length of the curve
    public var length: Double
    /// Whether the curve is closed (start meets end)
    public var isClosed: Bool
    /// Whether the curve is periodic
    public var isPeriodic: Bool
    /// Start point of the curve
    public var startPoint: SIMD3<Double>
    /// End point of the curve
    public var endPoint: SIMD3<Double>
}

/// Point on a curve with differential geometry properties
public struct CurvePoint: Sendable, Equatable {
    /// Position on the curve
    public var position: SIMD3<Double>
    /// Unit tangent vector at this point
    public var tangent: SIMD3<Double>
    /// Curvature at this point (1/radius, 0 for straight lines)
    public var curvature: Double
    /// Principal normal vector (perpendicular to tangent, toward center of curvature)
    /// Only available when curvature > 0
    public var normal: SIMD3<Double>?
}

extension Wire {
    /// Get comprehensive curve information.
    ///
    /// - Returns: Curve information including length, closed status, and endpoints
    public var curveInfo: CurveInfo? {
        let info = OCCTWireGetCurveInfo(handle)
        guard info.isValid else { return nil }
        return CurveInfo(
            length: info.length,
            isClosed: info.isClosed,
            isPeriodic: info.isPeriodic,
            startPoint: SIMD3(info.startX, info.startY, info.startZ),
            endPoint: SIMD3(info.endX, info.endY, info.endZ)
        )
    }

    /// Get the total length of the wire.
    ///
    /// A `BRepAdaptor_CompCurve` reports one `GeomAbs_CN` interval per edge span, so a wire of
    /// lines and circles was always exact — but each span was integrated with a single Gauss
    /// rule, so one elliptical edge in the wire measured 1.485% long. Each interval is now
    /// subdivided until two successive levels agree to 1e-9 relative (#603).
    ///
    /// ```swift
    /// let perimeter = Wire.rectangle(width: 10, height: 5)?.length   // 30.0
    /// ```
    ///
    /// - Returns: Length in model units, or nil on error
    public var length: Double? {
        let len = OCCTWireGetLength(handle)
        return len >= 0 ? len : nil
    }

    /// Get point on curve at normalized parameter.
    ///
    /// - Parameter parameter: Value from 0.0 (start) to 1.0 (end)
    /// - Returns: 3D position on the curve
    ///
    /// ## Example
    ///
    /// ```swift
    /// let arc = Wire.arc(center: .zero, radius: 10, startAngle: 0, endAngle: .pi)
    /// let midpoint = arc?.point(at: 0.5)  // Point at middle of arc
    /// ```
    public func point(at parameter: Double) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTWireGetPointAt(handle, parameter, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get unit tangent vector at normalized parameter.
    ///
    /// - Parameter parameter: Value from 0.0 (start) to 1.0 (end)
    /// - Returns: Normalized tangent vector pointing in direction of travel
    ///
    /// ## Example
    ///
    /// ```swift
    /// let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
    /// let tangent = line?.tangent(at: 0.5)  // Returns (1, 0, 0)
    /// ```
    public func tangent(at parameter: Double) -> SIMD3<Double>? {
        var tx: Double = 0, ty: Double = 0, tz: Double = 0
        guard OCCTWireGetTangentAt(handle, parameter, &tx, &ty, &tz) else { return nil }
        return SIMD3(tx, ty, tz)
    }

    /// Get curvature at normalized parameter.
    ///
    /// - Parameter parameter: Value from 0.0 (start) to 1.0 (end)
    /// - Returns: Curvature value (1/radius), or nil where the wire has none there.
    ///
    /// A straight line has curvature 0. A circle with radius R has curvature 1/R.
    ///
    /// `nil` means the wire cannot be evaluated at that parameter, or that its first derivative is
    /// null there — a cusp, where the curvature formula divides by zero. That second case used to
    /// come back as `0`, a straight wire's real answer, because only the error path reached this
    /// optional (#595). Unlike ``Curve3D/curvature(at:)`` a wire has no infinity sentinel to report
    /// at a cusp: `BRepAdaptor_CompCurve` computes the formula directly rather than through
    /// `GeomLProp_CLProps`, so there is nothing to say but nothing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let circle = Wire.circle(radius: 10)
    /// let curvature = circle?.curvature(at: 0.5)  // Returns 0.1 (1/10)
    /// ```
    public func curvature(at parameter: Double) -> Double? {
        var k = 0.0
        guard OCCTWireGetCurvatureAt(handle, parameter, &k) else { return nil }
        return k
    }

    /// Get full curve point with position, tangent, curvature, and normal.
    ///
    /// - Parameter parameter: Value from 0.0 (start) to 1.0 (end)
    /// - Returns: Complete differential geometry data at the point
    ///
    /// This is more efficient than calling `point(at:)`, `tangent(at:)`, and
    /// `curvature(at:)` separately when you need multiple values.
    public func curvePoint(at parameter: Double) -> CurvePoint? {
        let cp = OCCTWireGetCurvePointAt(handle, parameter)
        guard cp.isValid else { return nil }

        let normal: SIMD3<Double>? = cp.hasNormal ?
            SIMD3(cp.normX, cp.normY, cp.normZ) : nil

        return CurvePoint(
            position: SIMD3(cp.posX, cp.posY, cp.posZ),
            tangent: SIMD3(cp.tanX, cp.tanY, cp.tanZ),
            curvature: cp.curvature,
            normal: normal
        )
    }

    /// Offset wire in 3D space along a direction.
    ///
    /// - Parameters:
    ///   - distance: Offset distance
    ///   - direction: Direction to offset (will be normalized)
    /// - Returns: A new wire translated by the given distance in the given direction
    ///
    /// Unlike `offset(by:)` which creates a parallel curve in the XY plane,
    /// this translates the entire wire in 3D space.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let profile = Wire.circle(radius: 5)
    /// let raised = profile?.offset3D(distance: 10, direction: SIMD3(0, 0, 1))
    /// // raised is a circle at Z=10
    /// ```
    public func offset3D(distance: Double, direction: SIMD3<Double>) -> Wire? {
        guard let handle = OCCTWireOffset3D(handle, distance, direction.x, direction.y, direction.z) else {
            return nil
        }
        return Wire(handle: handle)
    }

    // MARK: - Curve Interpolation (v0.11.0)

    /// Create a smooth curve that interpolates through given points
    ///
    /// Unlike B-splines where control points influence but don't lie on the curve,
    /// interpolated curves pass exactly through all specified points.
    ///
    /// - Parameters:
    ///   - points: Points the curve must pass through (minimum 2)
    ///   - closed: If true, create a closed (periodic) curve
    ///   - tolerance: Interpolation tolerance (default: 1e-6)
    ///
    /// - Returns: A wire representing the interpolated curve, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a smooth curve through waypoints
    /// let waypoints: [SIMD3<Double>] = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(10, 5, 0),
    ///     SIMD3(20, 0, 0),
    ///     SIMD3(30, 5, 0)
    /// ]
    /// let path = Wire.interpolate(through: waypoints)
    /// ```
    public static func interpolate(
        through points: [SIMD3<Double>],
        closed: Bool = false,
        tolerance: Double = 1e-6
    ) -> Wire? {
        guard points.count >= 2 else { return nil }

        // Flatten points to [x,y,z,x,y,z,...]
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 3)
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }

        guard let handle = OCCTWireInterpolate(flatPoints, Int32(points.count), closed, tolerance) else {
            return nil
        }
        return Wire(handle: handle)
    }

    /// Create a smooth curve through points with specified end tangents
    ///
    /// This allows controlling the direction of the curve at its start and end,
    /// which is useful for ensuring smooth connections with other curves.
    ///
    /// - Parameters:
    ///   - points: Points the curve must pass through (minimum 2)
    ///   - startTangent: Desired tangent direction at start point
    ///   - endTangent: Desired tangent direction at end point
    ///   - tolerance: Interpolation tolerance (default: 1e-6)
    ///
    /// - Returns: A wire with the specified end tangents, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a curve that enters horizontally and exits vertically
    /// let points: [SIMD3<Double>] = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(10, 10, 0)
    /// ]
    /// let curve = Wire.interpolate(
    ///     through: points,
    ///     startTangent: SIMD3(1, 0, 0),  // Horizontal at start
    ///     endTangent: SIMD3(0, 1, 0)      // Vertical at end
    /// )
    /// ```
    public static func interpolate(
        through points: [SIMD3<Double>],
        startTangent: SIMD3<Double>,
        endTangent: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> Wire? {
        guard points.count >= 2 else { return nil }

        // Flatten points to [x,y,z,x,y,z,...]
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 3)
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }

        guard let handle = OCCTWireInterpolateWithTangents(
            flatPoints, Int32(points.count),
            startTangent.x, startTangent.y, startTangent.z,
            endTangent.x, endTangent.y, endTangent.z,
            tolerance
        ) else {
            return nil
        }
        return Wire(handle: handle)
    }
}

// MARK: - CAM Operations

extension Wire {
    /// Join type for wire offsetting
    public enum JoinType: Int32 {
        /// Round corners (arc)
        case arc = 0
        /// Sharp corners (extend until intersection)
        case intersection = 1
    }

    /// Offset the wire by a distance.
    ///
    /// - Parameters:
    ///   - distance: Offset distance. Positive = outward, Negative = inward.
    ///   - joinType: How to handle corners. Default is `.arc` for rounded corners.
    /// - Returns: The offset wire, or nil if the offset fails.
    ///
    /// This is useful for CAM tool compensation:
    /// - Offset model contour outward by tool radius to get tool center path
    /// - Offset inward for pocketing operations
    ///
    /// ## Example: Tool Compensation
    ///
    /// ```swift
    /// let modelContour = Wire.rectangle(width: 40, height: 40)
    /// let toolRadius = 3.0
    ///
    /// // Offset outward for clearing around the model
    /// if let toolPath = modelContour?.offset(by: toolRadius) {
    ///     // toolPath is where the tool center should travel
    /// }
    ///
    /// // Offset inward for pocketing
    /// if let pocketPath = modelContour?.offset(by: -toolRadius) {
    ///     // pocketPath keeps the tool inside the pocket boundary
    /// }
    /// ```
    ///
    /// - Note: The wire must be planar (all points in the same plane).
    /// - Note: For wires with holes (e.g., a square with a circular hole), only the
    ///   outermost contour is returned. Inner contours are not included in the result.
    public func offset(by distance: Double, joinType: JoinType = .arc) -> Wire? {
        guard let handle = OCCTWireOffset(self.handle, distance, joinType.rawValue) else {
            return nil
        }
        return Wire(handle: handle)
    }
}

// MARK: - Convenience Extensions

extension Wire {
    /// Create a rail profile based on standard rail specifications.
    ///
    /// - Parameters:
    ///   - headWidth: Width of rail head (top running surface)
    ///   - headHeight: Height of rail head
    ///   - webThickness: Thickness of the web (vertical part)
    ///   - baseWidth: Width of rail base (foot)
    ///   - baseHeight: Height of rail base
    ///   - totalHeight: Total height from base to head top
    /// - Returns: A closed wire representing the rail cross-section, or nil if creation fails
    ///
    /// Creates a simplified rail profile suitable for model railway use.
    /// For more accurate profiles, use `polygon(_:closed:)` with exact dimensions.
    public static func railProfile(
        headWidth: Double,
        headHeight: Double,
        webThickness: Double,
        baseWidth: Double,
        baseHeight: Double,
        totalHeight: Double
    ) -> Wire? {
        let webHeight = totalHeight - headHeight - baseHeight

        // Build profile from bottom-left, clockwise
        let points: [SIMD2<Double>] = [
            // Base
            SIMD2(0, 0),
            SIMD2(baseWidth, 0),
            SIMD2(baseWidth, baseHeight),

            // Right side of web
            SIMD2((baseWidth + webThickness) / 2, baseHeight),
            SIMD2((baseWidth + webThickness) / 2, baseHeight + webHeight),

            // Head right
            SIMD2((baseWidth + headWidth) / 2, baseHeight + webHeight),
            SIMD2((baseWidth + headWidth) / 2, totalHeight),

            // Head top
            SIMD2((baseWidth - headWidth) / 2, totalHeight),

            // Head left
            SIMD2((baseWidth - headWidth) / 2, baseHeight + webHeight),

            // Left side of web
            SIMD2((baseWidth - webThickness) / 2, baseHeight + webHeight),
            SIMD2((baseWidth - webThickness) / 2, baseHeight),

            // Back to base
            SIMD2(0, baseHeight)
        ]

        return polygon(points, closed: true)
    }

    // MARK: - 2D Fillet (v0.14.0)

    /// Apply a 2D fillet (rounded corner) to a specific vertex.
    ///
    /// The wire must be planar. The fillet creates a circular arc
    /// that smoothly connects the two edges meeting at the vertex.
    ///
    /// - Parameters:
    ///   - vertexIndex: Index of the vertex to fillet (0-based)
    ///   - radius: Fillet radius
    /// - Returns: Wire with filleted corner, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a rectangle and fillet one corner
    /// let rect = Wire.rectangle(width: 10, height: 5)
    /// let rounded = rect?.filleted2D(vertexIndex: 0, radius: 1.0)
    /// ```
    public func filleted2D(vertexIndex: Int, radius: Double) -> Wire? {
        guard let result = OCCTWireFillet2D(handle, Int32(vertexIndex), radius) else {
            return nil
        }
        return Wire(handle: result)
    }

    /// Apply 2D fillets (rounded corners) to all vertices.
    ///
    /// The wire must be planar. Each corner gets a fillet with the specified radius.
    /// Some corners may not be fillettable if the radius is too large.
    ///
    /// - Parameter radius: Fillet radius for all corners
    /// - Returns: Wire with filleted corners, or original wire if some failed
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a rounded rectangle
    /// let rect = Wire.rectangle(width: 10, height: 5)
    /// let rounded = rect?.filletedAll2D(radius: 1.0)
    /// ```
    public func filletedAll2D(radius: Double) -> Wire? {
        guard let result = OCCTWireFilletAll2D(handle, radius) else {
            return nil
        }
        return Wire(handle: result)
    }

    // MARK: - 2D Chamfer (v0.14.0)

    /// Apply a 2D chamfer (angled corner cut) to a specific vertex.
    ///
    /// The wire must be planar. The chamfer creates a straight line
    /// that cuts across the corner.
    ///
    /// - Parameters:
    ///   - vertexIndex: Index of the vertex to chamfer (0-based)
    ///   - distance1: Distance along the first edge
    ///   - distance2: Distance along the second edge
    /// - Returns: Wire with chamfered corner, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a rectangle and chamfer one corner
    /// let rect = Wire.rectangle(width: 10, height: 5)
    /// let chamfered = rect?.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)
    /// ```
    public func chamfered2D(vertexIndex: Int, distance1: Double, distance2: Double) -> Wire? {
        guard let result = OCCTWireChamfer2D(handle, Int32(vertexIndex), distance1, distance2) else {
            return nil
        }
        return Wire(handle: result)
    }

    /// Apply 2D chamfers (angled corner cuts) to all vertices.
    ///
    /// The wire must be planar. Each corner gets a symmetric chamfer.
    ///
    /// - Parameter distance: Chamfer distance for all corners
    /// - Returns: Wire with chamfered corners, or original wire if some failed
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a rectangle with all corners chamfered
    /// let rect = Wire.rectangle(width: 10, height: 5)
    /// let chamfered = rect?.chamferedAll2D(distance: 1.0)
    /// ```
    public func chamferedAll2D(distance: Double) -> Wire? {
        guard let result = OCCTWireChamferAll2D(handle, distance) else {
            return nil
        }
        return Wire(handle: result)
    }
}

// MARK: - Helix Curves (v0.28.0)

extension Wire {
    /// Create a helical wire with constant radius.
    ///
    /// - Parameters:
    ///   - origin: Center point of the helix axis
    ///   - axis: Direction of the helix axis (default: Z-up)
    ///   - radius: Helix radius
    ///   - pitch: Distance between consecutive turns
    ///   - turns: Number of turns
    ///   - clockwise: Winding direction (default: false = counter-clockwise)
    /// - Returns: A helical wire, or nil on failure
    ///
    /// - Important: `clockwise: false` reverses the internal build axis, so the wire's actual
    ///   start point and winding are not simply `origin + (radius, 0, 0)` ascending along `axis`
    ///   as a naive right-handed parametrization would suggest. If you need the exact start point
    ///   or tangent (for example to place a profile for `Shape.pipeShell`), measure it from the
    ///   wire itself rather than computing it analytically:
    ///
    ///   ```swift
    ///   guard let curve = spine.edges().first?.curve3D else { return }
    ///   let (start, tangent) = curve.d1(at: curve.domain.lowerBound)
    ///   ```
    ///
    ///   Computing it analytically and
    ///   getting the axis convention backwards is exactly what produced OCCTSwift #721, where a
    ///   profile ended up 2×radius from the spine with an inverted tangent, silently corrupting
    ///   `.correctedFrenet` sweeps (but not `.frenet`, by an unrelated coincidence) on the
    ///   resulting pipe shell.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let spring = Wire.helix(radius: 5, pitch: 2, turns: 10)
    /// ```
    public static func helix(
        origin: SIMD3<Double> = .zero,
        axis: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double,
        pitch: Double,
        turns: Double,
        clockwise: Bool = false
    ) -> Wire? {
        guard radius > 0, pitch > 0, turns > 0 else { return nil }
        guard let handle = OCCTWireCreateHelix(
            origin.x, origin.y, origin.z,
            axis.x, axis.y, axis.z,
            radius, pitch, turns, clockwise
        ) else { return nil }
        return Wire(handle: handle)
    }

    /// Create a tapered (conical) helical wire.
    ///
    /// The radius varies linearly from `startRadius` to `endRadius` along the axis.
    ///
    /// - Parameters:
    ///   - origin: Center point of the helix axis
    ///   - axis: Direction of the helix axis (default: Z-up)
    ///   - startRadius: Radius at the start
    ///   - endRadius: Radius at the end
    ///   - pitch: Distance between consecutive turns
    ///   - turns: Number of turns
    ///   - clockwise: Winding direction (default: false = counter-clockwise)
    /// - Returns: A tapered helical wire, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cone = Wire.helixTapered(startRadius: 10, endRadius: 2, pitch: 3, turns: 5)
    /// ```
    public static func helixTapered(
        origin: SIMD3<Double> = .zero,
        axis: SIMD3<Double> = SIMD3(0, 0, 1),
        startRadius: Double,
        endRadius: Double,
        pitch: Double,
        turns: Double,
        clockwise: Bool = false
    ) -> Wire? {
        guard startRadius > 0, endRadius > 0, pitch > 0, turns > 0 else { return nil }
        guard let handle = OCCTWireCreateHelixTapered(
            origin.x, origin.y, origin.z,
            axis.x, axis.y, axis.z,
            startRadius, endRadius, pitch, turns, clockwise
        ) else { return nil }
        return Wire(handle: handle)
    }
}

// MARK: - Wire Explorer (v0.29.0)

extension Wire {
    /// Number of edges in this wire, traversed in order.
    public var orderedEdgeCount: Int {
        Int(OCCTWireExplorerEdgeCount(handle))
    }

    /// Get the number of discretized points for an edge by its ordered index.
    ///
    /// - Parameter index: 0-based edge index in traversal order
    /// - Returns: Number of points, or 0 if index is out of range
    public func orderedEdgePointCount(at index: Int) -> Int {
        guard index >= 0 else { return 0 }
        return Int(OCCTWireExplorerGetEdgePointCount(handle, Int32(index)))
    }

    /// Get the discretized points of an edge by its ordered index.
    ///
    /// Uses `BRepTools_WireExplorer` for ordered traversal, ensuring
    /// edges are visited in connected sequence.
    ///
    /// When called without `maxPoints`, automatically allocates a buffer
    /// large enough for all discretized points (no truncation).
    ///
    /// - Parameters:
    ///   - index: 0-based edge index in traversal order
    ///   - maxPoints: Output *capacity* (default: all points), honoured within `1...`
    ///     ``Sampling/maximumSampleCount``; outside that range the result is nil (#558). This one
    ///     keeps its existing lower bound of 1 rather than clamping to 0, since 0 already meant
    ///     nil here.
    /// - Returns: Array of 3D points along the edge, or nil if index is out of range
    public func orderedEdgePoints(at index: Int, maxPoints: Int? = nil) -> [SIMD3<Double>]? {
        guard index >= 0 else { return nil }
        let limit: Int
        if let maxPoints {
            guard maxPoints > 0, maxPoints <= Sampling.maximumSampleCount else { return nil }
            limit = maxPoints
        } else {
            let count = orderedEdgePointCount(at: index)
            guard count > 0 else { return nil }
            limit = count
        }
        var buffer = [Double](repeating: 0, count: limit * 3)
        var pointCount: Int32 = 0
        guard OCCTWireExplorerGetEdge(handle, Int32(index), &buffer, Int32(limit), &pointCount)
        else { return nil }
        let n = Int(pointCount)
        return unpackSIMD3(buffer, count: n)
    }
}

// MARK: - Wire Edge Access

extension Wire {
    /// Get all edges from this wire as Edge objects.
    ///
    /// Converts the wire to a shape and extracts edges using the shape's
    /// edge extraction facilities.
    ///
    /// - Returns: Array of edges, or empty array if conversion fails
    public func edges() -> [Edge] {
        guard let shape = Shape.fromWire(self) else { return [] }
        return shape.edges()
    }

    /// Get all edges as discretized polylines.
    ///
    /// Convenience method that converts the wire to a shape and calls
    /// `allEdgePolylines()` on it.
    ///
    /// - Parameters:
    ///   - deflection: Maximum chord deviation
    ///   - maxPointsPerEdge: Maximum points per edge
    /// - Returns: Array of polylines, one per edge
    public func allEdgePolylines(
        deflection: Double = 0.1,
        maxPointsPerEdge: Int = 1000
    ) -> [[SIMD3<Double>]] {
        guard let shape = Shape.fromWire(self) else { return [] }
        return shape.allEdgePolylines(deflection: deflection, maxPointsPerEdge: maxPointsPerEdge)
    }

    /// Get a single edge's polyline by index.
    ///
    /// - Parameters:
    ///   - index: 0-based edge index
    ///   - deflection: Maximum chord deviation
    ///   - maxPoints: Maximum points to return
    /// - Returns: Array of 3D points along the edge, or nil if index is out of range
    public func edgePolyline(
        at index: Int,
        deflection: Double = 0.1,
        maxPoints: Int = 1000
    ) -> [SIMD3<Double>]? {
        guard let shape = Shape.fromWire(self) else { return nil }
        return shape.edgePolyline(at: index, deflection: deflection, maxPoints: maxPoints)
    }

    /// Get the bounding box of this wire.
    ///
    /// - Warning: Forwards to ``Shape/bounds``, including its void-shape fabrication: an
    ///   unconvertible or degenerate wire reports `(0,0,0)-(0,0,0)`, indistinguishable from a
    ///   genuine zero-size wire at the origin (#834).
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        guard let shape = Shape.fromWire(self) else {
            return nil
        }
        return shape.bounds
    }
}

// MARK: - Wire Topology Analysis (v0.37.0)

/// Result of wire topology analysis.
public struct WireAnalysis: Sendable {
    /// Whether the wire forms a closed loop
    public var isClosed: Bool
    /// Whether the wire has small/degenerate edges
    public var hasSmallEdges: Bool
    /// Whether there are 3D gaps between edges
    public var hasGaps: Bool
    /// Whether the wire self-intersects
    public var hasSelfIntersection: Bool
    /// Whether edges are properly ordered
    public var isOrdered: Bool
    /// Minimum 3D gap distance
    public var minGap: Double
    /// Maximum 3D gap distance
    public var maxGap: Double
    /// Number of edges
    public var edgeCount: Int
}

extension Wire {
    /// Analyze wire topology for potential issues.
    ///
    /// Checks closure, edge connectivity, gaps, self-intersection, and ordering.
    ///
    /// - Parameter tolerance: Analysis tolerance
    /// - Returns: Analysis results, or nil if analysis fails
    public func analyze(tolerance: Double = 1e-6) -> WireAnalysis? {
        var result = OCCTWireAnalysisResult()
        guard OCCTWireAnalyze(handle, tolerance, &result) else { return nil }
        return WireAnalysis(
            isClosed: result.isClosed,
            hasSmallEdges: result.hasSmallEdges,
            hasGaps: result.hasGaps3d,
            hasSelfIntersection: result.hasSelfIntersection,
            isOrdered: result.isOrdered,
            minGap: result.minDistance3d,
            maxGap: result.maxDistance3d,
            edgeCount: Int(result.edgeCount)
        )
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

import Foundation
import OCCTBridge
import simd

/// A 2D grid of points sampled over a surface's UV parameter space.
///
/// Returned by ``Surface/drawMesh(uCount:vCount:)`` and
/// ``Surface/evaluateGrid(uParameters:vParameters:)``. Both share this type specifically so
/// indexing is unambiguous: access is always `.at(u:v:)`, regardless of how each method lays out
/// its own bridge buffer internally — there is no `[[SIMD3<Double>]]` nesting order left for a
/// caller to get backwards between the two.
///
/// ```swift
/// let grid = surface.drawMesh(uCount: 20, vCount: 10)
/// let corner = grid.at(u: 0, v: 0)
/// let opposite = grid.at(u: grid.uCount - 1, v: grid.vCount - 1)
/// ```
public struct SurfaceGrid: Sendable {
    /// Number of samples in the U direction.
    public let uCount: Int
    /// Number of samples in the V direction.
    public let vCount: Int
    /// Flat storage, U-major: `points[surfaceGridIndex(u:v:vCount:)]`.
    private let points: [SIMD3<Double>]

    init(uCount: Int, vCount: Int, points: [SIMD3<Double>]) {
        self.uCount = uCount
        self.vCount = vCount
        self.points = points
    }

    static let empty = SurfaceGrid(uCount: 0, vCount: 0, points: [])

    /// Whether this grid has no points (returned when sampling fails).
    public var isEmpty: Bool { points.isEmpty }

    /// Point at the given U/V grid index.
    public func at(u: Int, v: Int) -> SIMD3<Double> {
        precondition(
            u >= 0 && u < uCount && v >= 0 && v < vCount,
            "SurfaceGrid.at(u: \(u), v: \(v)) out of range (uCount: \(uCount), vCount: \(vCount))")
        return points[surfaceGridIndex(u: u, v: v, vCount: vCount)]
    }
}

/// The one definition of a UV grid's flat storage index: **U-major**, u varying slowest.
///
/// Shared by ``SurfaceGrid`` and ``SurfaceGridD1``, and mirroring the bridge's own
/// `occtSurfaceGridIndex` so the Swift and C sides of the same buffer cannot disagree. #486:
/// two bridge functions once wrote opposite layouts, each header calling its own "row-major",
/// a phrase that says nothing about a UV grid, where either parameter can be the row.
@inline(__always)
internal func surfaceGridIndex(u: Int, v: Int, vCount: Int) -> Int {
    u * vCount + v
}

/// A 2D grid of points and first partial derivatives sampled over a surface's UV parameter space.
///
/// The D1 counterpart of ``SurfaceGrid``, returned by
/// ``Surface/evaluateGridD1(uParameters:vParameters:)``. Indexing is `.at(u:v:)` for the same
/// reason: a flat `[(point:, d1u:, d1v:)]` array leaves the caller guessing whether u or v runs
/// fastest.
///
/// ```swift
/// let grid = surface.evaluateGridD1(uParameters: [0, 0.5, 1], vParameters: [0, 1])
/// let sample = grid.at(u: 2, v: 0)
/// let normal = simd_normalize(simd_cross(sample.d1u, sample.d1v))
/// ```
public struct SurfaceGridD1: Sendable {
    /// Number of samples in the U direction.
    public let uCount: Int
    /// Number of samples in the V direction.
    public let vCount: Int
    /// Flat storage, U-major: `points[surfaceGridIndex(u:v:vCount:)]`.
    private let points: [SIMD3<Double>]
    private let d1u: [SIMD3<Double>]
    private let d1v: [SIMD3<Double>]

    init(
        uCount: Int, vCount: Int,
        points: [SIMD3<Double>], d1u: [SIMD3<Double>], d1v: [SIMD3<Double>]
    ) {
        self.uCount = uCount
        self.vCount = vCount
        self.points = points
        self.d1u = d1u
        self.d1v = d1v
    }

    static let empty = SurfaceGridD1(uCount: 0, vCount: 0, points: [], d1u: [], d1v: [])

    /// Whether this grid has no samples (returned when evaluation fails).
    public var isEmpty: Bool { points.isEmpty }

    /// Point and first partial derivatives at the given U/V grid index.
    public func at(u: Int, v: Int) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
    {
        precondition(
            u >= 0 && u < uCount && v >= 0 && v < vCount,
            "SurfaceGridD1.at(u: \(u), v: \(v)) out of range (uCount: \(uCount), vCount: \(vCount))"
        )
        let i = surfaceGridIndex(u: u, v: v, vCount: vCount)
        return (point: points[i], d1u: d1u[i], d1v: d1v[i])
    }
}

/// A parametric surface backed by OpenCASCADE Handle(Geom_Surface).
///
/// Wraps analytic surfaces (plane, cylinder, cone, sphere, torus),
/// swept surfaces (extrusion, revolution), freeform surfaces (Bezier, BSpline),
/// and derived surfaces (trimmed, offset) polymorphically.
public final class Surface: @unchecked Sendable {
    internal let handle: OCCTSurfaceRef

    internal init(handle: OCCTSurfaceRef) {
        self.handle = handle
    }

    deinit {
        OCCTSurfaceRelease(handle)
    }

    // MARK: - Properties

    /// Surface type classification (matches GeomAbs_SurfaceType).
    public enum SurfaceType: Int32, Sendable {
        case plane = 0
        case cylinder = 1
        case cone = 2
        case sphere = 3
        case torus = 4
        case bezierSurface = 5
        case bsplineSurface = 6
        case surfaceOfRevolution = 7
        case surfaceOfExtrusion = 8
        case offsetSurface = 9
        case other = 10
    }

    /// The specific geometric kind of this surface (Geom subclass).
    public var surfaceKind: SurfaceType {
        SurfaceType(rawValue: OCCTSurfaceGetType(handle)) ?? .other
    }

    /// Measured overall continuity of the surface.
    ///
    /// ```swift
    /// let cylinder = Surface.cylinder(radius: 5)
    /// print(cylinder?.continuityClass)                    // .cN
    /// print(cylinder?.continuityClass.satisfies(.c2))     // true
    /// ```
    ///
    /// - Note: Reports a *measured* class, not a requested order. Its raw values are
    ///   `GeomAbs_Shape`'s own ordinals, which are not a 0/1/2 order. Do not confuse it with
    ///   the top-level ``SurfaceContinuity``, one dot away, which is the G0/G1/G2 order you
    ///   *request* of a filling or plate constraint. See #398 for the full census.
    public var continuityClass: ContinuityClass {
        ContinuityClass(rawValue: OCCTSurfaceGetContinuity(handle)) ?? .c0
    }

    public var isPlane: Bool { surfaceKind == .plane }
    public var isCylinder: Bool { surfaceKind == .cylinder }
    public var isCone: Bool { surfaceKind == .cone }
    public var isSphere: Bool { surfaceKind == .sphere }
    public var isTorus: Bool { surfaceKind == .torus }
    public var isBezier: Bool { surfaceKind == .bezierSurface }
    public var isBSpline: Bool { surfaceKind == .bsplineSurface }
    public var isSurfaceOfRevolution: Bool { surfaceKind == .surfaceOfRevolution }
    public var isSurfaceOfExtrusion: Bool { surfaceKind == .surfaceOfExtrusion }
    public var isOffsetSurface: Bool { surfaceKind == .offsetSurface }

    /// Parameter domain (uMin, uMax, vMin, vMax).
    public var domain: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin: Double = 0
        var uMax: Double = 0
        var vMin: Double = 0
        var vMax: Double = 0
        OCCTSurfaceGetDomain(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Whether the surface is closed in U direction.
    public var isUClosed: Bool {
        OCCTSurfaceIsUClosed(handle)
    }

    /// Whether the surface is closed in V direction.
    public var isVClosed: Bool {
        OCCTSurfaceIsVClosed(handle)
    }

    /// Whether the surface is periodic in U direction.
    public var isUPeriodic: Bool {
        OCCTSurfaceIsUPeriodic(handle)
    }

    /// Whether the surface is periodic in V direction.
    public var isVPeriodic: Bool {
        OCCTSurfaceIsVPeriodic(handle)
    }

    /// Period in U direction (nil if not periodic).
    public var uPeriod: Double? {
        guard isUPeriodic else { return nil }
        return OCCTSurfaceGetUPeriod(handle)
    }

    /// Period in V direction (nil if not periodic).
    public var vPeriod: Double? {
        guard isVPeriodic else { return nil }
        return OCCTSurfaceGetVPeriod(handle)
    }

    // MARK: - Evaluation

    /// Evaluate surface point at (u, v).
    public func point(atU u: Double, v: Double) -> SIMD3<Double> {
        unwrapVectorComponents { OCCTSurfaceGetPoint(handle, u, v, $0, $1, $2) }
    }

    /// First-order derivatives at (u, v).
    public func d1(atU u: Double, v: Double) -> (
        point: SIMD3<Double>, du: SIMD3<Double>, dv: SIMD3<Double>
    ) {
        var px: Double = 0
        var py: Double = 0
        var pz: Double = 0
        var dux: Double = 0
        var duy: Double = 0
        var duz: Double = 0
        var dvx: Double = 0
        var dvy: Double = 0
        var dvz: Double = 0
        OCCTSurfaceD1(handle, u, v, &px, &py, &pz, &dux, &duy, &duz, &dvx, &dvy, &dvz)
        return (SIMD3(px, py, pz), SIMD3(dux, duy, duz), SIMD3(dvx, dvy, dvz))
    }

    /// Second-order derivatives at (u, v).
    public func d2(atU u: Double, v: Double) -> (
        point: SIMD3<Double>,
        d1u: SIMD3<Double>, d1v: SIMD3<Double>,
        d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>
    ) {
        var px: Double = 0
        var py: Double = 0
        var pz: Double = 0
        var d1ux: Double = 0
        var d1uy: Double = 0
        var d1uz: Double = 0
        var d1vx: Double = 0
        var d1vy: Double = 0
        var d1vz: Double = 0
        var d2ux: Double = 0
        var d2uy: Double = 0
        var d2uz: Double = 0
        var d2vx: Double = 0
        var d2vy: Double = 0
        var d2vz: Double = 0
        var d2uvx: Double = 0
        var d2uvy: Double = 0
        var d2uvz: Double = 0
        OCCTSurfaceD2(
            handle, u, v, &px, &py, &pz,
            &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
            &d2uvx, &d2uvy, &d2uvz)
        return (
            SIMD3(px, py, pz),
            SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
            SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz),
            SIMD3(d2uvx, d2uvy, d2uvz)
        )
    }

    /// Surface normal at (u, v).
    public func normal(atU u: Double, v: Double) -> SIMD3<Double>? {
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        guard OCCTSurfaceGetNormal(handle, u, v, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    // MARK: - Analytic Surfaces

    /// Create an infinite plane from a point and normal direction.
    ///
    /// A spelling of `planeFromPointNormal(point:normal:)` with unlabeled positional arguments,
    /// and it delegates to it — the two cannot produce different planes for the same input (#421).
    ///
    /// - Parameters:
    ///   - origin: A point on the plane
    ///   - normal: Normal direction of the plane
    /// - Returns: Plane surface, or nil if `normal` has zero (or near-zero) length
    ///
    /// ```swift
    /// let ground = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
    /// #expect(ground != nil)
    /// ```
    public static func plane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Surface? {
        planeFromPointNormal(point: origin, normal: normal)
    }

    /// Create a cylindrical surface.
    public static func cylinder(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        radius: Double
    ) -> Surface? {
        guard
            let h = OCCTSurfaceCreateCylinder(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface.
    public static func cone(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        radius: Double, semiAngle: Double
    ) -> Surface? {
        guard
            let h = OCCTSurfaceCreateCone(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z,
                radius, semiAngle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a spherical surface.
    public static func sphere(center: SIMD3<Double>, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateSphere(center.x, center.y, center.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a toroidal surface.
    public static func torus(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Surface? {
        guard
            let h = OCCTSurfaceCreateTorus(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z,
                majorRadius, minorRadius)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Swept Surfaces

    /// Create a surface by extruding a curve along a direction.
    public static func extrusion(profile: Curve3D, direction: SIMD3<Double>) -> Surface? {
        guard
            let h = OCCTSurfaceCreateExtrusion(
                profile.handle,
                direction.x, direction.y, direction.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a surface of revolution by revolving a curve around an axis.
    public static func revolution(
        meridian: Curve3D,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>
    ) -> Surface? {
        guard
            let h = OCCTSurfaceCreateRevolution(
                meridian.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Freeform Surfaces

    /// Create a Bezier surface from control points.
    ///
    /// - Parameters:
    ///   - poles: 2D array of control points `[uRow][vCol]`, **at least 2 × 2**.
    ///   - weights: Optional 2D array of weights (same dimensions as poles).
    /// - Returns: The surface, or `nil` if either direction has fewer than 2 poles or OCCT rejects
    ///   the poles. Unlike ``drawMesh(uCount:vCount:)``, whose superficially identical minimum of 2
    ///   turned out to be a bridge artifact (#620), this one is the kernel's: a Bezier's degree is
    ///   its pole count minus 1 and must be at least 1, so `Geom_BezierSurface` raises
    ///   `Standard_ConstructionError` on a single-pole direction. A 2 × 2 patch is the smallest
    ///   legal one, bilinear in both directions.
    ///
    /// ```swift
    /// let patch = Surface.bezier(poles: [
    ///     [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
    ///     [SIMD3(1, 0, 0), SIMD3(1, 1, 1)],
    /// ])
    /// ```
    public static func bezier(
        poles: [[SIMD3<Double>]],
        weights: [[Double]]? = nil
    ) -> Surface? {
        let uCount = Int32(poles.count)
        guard uCount >= 2 else { return nil }
        let vCount = Int32(poles[0].count)
        guard vCount >= 2 else { return nil }

        var flatPoles = [Double]()
        flatPoles.reserveCapacity(Int(uCount * vCount) * 3)
        for row in poles {
            for p in row {
                flatPoles.append(p.x)
                flatPoles.append(p.y)
                flatPoles.append(p.z)
            }
        }

        if let w = weights {
            var flatWeights = [Double]()
            flatWeights.reserveCapacity(Int(uCount * vCount))
            for row in w {
                flatWeights.append(contentsOf: row)
            }
            let h = flatPoles.withUnsafeBufferPointer { pPtr in
                flatWeights.withUnsafeBufferPointer { wPtr in
                    OCCTSurfaceCreateBezier(
                        pPtr.baseAddress, uCount, vCount,
                        wPtr.baseAddress)
                }
            }
            guard let h = h else { return nil }
            return Surface(handle: h)
        } else {
            let h = flatPoles.withUnsafeBufferPointer { pPtr in
                OCCTSurfaceCreateBezier(pPtr.baseAddress, uCount, vCount, nil)
            }
            guard let h = h else { return nil }
            return Surface(handle: h)
        }
    }

    /// Create a BSpline surface.
    /// - Parameters:
    ///   - poles: 2D array of control points [uRow][vCol]
    ///   - weights: Optional 2D array of weights
    ///   - knotsU: Knot values in U direction
    ///   - multiplicitiesU: Knot multiplicities in U direction
    ///   - knotsV: Knot values in V direction
    ///   - multiplicitiesV: Knot multiplicities in V direction
    ///   - degreeU: Polynomial degree in U
    ///   - degreeV: Polynomial degree in V
    /// - Returns: The constructed surface, or nil if the pole/knot/multiplicity data is invalid.
    public static func bspline(
        poles: [[SIMD3<Double>]],
        weights: [[Double]]? = nil,
        knotsU: [Double], multiplicitiesU: [Int32],
        knotsV: [Double], multiplicitiesV: [Int32],
        degreeU: Int, degreeV: Int
    ) -> Surface? {
        let uCount = Int32(poles.count)
        guard uCount >= 2 else { return nil }
        let vCount = Int32(poles[0].count)
        guard vCount >= 2 else { return nil }

        var flatPoles = [Double]()
        flatPoles.reserveCapacity(Int(uCount * vCount) * 3)
        for row in poles {
            for p in row {
                flatPoles.append(p.x)
                flatPoles.append(p.y)
                flatPoles.append(p.z)
            }
        }

        let result: OCCTSurfaceRef? = flatPoles.withUnsafeBufferPointer { pPtr in
            knotsU.withUnsafeBufferPointer { kuPtr in
                knotsV.withUnsafeBufferPointer { kvPtr in
                    multiplicitiesU.withUnsafeBufferPointer { muPtr in
                        multiplicitiesV.withUnsafeBufferPointer { mvPtr in
                            if let w = weights {
                                var flatWeights = [Double]()
                                flatWeights.reserveCapacity(Int(uCount * vCount))
                                for row in w { flatWeights.append(contentsOf: row) }
                                return flatWeights.withUnsafeBufferPointer { wPtr in
                                    OCCTSurfaceCreateBSpline(
                                        pPtr.baseAddress, uCount, vCount,
                                        wPtr.baseAddress,
                                        kuPtr.baseAddress, Int32(knotsU.count),
                                        kvPtr.baseAddress, Int32(knotsV.count),
                                        muPtr.baseAddress, mvPtr.baseAddress,
                                        Int32(degreeU), Int32(degreeV))
                                }
                            } else {
                                return OCCTSurfaceCreateBSpline(
                                    pPtr.baseAddress, uCount, vCount,
                                    nil,
                                    kuPtr.baseAddress, Int32(knotsU.count),
                                    kvPtr.baseAddress, Int32(knotsV.count),
                                    muPtr.baseAddress, mvPtr.baseAddress,
                                    Int32(degreeU), Int32(degreeV))
                            }
                        }
                    }
                }
            }
        }
        guard let h = result else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Operations

    /// Create a rectangular trim of this surface.
    public func trimmed(u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let h = OCCTSurfaceTrim(handle, u1, u2, v1, v2) else { return nil }
        return Surface(handle: h)
    }

    /// Create an offset surface at a given distance from this surface.
    public func offset(distance: Double) -> Surface? {
        guard let h = OCCTSurfaceOffset(handle, distance) else { return nil }
        return Surface(handle: h)
    }

    /// Translated copy.
    public func translated(by delta: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceTranslate(handle, delta.x, delta.y, delta.z) else { return nil }
        return Surface(handle: h)
    }

    /// Rotated copy around an axis.
    public func rotated(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
        angle: Double
    ) -> Surface? {
        guard
            let h = OCCTSurfaceRotate(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Scaled copy from a center point.
    public func scaled(center: SIMD3<Double>, factor: Double) -> Surface? {
        guard let h = OCCTSurfaceScale(handle, center.x, center.y, center.z, factor)
        else { return nil }
        return Surface(handle: h)
    }

    /// Mirrored copy across a plane.
    public func mirrored(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Surface? {
        guard
            let h = OCCTSurfaceMirrorPlane(
                handle,
                planeOrigin.x, planeOrigin.y, planeOrigin.z,
                planeNormal.x, planeNormal.y, planeNormal.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Mirrored copy across a point.
    ///
    /// ```swift
    /// let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
    /// let mirrored = plane?.mirrored(acrossPoint: SIMD3(1, 1, 1))
    /// ```
    public func mirrored(acrossPoint point: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceMirrorPoint(handle, point.x, point.y, point.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Mirrored copy across an axis (line).
    ///
    /// ```swift
    /// let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
    /// let mirrored = plane?.mirrored(acrossAxis: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
    /// ```
    public func mirrored(acrossAxis point: SIMD3<Double>, direction: SIMD3<Double>) -> Surface? {
        guard
            let h = OCCTSurfaceMirrorAxis(
                handle, point.x, point.y, point.z,
                direction.x, direction.y, direction.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Conversion

    /// Convert to a BSpline representation, exactly where OCCT can and by approximation where it
    /// cannot.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 10)!
    /// let bspline = sphere.toBSpline()      // exact: degree 2, 6x5 poles
    ///
    /// // An offset surface with no analytic equivalent is approximated instead.
    /// let approximated = sphere.offset(distance: 1)?.trimmed(u1: 0, u2: 4, v1: -1, v2: 1)?.toBSpline()
    /// ```
    ///
    /// - Important: This is not an exactness guarantee, and it takes no tolerance. Analytic
    ///   families (plane, cylinder, cone, sphere, torus, surface of revolution) and Bezier and
    ///   BSpline surfaces convert exactly. Everything else, including offset surfaces with no
    ///   analytic equivalent, is handed to `GeomConvert_ApproxSurface` at a tolerance OCCT
    ///   hardcodes to `1e-4`, with a continuity it derives from the surface's own `IsCNu`/`IsCNv`,
    ///   and the result is returned whether or not that tolerance was met. Measured on a trimmed
    ///   offset of a B-spline that is C1 but not C2 in U, the conversion caps out at degree 14 and
    ///   sits 0.038 from its source (#572). Use ``approximated(tolerance:continuity:maxSegments:maxDegree:)``
    ///   when you need to name the tolerance, and ``approxWithDetails(tolerance:uContinuity:vContinuity:maxSegments:maxDegree:)``
    ///   when you need to know whether it was reached.
    /// - Returns: The BSpline surface, or `nil` when OCCT produced none. An unbounded surface
    ///   throws inside OCCT and surfaces here as `nil`; trim it first with
    ///   ``trimmed(u1:u2:v1:v2:)``.
    public func toBSpline() -> Surface? {
        guard let h = OCCTSurfaceToBSpline(handle) else { return nil }
        return Surface(handle: h)
    }

    /// Approximate as a BSpline surface within tolerance.
    ///
    /// - Parameters:
    ///   - tolerance: Maximum approximation error
    ///   - continuity: A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2). The
    ///     approximator accepts nothing stricter: `AdvApprox` throws for C3 and above, which
    ///     surfaces here as `nil`.
    ///   - maxSegments: Maximum number of B-spline segments
    ///   - maxDegree: Maximum polynomial degree
    ///
    /// Defaults (`tolerance: 1e-3`, `maxDegree: 8`) match `Curve3D.approximated`/
    /// `Curve2D.approximated` (#406): all three wrap the same `GeomConvert_Approx*`/
    /// `Geom2dConvert_ApproxCurve` family applied to a different OCCT geometry hierarchy
    /// (surface vs. 3D curve vs. 2D curve), not independent algorithms whose numeric defaults
    /// should be tuned independently. Measured directly (analytic primitives — sphere, torus,
    /// trimmed cylinder/cone — and a 40x40-point BSpline fit): the tighter tolerance and lower
    /// degree succeed on every case tried, with no meaningful cost difference, so there was no
    /// dimensional justification for the looser values this used to default to. An
    /// infinite/unbounded surface must still be trimmed to a finite parameter domain before
    /// calling this (see `trimmed(u1:u2:v1:v2:)`) — approximation does not do that for you.
    ///
    /// Returns the fitted surface whenever OCCT produced one, which — per `HasResult()` — includes
    /// a best-effort fit that did *not* reach `tolerance`. A non-nil result is therefore not a
    /// promise that `tolerance` was met; on a surface where `maxDegree` cannot reach it (a torus at
    /// 1e-9, say) OCCT returns a usable surface anyway.
    /// ``Surface/approxWithDetails(tolerance:uContinuity:vContinuity:maxDegree:maxSegments:)``
    /// runs the identical approximation (one shared `GeomConvert_ApproxSurface` behind both since
    /// #491) and reports the actual `maxError` plus an `isDone` flag.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// let bsp = sphere.approximated(tolerance: 1e-3, maxDegree: 8)
    /// ```
    ///
    /// - Returns: The fitted surface, or nil if the approximation could not be constructed at all.
    public func approximated(
        tolerance: Double = 1e-3, continuity: Int = 2,
        maxSegments: Int = 100, maxDegree: Int = 8
    ) -> Surface? {
        guard
            let h = OCCTSurfaceApproximate(
                handle, tolerance, Int32(continuity),
                Int32(maxSegments), Int32(maxDegree))
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Iso Curves

    /// Extract a U-iso curve (constant U, varying V).
    public func uIso(at u: Double) -> Curve3D? {
        guard let h = OCCTSurfaceUIso(handle, u) else { return nil }
        return Curve3D(handle: h)
    }

    /// Extract a V-iso curve (constant V, varying U).
    public func vIso(at v: Double) -> Curve3D? {
        guard let h = OCCTSurfaceVIso(handle, v) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - Pipe Surfaces

    /// Create a pipe surface by sweeping a circle along a path.
    public static func pipe(path: Curve3D, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreatePipe(path.handle, radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a pipe surface by sweeping a section curve along a path.
    public static func pipe(path: Curve3D, section: Curve3D) -> Surface? {
        guard let h = OCCTSurfaceCreatePipeWithSection(path.handle, section.handle)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Draw Methods

    /// Draw iso-parameter grid lines for Metal visualization.
    /// - Parameters:
    ///   - uLineCount: Number of U-iso lines, at least 0.
    ///   - vLineCount: Number of V-iso lines, at least 0.
    ///   - pointsPerLine: Points per iso line, at least 1.
    /// - Returns: Array of polylines, each a [SIMD3<Double>], or empty if the grid cannot be
    ///   served. The bound is on the total: `(uLineCount + vLineCount) * pointsPerLine` must not
    ///   exceed ``Sampling/maximumSampleCount`` (#558). Each factor is also checked on its own,
    ///   since a negative line count used to abort the process unless the other count happened to
    ///   outweigh it.
    public func drawGrid(
        uLineCount: Int = 10, vLineCount: Int = 10,
        pointsPerLine: Int = 50
    ) -> [[SIMD3<Double>]] {
        // Bound each line count before adding: the sum is what sizes `lineLengths`, and two counts
        // near `Int.max` overflow the addition itself into a trap before any ceiling is consulted.
        guard uLineCount >= 0, uLineCount <= Sampling.maximumSampleCount,
            vLineCount >= 0, vLineCount <= Sampling.maximumSampleCount
        else { return [] }
        let maxLines = uLineCount + vLineCount
        guard let maxPoints = Sampling.gridTotal(maxLines, pointsPerLine, atLeast: 0),
            maxPoints > 0
        else { return [] }
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        var lineLengths = [Int32](repeating: 0, count: maxLines)

        let totalPoints = Int(
            OCCTSurfaceDrawGrid(
                handle, Int32(uLineCount), Int32(vLineCount), Int32(pointsPerLine),
                &buffer, Int32(maxPoints), &lineLengths, Int32(maxLines)))

        guard totalPoints > 0 else { return [] }

        var result = [[SIMD3<Double>]]()
        var offset = 0
        for i in 0..<maxLines {
            let count = Int(lineLengths[i])
            if count == 0 { continue }
            var line = [SIMD3<Double>]()
            line.reserveCapacity(count)
            for j in 0..<count {
                let idx = (offset + j) * 3
                line.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            result.append(line)
            offset += count
        }
        return result
    }

    /// Sample a uniform grid of points over the surface's parametric bounds.
    ///
    /// - Parameters:
    ///   - uCount: Samples in U, at least 1.
    ///   - vCount: Samples in V, at least 1.
    /// - Returns: A ``SurfaceGrid`` indexed `.at(u:v:)`, or an empty grid if sampling fails or the
    ///   grid cannot be served. The bound is on the **product**: `uCount * vCount` must not exceed
    ///   ``Sampling/maximumSampleCount`` (#558). Each factor is also checked on its own, which is
    ///   not redundant — two negative counts multiply to a plausible positive total, so
    ///   `drawMesh(uCount: -1, vCount: -1)` used to look well-behaved while
    ///   `drawMesh(uCount: -1, vCount: 3)` aborted the process.
    ///
    /// Samples span the **sampled range**, which is the surface's parametric domain with infinite
    /// bounds clamped to ±100. For a bounded surface that is ``domain``; for an unbounded one
    /// (a plane, an unbounded cylinder) it is not, and the difference is extreme rather than
    /// marginal — a plane's `domain.uMin` is about -2e100 while its first sample sits at -100.
    ///
    /// **One sample in a direction is a request, not a degenerate case.** Despite the name nothing
    /// here triangulates: the bridge walks that range evaluating the surface pointwise, so
    /// `uCount: 1` is the single iso-row at the low end of the sampled U range and a 1×1 grid is
    /// one point. The bridge used to demand 2 per direction — its own interpolation divisor, not
    /// an OCCT rule — so a request this doc called in-range came back as an empty grid the caller
    /// could not tell apart from a surface that failed to sample (#620). Counts below 1 are still
    /// rejected, and rejection is still an empty grid, the documented answer every ``Sampling``
    /// entry point gives.
    ///
    /// ```swift
    /// let grid = surface.drawMesh(uCount: 30, vCount: 30)
    /// let p = grid.at(u: 5, v: 3)
    ///
    /// // A single V iso-row: 20 points along v, at the low end of the sampled U range.
    /// let isoRow = surface.drawMesh(uCount: 1, vCount: 20)
    /// let along = (0..<isoRow.vCount).map { isoRow.at(u: 0, v: $0) }
    ///
    /// // Bounded surface: that low end is domain.uMin.
    /// let sphere = Surface.sphere(center: .zero, radius: 10)!
    /// sphere.drawMesh(uCount: 1, vCount: 4).at(u: 0, v: 0)   // == sphere.point(atU: 0, v: -.pi / 2)
    ///
    /// // Unbounded surface: it is the clamp, not domain.uMin.
    /// let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
    /// plane.drawMesh(uCount: 1, vCount: 4).at(u: 0, v: 0).x   // -100, not plane.domain.uMin
    /// ```
    public func drawMesh(uCount: Int = 20, vCount: Int = 20) -> SurfaceGrid {
        // `atLeast: 1` is gridTotal's default, but it is spelled out because it is a contract the
        // bridge has to match exactly: the one time it was left implicit the two disagreed (#620).
        guard let total = Sampling.gridTotal(uCount, vCount, atLeast: 1) else { return .empty }
        var buffer = [Double](repeating: 0, count: total * 3)
        let n = Int(OCCTSurfaceDrawMesh(handle, Int32(uCount), Int32(vCount), &buffer))
        guard n == total else { return .empty }

        // Bridge buffer is already U-major (idx = u * vCount + v), matching SurfaceGrid's storage.
        let points: [SIMD3<Double>] = unpackSIMD3(buffer, count: total)
        return SurfaceGrid(uCount: uCount, vCount: vCount, points: points)
    }

    // MARK: - Local Properties

    /// Gaussian curvature at (u, v), or `nil` where the surface has none.
    ///
    /// - Parameters:
    ///   - u: U parameter.
    ///   - v: V parameter.
    /// - Returns: Gaussian curvature, or `nil` at a point where the tangent vectors are degenerate
    ///   (a cone apex, a sphere pole) and `GeomLProp_SLProps::IsCurvatureDefined()` is false.
    ///
    /// This used to be `0` — which is also the Gaussian curvature of **every point of every plane,
    /// cylinder and cone**, since those are developable. Whole surfaces read as "no answer" (#595).
    /// ``Face/gaussianCurvature(atU:v:)`` reads the same quantity off the same surface through the
    /// face and has always returned an optional; the two now agree.
    ///
    /// `curvatures(u:v:)` returns this value and `meanCurvature(atU:v:)` together from a single
    /// evaluation; all three share one `GeomLProp_SLProps` construction and therefore agree
    /// exactly on both the value and on whether curvature is defined at all.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// if let k = sphere.gaussianCurvature(atU: 0, v: 0) { #expect(abs(k - 1.0 / 25) < 1e-12) }
    ///
    /// let cylinder = Surface.cylinder(axis: .zero, direction: SIMD3(0, 0, 1), radius: 3)!
    /// cylinder.gaussianCurvature(atU: 1, v: 6)   // 0 — developable, and that is the answer
    /// ```
    public func gaussianCurvature(atU u: Double, v: Double) -> Double? {
        var k = 0.0
        guard OCCTSurfaceGetGaussianCurvature(handle, u, v, &k) else { return nil }
        return k
    }

    /// Mean curvature at (u, v), or `nil` where the surface has none.
    ///
    /// - Parameters:
    ///   - u: U parameter.
    ///   - v: V parameter.
    /// - Returns: Mean curvature, or `nil` at a point where the tangent vectors are degenerate and
    ///   `GeomLProp_SLProps::IsCurvatureDefined()` is false.
    ///
    /// This used to be `0`, which is also every point of every plane's real mean curvature (#595),
    /// and it disagreed with ``Face/meanCurvature(atU:v:)``, which already returned an optional.
    ///
    /// `curvatures(u:v:)` returns this value and `gaussianCurvature(atU:v:)` together from a
    /// single evaluation; all three share one `GeomLProp_SLProps` construction.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// if let h = sphere.meanCurvature(atU: 0, v: 0) { #expect(abs(abs(h) - 1.0 / 5) < 1e-12) }
    /// ```
    public func meanCurvature(atU u: Double, v: Double) -> Double? {
        var h = 0.0
        guard OCCTSurfaceGetMeanCurvature(handle, u, v, &h) else { return nil }
        return h
    }

    /// Principal curvature result.
    public struct PrincipalCurvatures: Sendable {
        public let kMin: Double
        public let kMax: Double
        public let dirMin: SIMD3<Double>
        public let dirMax: SIMD3<Double>
    }

    /// Principal curvatures and directions at (u, v).
    public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures? {
        var kMin: Double = 0
        var kMax: Double = 0
        var d1x: Double = 0
        var d1y: Double = 0
        var d1z: Double = 0
        var d2x: Double = 0
        var d2y: Double = 0
        var d2z: Double = 0
        guard
            OCCTSurfaceGetPrincipalCurvatures(
                handle, u, v, &kMin, &kMax,
                &d1x, &d1y, &d1z,
                &d2x, &d2y, &d2z)
        else { return nil }
        return PrincipalCurvatures(
            kMin: kMin, kMax: kMax,
            dirMin: SIMD3(d1x, d1y, d1z),
            dirMax: SIMD3(d2x, d2y, d2z))
    }

    // MARK: - Bounding Box

    /// Axis-aligned bounding box (nil for infinite surfaces).
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xMin: Double = 0
        var yMin: Double = 0
        var zMin: Double = 0
        var xMax: Double = 0
        var yMax: Double = 0
        var zMax: Double = 0
        guard
            OCCTSurfaceGetBoundingBox(
                handle, &xMin, &yMin, &zMin,
                &xMax, &yMax, &zMax)
        else { return nil }
        return (SIMD3(xMin, yMin, zMin), SIMD3(xMax, yMax, zMax))
    }

    // MARK: - BSpline/Bezier Queries

    /// Number of control points in U direction (0 if not BSpline/Bezier).
    public var uPoleCount: Int {
        Int(OCCTSurfaceGetUPoleCount(handle))
    }

    /// Number of control points in V direction (0 if not BSpline/Bezier).
    public var vPoleCount: Int {
        Int(OCCTSurfaceGetVPoleCount(handle))
    }

    /// Control points as 2D array [uRow][vCol] (empty if not BSpline/Bezier).
    public var poles: [[SIMD3<Double>]] {
        let uCount = uPoleCount
        let vCount = vPoleCount
        guard uCount > 0 && vCount > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: uCount * vCount * 3)
        let n = Int(OCCTSurfaceGetPoles(handle, &buffer))
        guard n == uCount * vCount else { return [] }
        var result = [[SIMD3<Double>]]()
        for i in 0..<uCount {
            var row = [SIMD3<Double>]()
            for j in 0..<vCount {
                let idx = (i * vCount + j) * 3
                row.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            result.append(row)
        }
        return result
    }

    /// Polynomial degree in U direction (0 if not BSpline/Bezier).
    public var uDegree: Int {
        Int(OCCTSurfaceGetUDegree(handle))
    }

    /// Polynomial degree in V direction (0 if not BSpline/Bezier).
    public var vDegree: Int {
        Int(OCCTSurfaceGetVDegree(handle))
    }

    // MARK: - Curve Projection (v0.22.0)

    /// Result of projecting a point onto a surface.
    public struct SurfaceProjection: Sendable {
        public let u: Double
        public let v: Double
        public let distance: Double
    }

    /// Project a 3D curve onto this surface, returning a 2D (UV) parametric curve.
    ///
    /// Uses `GeomProjLib::Curve2d` for analytic projection. The result is a
    /// `Curve2D` in the surface's UV parameter space.
    /// - Parameters:
    ///   - curve: The 3D curve to project
    ///   - tolerance: Projection tolerance (default 1e-4)
    /// - Returns: A 2D curve in UV space, or nil if projection fails
    public func projectCurve(_ curve: Curve3D, tolerance: Double = 1e-4) -> Curve2D? {
        guard let h = OCCTSurfaceProjectCurve2D(handle, curve.handle, tolerance) else {
            return nil
        }
        return Curve2D(handle: h)
    }

    /// Project a 3D curve onto this surface using composite projection.
    ///
    /// Uses `ProjLib_CompProjectedCurve` which handles cases where the curve
    /// projects as multiple disconnected segments in UV space (e.g., when
    /// the curve crosses surface seams or boundaries).
    /// - Parameters:
    ///   - curve: The 3D curve to project
    ///   - tolerance: Projection tolerance (default 1e-4)
    /// - Returns: Array of 2D curves in UV space (may be empty)
    public func projectCurveSegments(_ curve: Curve3D, tolerance: Double = 1e-4) -> [Curve2D] {
        var buffer = [OCCTCurve2DRef?](repeating: nil, count: 32)
        let count = buffer.withUnsafeMutableBufferPointer { ptr in
            OCCTSurfaceProjectCurveSegments(
                handle, curve.handle, tolerance,
                ptr.baseAddress, 32)
        }
        var result = [Curve2D]()
        for i in 0..<Int(count) {
            if let h = buffer[i] {
                result.append(Curve2D(handle: h))
            }
        }
        return result
    }

    /// Project a 3D curve onto this surface, returning the result as a 3D curve.
    ///
    /// Uses `GeomProjLib::Project` for normal projection. The result is a
    /// 3D curve that lies on the surface.
    /// - Parameter curve: The 3D curve to project
    /// - Returns: A 3D curve on the surface, or nil if projection fails
    public func projectCurve3D(_ curve: Curve3D) -> Curve3D? {
        guard let h = OCCTSurfaceProjectCurve3D(handle, curve.handle) else {
            return nil
        }
        return Curve3D(handle: h)
    }

    /// Project a 3D point onto this surface (closest point).
    ///
    /// Uses `GeomAPI_ProjectPointOnSurf` to find the nearest point
    /// on the surface to the given point.
    /// - Parameter point: The 3D point to project
    /// - Returns: UV parameters and distance, or nil if projection fails
    public func projectPoint(_ point: SIMD3<Double>) -> SurfaceProjection? {
        var u: Double = 0
        var v: Double = 0
        var distance: Double = 0
        guard
            OCCTSurfaceProjectPoint(
                handle, point.x, point.y, point.z,
                &u, &v, &distance)
        else {
            return nil
        }
        return SurfaceProjection(u: u, v: v, distance: distance)
    }

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface (parametric) approximating a set of 3D points.
    ///
    /// Uses `GeomPlate_BuildPlateSurface` + `GeomPlate_MakeApprox` to produce a BSpline surface
    /// through the given points. It **approximates** rather than interpolates: the fit subdivides
    /// into more Bezier patches until it is within `tolerance` of the plate, and a cloud that
    /// cannot be fitted that tightly still returns its best effort. Check the result:
    ///
    /// ```swift
    /// let points: [SIMD3<Double>] = (0..<5).flatMap { i in
    ///     (0..<5).map { j in
    ///         SIMD3(Double(i) * 4, Double(j) * 4,
    ///               4 * sin(Double(i) * 1.3) * cos(Double(j) * 1.1))
    ///     }
    /// }
    /// if let plate = Surface.plateThrough(points, degree: 3, tolerance: 0.01) {
    ///     let worst = points.compactMap { plate.projectPoint($0)?.distance }.max() ?? 0
    ///     print(worst)              // 0.0032 — inside tolerance
    ///     print(plate.uPoleCount)   // 16 — more than one patch, so the fit did subdivide
    /// }
    /// ```
    ///
    /// A `uPoleCount` no greater than the degree cap plus one means the fit stayed on a single
    /// Bezier patch. Before #571 that was forced, and `tolerance` was unenforceable as a result.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 3)
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: A parametric BSpline surface, or nil on failure
    public static func plateThrough(
        _ points: [SIMD3<Double>],
        degree: Int = 3,
        tolerance: Double = 0.01
    ) -> Surface? {
        guard points.count >= 3 else { return nil }

        var flatPoints: [Double] = []
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }

        guard
            let h = OCCTSurfacePlateThrough(
                &flatPoints, Int32(points.count),
                Int32(degree), tolerance
            )
        else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface to pass through target positions (NLPlate G0).
    ///
    /// Uses the non-linear plate solver to compute a displacement field on
    /// this surface, then samples and approximates as a BSpline. Each constraint
    /// specifies a (u, v) parameter and a target 3D position.
    ///
    /// - Parameters:
    ///   - constraints: Array of (uv parameter, target 3D position) pairs
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformed(
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // Flat array: (u, v, targetX, targetY, targetZ) per constraint
        var flat: [Double] = []
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
        }

        guard
            let h = OCCTSurfaceNLPlateG0(
                handle, &flat, Int32(constraints.count),
                Int32(maxIterations), tolerance
            )
        else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface with position + tangent constraints (NLPlate G0+G1).
    ///
    /// Each constraint specifies a (u, v) parameter, a target 3D position, and
    /// desired partial derivatives (tangent vectors) in the U and V directions.
    ///
    /// - Parameters:
    ///   - constraints: Array of (uv, target, tangentU, tangentV) tuples
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformedG1(
        constraints: [(
            uv: SIMD2<Double>, target: SIMD3<Double>, tangentU: SIMD3<Double>,
            tangentV: SIMD3<Double>
        )],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // Flat: (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
        var flat: [Double] = []
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
            flat.append(c.tangentU.x)
            flat.append(c.tangentU.y)
            flat.append(c.tangentU.z)
            flat.append(c.tangentV.x)
            flat.append(c.tangentV.y)
            flat.append(c.tangentV.z)
        }

        guard
            let h = OCCTSurfaceNLPlateG1(
                handle, &flat, Int32(constraints.count),
                Int32(maxIterations), tolerance
            )
        else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Batch Evaluation (v0.29.0)

extension Surface {
    /// Evaluate the surface at a UV grid in one call.
    ///
    /// - Parameters:
    ///   - uParameters: Array of U parameter values
    ///   - vParameters: Array of V parameter values
    /// - Returns: A ``SurfaceGrid`` indexed `.at(u:v:)`, or an empty grid if either input is
    ///   empty or the evaluated count doesn't match `uParameters.count * vParameters.count`.
    ///
    /// ```swift
    /// let grid = surface.evaluateGrid(uParameters: [0, 1, 2], vParameters: [0, 1])
    /// let p = grid.at(u: 2, v: 0)
    /// ```
    public func evaluateGrid(uParameters: [Double], vParameters: [Double]) -> SurfaceGrid {
        guard !uParameters.isEmpty, !vParameters.isEmpty else { return .empty }
        let uCount = uParameters.count
        let vCount = vParameters.count
        let total = uCount * vCount
        var outXYZ = [Double](repeating: 0, count: total * 3)
        let n = Int(
            OCCTSurfaceEvaluateGrid(
                handle,
                uParameters, Int32(uCount),
                vParameters, Int32(vCount),
                &outXYZ))
        guard n == total else { return .empty }

        // Bridge buffer is U-major, matching SurfaceGrid's storage, so no transpose. It was
        // V-major until #486 settled every surface grid producer on one layout.
        let points: [SIMD3<Double>] = unpackSIMD3(outXYZ, count: total)
        return SurfaceGrid(uCount: uCount, vCount: vCount, points: points)
    }

    /// Evaluate the surface and its first partial derivatives at a UV grid in one call.
    ///
    /// The D1 counterpart of ``evaluateGrid(uParameters:vParameters:)``, using OCCT's batch
    /// `GeomGridEval_Surface` evaluator rather than one `D1` call per sample.
    ///
    /// - Parameters:
    ///   - uParameters: Array of U parameter values
    ///   - vParameters: Array of V parameter values
    /// - Returns: A ``SurfaceGridD1`` indexed `.at(u:v:)`, or an empty grid if either input is
    ///   empty or the evaluation fails.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// let grid = sphere.evaluateGridD1(uParameters: [0, 1, 2], vParameters: [0, 0.5])
    /// let sample = grid.at(u: 1, v: 0)
    /// let normal = simd_normalize(simd_cross(sample.d1u, sample.d1v))
    /// ```
    public func evaluateGridD1(uParameters: [Double], vParameters: [Double]) -> SurfaceGridD1 {
        guard !uParameters.isEmpty, !vParameters.isEmpty else { return .empty }
        let uCount = uParameters.count
        let vCount = vParameters.count
        let total = uCount * vCount
        var outXYZ = [Double](repeating: 0, count: total * 3)
        var outD1U = [Double](repeating: 0, count: total * 3)
        var outD1V = [Double](repeating: 0, count: total * 3)
        let n = Int(
            OCCTSurfaceEvaluateGridD1(
                handle,
                uParameters, Int32(uCount),
                vParameters, Int32(vCount),
                &outXYZ, &outD1U, &outD1V))
        guard n == total else { return .empty }

        return SurfaceGridD1(
            uCount: uCount, vCount: vCount,
            points: unpackSIMD3(outXYZ, count: total),
            d1u: unpackSIMD3(outD1U, count: total),
            d1v: unpackSIMD3(outD1V, count: total))
    }
}

// MARK: - Surface Intersection & Conversion (v0.30.0)

extension Surface {
    /// Intersect this surface with another surface.
    ///
    /// - Parameters:
    ///   - other: The other surface
    ///   - tolerance: Intersection tolerance
    ///   - maxCurves: Output *capacity* (default 50), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of intersection curves
    public func intersections(with other: Surface, tolerance: Double = 1e-6, maxCurves: Int = 50)
        -> [Curve3D]
    {
        let maxCurves = Sampling.capacity(maxCurves)
        guard maxCurves > 0 else { return [] }
        var handles = [OCCTCurve3DRef?](repeating: nil, count: maxCurves)
        let n = Int(
            OCCTSurfaceIntersect(handle, other.handle, tolerance, &handles, Int32(maxCurves)))
        return (0..<n).compactMap { i in
            guard let h = handles[i] else { return nil }
            return Curve3D(handle: h)
        }
    }

    /// Convert this surface to an analytical surface if possible.
    ///
    /// Recognizes if the surface is actually a plane, cylinder, cone, sphere, or torus within the
    /// given tolerance. A surface that is already analytical converts to an equal, independent
    /// surface rather than being rejected.
    ///
    /// Use ``toAnalyticalWithGap(tolerance:)`` to also get the deviation, or
    /// ``toAnalyticalWithGap(tolerance:uMin:uMax:vMin:vMax:)`` to fit only a sub-patch.
    ///
    /// ```swift
    /// let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
    /// if let analytical = cylinder.toBSpline()?.toAnalytical(tolerance: 1e-4) {
    ///     print(analytical.surfaceKind)   // .cylinder
    /// }
    /// ```
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The analytical surface, or nil if not recognizable
    public func toAnalytical(tolerance: Double = 1e-4) -> Surface? {
        toAnalyticalWithGap(tolerance: tolerance)?.surface
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

/// Filling style for Bezier surface construction.
public enum BezierFillStyle: Int32, Sendable {
    /// Stretch style — minimal surface area
    case stretch = 0
    /// Coons style — bilinear blending
    case coons = 1
    /// Curved style — smooth curved interpolation
    case curved = 2
}

extension Surface {
    /// Create a Bezier surface by filling 4 Bezier boundary curves.
    ///
    /// The four curves must be Bezier curves forming a closed boundary.
    ///
    /// - Parameters:
    ///   - c1: First boundary curve
    ///   - c2: Second boundary curve
    ///   - c3: Third boundary curve
    ///   - c4: Fourth boundary curve
    ///   - style: Filling style
    /// - Returns: Bezier surface, or nil on failure
    public static func bezierFill(
        _ c1: Curve3D, _ c2: Curve3D, _ c3: Curve3D, _ c4: Curve3D,
        style: BezierFillStyle = .stretch
    ) -> Surface? {
        guard
            let h = OCCTSurfaceBezierFill4(
                c1.handle, c2.handle, c3.handle, c4.handle,
                style.rawValue)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a Bezier surface by filling 2 Bezier boundary curves.
    ///
    /// The two curves are used as opposite edges of the surface.
    ///
    /// - Parameters:
    ///   - c1: First boundary curve
    ///   - c2: Second boundary curve
    ///   - style: Filling style
    /// - Returns: Bezier surface, or nil on failure
    public static func bezierFill(
        _ c1: Curve3D, _ c2: Curve3D,
        style: BezierFillStyle = .stretch
    ) -> Surface? {
        guard let h = OCCTSurfaceBezierFill2(c1.handle, c2.handle, style.rawValue) else {
            return nil
        }
        return Surface(handle: h)
    }

    // MARK: - Face from Surface (v0.33.0)

    /// Create a face from this surface using its full parameter domain.
    ///
    /// - Parameter tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(tolerance: Double = 1e-6) -> Shape? {
        let d = domain
        return Shape.face(
            from: self, uRange: d.uMin...d.uMax, vRange: d.vMin...d.vMax, tolerance: tolerance)
    }

    /// Create a face from this surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(
        uRange: ClosedRange<Double>, vRange: ClosedRange<Double>,
        tolerance: Double = 1e-6
    ) -> Shape? {
        return Shape.face(from: self, uRange: uRange, vRange: vRange, tolerance: tolerance)
    }

    /// Create a face trimmed to a **non-rectangular** region of this surface, given by a closed
    /// boundary polygon in **UV space** (≥ 3 points, e.g. `[SIMD2(u,v), …]`).
    ///
    /// Each segment becomes
    /// a 2D edge carrying a pcurve on the surface, so the face footprint follows the polygon —
    /// unlike ``toFace(uRange:vRange:tolerance:)``, which can only make a rectangular UV patch.
    ///
    /// Ideal for reconstructing a fitted analytic surface (cylinder / cone / sphere / B-spline)
    /// trimmed to a region's real boundary rather than over-extending to the UV bounding box.
    ///
    /// - Parameter uvBoundary: Closed polygon of `(u, v)` points (the closing segment is implicit).
    /// - Returns: The trimmed face, or nil on failure.
    public func toFace(uvBoundary: [SIMD2<Double>]) -> Shape? {
        guard uvBoundary.count >= 3 else { return nil }
        var flat = [Double]()
        flat.reserveCapacity(uvBoundary.count * 2)
        for p in uvBoundary {
            flat.append(p.x)
            flat.append(p.y)
        }
        guard
            let h = flat.withUnsafeBufferPointer({ buf in
                OCCTShapeCreateFaceFromSurfaceUVPolygon(
                    handle, buf.baseAddress, Int32(uvBoundary.count))
            })
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Surface-Surface Intersection (v0.35.0)

    /// Compute intersection curves between this surface and another.
    ///
    /// Returns the parametric curves where the two surfaces intersect.
    ///
    /// - Parameters:
    ///   - other: The other surface to intersect with
    ///   - tolerance: Intersection tolerance
    /// - Returns: Array of 3D intersection curves
    public func intersectionCurves(with other: Surface, tolerance: Double = 1e-6) -> [Curve3D] {
        let maxCurves: Int32 = 64
        var curveRefs = [OCCTCurve3DRef?](repeating: nil, count: Int(maxCurves))
        let count = curveRefs.withUnsafeMutableBufferPointer { buf in
            OCCTSurfaceSurfaceIntersect(
                handle, other.handle, tolerance,
                buf.baseAddress, maxCurves)
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = curveRefs[i] else { return nil }
            return Curve3D(handle: ref)
        }
    }
}

// MARK: - Curve-Surface Intersection (v0.35.0)

/// Result of a curve-surface intersection point.
public struct CurveSurfaceIntersection: Sendable {
    /// 3D intersection point.
    public var point: SIMD3<Double>
    /// Surface parameters (u, v) at the intersection.
    public var surfaceUV: SIMD2<Double>
    /// Curve parameter at the intersection.
    public var curveParameter: Double
}

extension Curve3D {
    /// Compute intersection points between this curve and a surface.
    ///
    /// - Parameter surface: The surface to intersect with
    /// - Returns: Array of intersection results with 3D points, surface UV, and curve parameter
    public func intersections(with surface: Surface) -> [CurveSurfaceIntersection] {
        let maxPoints: Int32 = 64
        var points = [OCCTCurveSurfacePoint](
            repeating: OCCTCurveSurfacePoint(), count: Int(maxPoints))
        let count = points.withUnsafeMutableBufferPointer { buf in
            OCCTCurveSurfaceIntersect(handle, surface.handle, buf.baseAddress, maxPoints)
        }
        return (0..<Int(count)).map { i in
            let p = points[i]
            return CurveSurfaceIntersection(
                point: SIMD3(p.x, p.y, p.z),
                surfaceUV: SIMD2(p.u, p.v),
                curveParameter: p.w
            )
        }
    }
}

// MARK: - Surface to Bezier Patches (v0.36.0)

extension Surface {
    // MARK: - Surface Singularity Analysis (v0.37.0)

    /// Count the number of singularities (poles/degenerate regions) on this surface.
    ///
    /// - Parameter tolerance: Precision for singularity detection
    /// - Returns: Number of singularities found (0 = none)
    public func singularityCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTSurfaceSingularityCount(handle, tolerance))
    }

    /// Check if a 3D point lies at a degenerate region of this surface.
    ///
    /// - Parameters:
    ///   - point: The 3D point to check
    ///   - tolerance: Precision for degeneration detection
    /// - Returns: true if the point is at a degenerate region
    public func isDegenerated(at point: SIMD3<Double>, tolerance: Double = 1e-6) -> Bool {
        OCCTSurfaceIsDegenerated(handle, point.x, point.y, point.z, tolerance)
    }

    /// Whether this surface has any singularities at the given tolerance.
    public func hasSingularities(tolerance: Double = 1e-6) -> Bool {
        singularityCount(tolerance: tolerance) > 0
    }

    // MARK: - ShapeAnalysis_Surface extras (#266 follow-up)

    /// Refine a (U,V) for a 3D point by projecting it onto this surface's iso-lines — more robust
    /// near degeneracies than plain ``projectPoint(_:)``.
    ///
    /// Returns the parameters and the 3D gap; a
    /// very large gap means the projection effectively failed.
    public func uvFromIso(_ point: SIMD3<Double>, precision: Double = 1e-6) -> (
        u: Double, v: Double, gap: Double
    )? {
        var u = 0.0
        var v = 0.0
        let gap = OCCTSurfaceUVFromIso(handle, point.x, point.y, point.z, precision, &u, &v)
        guard gap >= 0 else { return nil }
        return (u, v, gap)
    }

    /// Detail of a surface singularity (a degenerate iso-line collapsing to a pole), e.g. the apex
    /// of a cone or the poles of a sphere.
    public struct Singularity: Sendable {
        /// The 3D pole point.
        public let point: SIMD3<Double>
        /// First / last 2D (u,v) points of the degenerate iso-line.
        public let firstUV: SIMD2<Double>
        public let lastUV: SIMD2<Double>
        /// First / last parameter along the iso-line.
        public let firstParameter: Double
        public let lastParameter: Double
        /// True if the degenerate iso-line is a U-iso (else a V-iso).
        public let isUIso: Bool
        /// The precision at which the singularity was detected.
        public let precision: Double
    }

    /// Full detail of singularity `index` (**0-based**, `0..<singularityCount(...)`), or nil if out
    /// of range.
    ///
    /// Unlike ``singularityCount(tolerance:)`` (count only) this returns the pole point,
    /// iso-line 2D endpoints + parameters, and the iso direction.
    public func singularity(_ index: Int, precision: Double = 1e-6) -> Singularity? {
        var pr = precision
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var fu = 0.0
        var fv = 0.0
        var lu = 0.0
        var lv = 0.0
        var fp = 0.0
        var lp = 0.0
        var uiso = false
        guard
            OCCTSurfaceSingularityDetail(
                handle, Int32(index + 1), &pr, &px, &py, &pz,
                &fu, &fv, &lu, &lv, &fp, &lp, &uiso)
        else { return nil }
        return Singularity(
            point: SIMD3(px, py, pz), firstUV: SIMD2(fu, fv), lastUV: SIMD2(lu, lv),
            firstParameter: fp, lastParameter: lp, isUIso: uiso, precision: pr)
    }

    /// Resolve the indeterminate 2D coordinate of a point lying in a singularity (e.g. a cone apex),
    /// taking the well-defined coordinate from a `neighbour` 2D point.
    ///
    /// Returns the resolved (u,v).
    public func projectDegenerated(
        _ point: SIMD3<Double>, neighbour: SIMD2<Double>,
        precision: Double = 1e-6
    ) -> SIMD2<Double>? {
        var ru = 0.0
        var rv = 0.0
        guard
            OCCTSurfaceProjectDegenerated(
                handle, point.x, point.y, point.z, precision,
                neighbour.x, neighbour.y, &ru, &rv)
        else { return nil }
        return SIMD2(ru, rv)
    }

    /// Project a 3D point onto this surface, restricting the parameter search to the given U/V
    /// domain — disambiguates projection on periodic or self-overlapping surfaces.
    ///
    /// Returns the (u,v)
    /// and the 3D gap, or nil on failure.
    public func projectPoint(
        _ point: SIMD3<Double>, uDomain: ClosedRange<Double>,
        vDomain: ClosedRange<Double>, precision: Double = 1e-6
    )
        -> (uv: SIMD2<Double>, gap: Double)?
    {
        var u = 0.0
        var v = 0.0
        let gap = OCCTSurfaceProjectPointUVInDomain(
            handle, point.x, point.y, point.z, precision,
            uDomain.lowerBound, uDomain.upperBound,
            vDomain.lowerBound, vDomain.upperBound, &u, &v)
        guard gap >= 0 else { return nil }
        return (SIMD2(u, v), gap)
    }

    /// Convert this surface to an array of Bezier surface patches.
    ///
    /// Decomposes a B-spline surface into a grid of Bezier patches. The surface
    /// is first converted to B-spline if needed.
    ///
    /// - Returns: Array of Bezier surface patches, or empty if conversion fails
    public func toBezierPatches() -> [Surface] {
        let maxPatches: Int32 = 256
        var patchRefs = [OCCTSurfaceRef?](repeating: nil, count: Int(maxPatches))
        let count = patchRefs.withUnsafeMutableBufferPointer { buf in
            OCCTSurfaceToBezierPatches(handle, buf.baseAddress, maxPatches)
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = patchRefs[i] else { return nil }
            return Surface(handle: ref)
        }
    }

    // MARK: - BSpline Bezier Patch Grid (v0.40.0)

    /// Result of decomposing a BSpline surface into Bezier patches.
    public struct BezierPatchGrid {
        /// Number of patches in U direction.
        public let uCount: Int
        /// Number of patches in V direction.
        public let vCount: Int
        /// Patches in row-major order (U varies faster).
        public let patches: [Surface]
    }

    /// Decompose this BSpline surface into a grid of Bezier patches.
    ///
    /// Returns the patches along with their U/V grid dimensions.
    /// Only works on BSpline surfaces.
    /// - Returns: Bezier patch grid, or nil if not a BSpline surface
    public func toBezierPatchGrid() -> BezierPatchGrid? {
        let maxPatches: Int32 = 256
        var patchRefs = [OCCTSurfaceRef?](repeating: nil, count: Int(maxPatches))
        var nbU: Int32 = 0
        var nbV: Int32 = 0
        let total = patchRefs.withUnsafeMutableBufferPointer { buf in
            OCCTSurfaceBSplineToBezierPatches(handle, buf.baseAddress, maxPatches, &nbU, &nbV)
        }
        guard total > 0 else { return nil }
        let patches = (0..<min(Int(total), Int(maxPatches))).compactMap { i -> Surface? in
            guard let ref = patchRefs[i] else { return nil }
            return Surface(handle: ref)
        }
        return BezierPatchGrid(uCount: Int(nbU), vCount: Int(nbV), patches: patches)
    }

    // MARK: - v0.43.0: BSpline Fill from Boundary Curves

    /// Filling style for BSpline surface construction from boundary curves.
    public enum FillStyle: Int32, Sendable {
        /// Flattest result — minimal curvature between boundaries
        case stretch = 0
        /// Coons-style blending — moderate curvature
        case coons = 1
        /// Most curved result — maximum curvature
        case curved = 2
    }

    /// Create a BSpline surface from 2 boundary curves.
    ///
    /// Uses GeomFill_BSplineCurves to construct a surface spanning between two
    /// BSpline curves. The curves must be BSpline (created via `Curve3D.bspline` or
    /// `Curve3D.interpolate`).
    ///
    /// - Parameters:
    ///   - curve1: First boundary curve
    ///   - curve2: Second boundary curve
    ///   - style: Filling style (default: .coons)
    /// - Returns: BSpline surface, or nil if curves are not BSpline or fill fails
    public static func bsplineFill(curve1: Curve3D, curve2: Curve3D, style: FillStyle = .coons)
        -> Surface?
    {
        guard let ref = OCCTSurfaceFillBSpline2Curves(curve1.handle, curve2.handle, style.rawValue)
        else {
            return nil
        }
        return Surface(handle: ref)
    }

    /// Create a BSpline surface from 4 boundary curves.
    ///
    /// Uses GeomFill_BSplineCurves to construct a surface bounded by four BSpline curves
    /// forming a closed boundary. The curves must be connected end-to-end in order.
    ///
    /// - Parameters:
    ///   - curves: Four boundary curves in order (bottom, right, top, left)
    ///   - style: Filling style (default: .coons)
    /// - Returns: BSpline surface, or nil on failure
    public static func bsplineFill(
        curves: (Curve3D, Curve3D, Curve3D, Curve3D), style: FillStyle = .coons
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceFillBSpline4Curves(
                curves.0.handle, curves.1.handle, curves.2.handle, curves.3.handle,
                style.rawValue
            )
        else {
            return nil
        }
        return Surface(handle: ref)
    }

    // MARK: - Surface Extrema

    /// Result of surface-to-surface extrema computation.
    public struct SurfaceExtremaResult {
        /// Minimum distance between the surfaces.
        public let distance: Double
        /// Nearest point on the first surface.
        public let point1: SIMD3<Double>
        /// Nearest point on the second surface.
        public let point2: SIMD3<Double>
        /// UV parameters on the first surface.
        public let uv1: SIMD2<Double>
        /// UV parameters on the second surface.
        public let uv2: SIMD2<Double>
    }

    /// Compute the minimum distance between this surface and another.
    ///
    /// Uses GeomAPI_ExtremaSurfaceSurface to find the closest pair of points
    /// between two surfaces within the given UV bounds.
    ///
    /// - Parameters:
    ///   - other: The other surface
    ///   - uvBounds1: UV bounds on this surface (uMin, uMax, vMin, vMax). Uses full surface bounds if nil.
    ///   - uvBounds2: UV bounds on the other surface. Uses full surface bounds if nil.
    /// - Returns: The extrema result, or nil if computation fails
    public func extrema(
        to other: Surface,
        uvBounds1: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil,
        uvBounds2: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil
    ) -> SurfaceExtremaResult? {
        let b1 = uvBounds1 ?? (0, 1, 0, 1)
        let b2 = uvBounds2 ?? (0, 1, 0, 1)
        var result = OCCTSurfaceExtremaResult()
        let count = OCCTSurfaceExtrema(
            handle, other.handle,
            b1.uMin, b1.uMax, b1.vMin, b1.vMax,
            b2.uMin, b2.uMax, b2.vMin, b2.vMax,
            &result
        )
        guard count > 0 else { return nil }
        return SurfaceExtremaResult(
            distance: result.distance,
            point1: SIMD3(result.p1X, result.p1Y, result.p1Z),
            point2: SIMD3(result.p2X, result.p2Y, result.p2Z),
            uv1: SIMD2(result.u1, result.v1),
            uv2: SIMD2(result.u2, result.v2)
        )
    }

    // MARK: - ShapeAnalysis_Surface expansion (v0.49.0)

    /// Result of projecting a 3D point to surface UV parameters.
    public struct UVProjection: Sendable {
        /// UV parameters on the surface.
        public let uv: SIMD2<Double>
        /// Gap: distance between the 3D point and the surface at the found UV.
        public let gap: Double
    }

    /// Project a 3D point onto this surface to find UV parameters.
    ///
    /// Uses ShapeAnalysis_Surface::ValueOfUV.
    ///
    /// - Parameters:
    ///   - point: 3D point to project
    ///   - precision: Projection precision (default: 1e-6)
    /// - Returns: UV coordinates and gap distance
    public func valueOfUV(point: SIMD3<Double>, precision: Double = 1e-6) -> UVProjection {
        let result = OCCTSurfaceValueOfUV(handle, point.x, point.y, point.z, precision)
        return UVProjection(uv: SIMD2(result.u, result.v), gap: result.gap)
    }

    /// Project a 3D point onto this surface using a previous UV as starting hint.
    ///
    /// More efficient than `valueOfUV` for iterative projections along a path.
    /// Uses ShapeAnalysis_Surface::NextValueOfUV.
    ///
    /// - Parameters:
    ///   - previousUV: Previous UV result to use as hint
    ///   - point: 3D point to project
    ///   - precision: Projection precision (default: 1e-6)
    /// - Returns: UV coordinates and gap distance
    public func nextValueOfUV(
        previousUV: SIMD2<Double>, point: SIMD3<Double>, precision: Double = 1e-6
    ) -> UVProjection {
        let result = OCCTSurfaceNextValueOfUV(
            handle, previousUV.x, previousUV.y,
            point.x, point.y, point.z, precision)
        return UVProjection(uv: SIMD2(result.u, result.v), gap: result.gap)
    }

    // MARK: - v0.50.0: Constrained geometry construction, knot splitting, conversions

    /// Create a conical surface from axis placement, semi-angle, and base radius.
    ///
    /// - Parameters:
    ///   - origin: Origin of the cone axis
    ///   - direction: Direction of the cone axis
    ///   - semiAngle: Half-angle of the cone in radians (must be in (0, PI/2))
    ///   - radius: Base radius at the origin
    /// - Returns: Conical surface, or nil on failure
    public static func conicalSurface(
        origin: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        semiAngle: Double,
        radius: Double
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceConicalFromAxis(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                semiAngle, radius)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a conical surface passing through two points with specified radii.
    ///
    /// - Parameters:
    ///   - point1: First axis point (with radius r1)
    ///   - point2: Second axis point (with radius r2)
    ///   - r1: Radius at point1
    ///   - r2: Radius at point2
    /// - Returns: Conical surface, or nil on failure
    public static func conicalSurface(
        point1: SIMD3<Double>,
        point2: SIMD3<Double>,
        r1: Double,
        r2: Double
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceConicalFromPointsRadii(
                point1.x, point1.y, point1.z,
                point2.x, point2.y, point2.z,
                r1, r2)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a cylindrical surface from axis and radius.
    ///
    /// - Parameters:
    ///   - origin: Origin of the cylinder axis
    ///   - direction: Direction of the cylinder axis
    ///   - radius: Radius of the cylinder
    /// - Returns: Cylindrical surface, or nil on failure
    public static func cylindricalSurface(
        origin: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceCylindricalFromAxis(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a cylindrical surface through three points.
    ///
    /// The axis passes through point1 and point2. The radius is the distance
    /// from point3 to the axis.
    ///
    /// - Parameters:
    ///   - point1: First axis point
    ///   - point2: Second axis point
    ///   - point3: Point defining the radius
    /// - Returns: Cylindrical surface, or nil on failure
    public static func cylindricalSurface(
        point1: SIMD3<Double>,
        point2: SIMD3<Double>,
        point3: SIMD3<Double>
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceCylindricalFromPoints(
                point1.x, point1.y, point1.z,
                point2.x, point2.y, point2.z,
                point3.x, point3.y, point3.z)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a plane surface through three points, via `GC_MakePlane`.
    ///
    /// `planeFrom3Points(p1:p2:p3:)` is a labeled-argument spelling of the same construction
    /// (`gce_MakePln` instead of `GC_MakePlane`) and delegates here — ground-truthed for #421,
    /// the two OCCT algorithm classes agree on every case tested (well-separated, collinear, and
    /// coincident points), so there is only one implementation.
    ///
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    ///   - point3: Third point
    /// - Returns: Plane surface, or nil if points are collinear (including coincident)
    ///
    /// ```swift
    /// let base = Surface.planeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0))
    /// #expect(base != nil)
    ///
    /// // Collinear points fail construction:
    /// let degenerate = Surface.planeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 0, 0))
    /// #expect(degenerate == nil)
    /// ```
    public static func planeFromPoints(
        _ point1: SIMD3<Double>,
        _ point2: SIMD3<Double>,
        _ point3: SIMD3<Double>
    ) -> Surface? {
        guard
            let ref = OCCTSurfacePlaneFromPoints(
                point1.x, point1.y, point1.z,
                point2.x, point2.y, point2.z,
                point3.x, point3.y, point3.z)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a plane surface from a point and normal direction, via `GC_MakePlane`.
    ///
    /// `plane(origin:normal:)` is an unlabeled-positional spelling of the same construction and
    /// delegates here.
    ///
    /// - Parameters:
    ///   - point: A point on the plane
    ///   - normal: Normal direction of the plane
    /// - Returns: Plane surface, or nil if `normal` has zero (or near-zero) length
    ///
    /// ```swift
    /// let sheet = Surface.planeFromPointNormal(point: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
    /// #expect(sheet != nil)
    /// ```
    public static func planeFromPointNormal(
        point: SIMD3<Double>,
        normal: SIMD3<Double>
    ) -> Surface? {
        guard
            let ref = OCCTSurfacePlaneFromPointNormal(
                point.x, point.y, point.z,
                normal.x, normal.y, normal.z)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a trimmed conical surface between two endpoints with specified radii.
    ///
    /// - Parameters:
    ///   - point1: Base center point (with radius r1)
    ///   - point2: Top center point (with radius r2)
    ///   - r1: Radius at point1
    ///   - r2: Radius at point2
    /// - Returns: Bounded trimmed conical surface, or nil on failure
    public static func trimmedCone(
        point1: SIMD3<Double>,
        point2: SIMD3<Double>,
        r1: Double,
        r2: Double
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceTrimmedCone(
                point1.x, point1.y, point1.z,
                point2.x, point2.y, point2.z,
                r1, r2)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create a trimmed cylindrical surface from axis, radius, and height.
    ///
    /// - Parameters:
    ///   - origin: Base center of the cylinder
    ///   - direction: Axis direction
    ///   - radius: Cylinder radius
    ///   - height: Height (can be negative for downward)
    /// - Returns: Bounded trimmed cylindrical surface, or nil on failure
    public static func trimmedCylinder(
        origin: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        radius: Double,
        height: Double
    ) -> Surface? {
        guard
            let ref = OCCTSurfaceTrimmedCylinder(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                radius, height)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Result of BSpline surface knot splitting analysis.
    ///
    /// `uSplitParams`/`vSplitParams` are the actual parameter values (from the surface's
    /// own U/V knot vectors) at which those splits occur -- the 2D, per-direction analogue
    /// of `Curve3D.continuityBreaks`'s 1D split parameters. Added in #403: the counts alone
    /// made this strictly weaker than its curve/law siblings even though the underlying
    /// analyzer (`GeomConvert_BSplineSurfaceKnotSplitting`) always computed the locations
    /// too, via `USplitValue`/`VSplitValue`, this just wasn't surfaced.
    public struct KnotSplitResult {
        /// Number of U split indices needed for the requested continuity.
        public let uSplitCount: Int
        /// Number of V split indices needed for the requested continuity.
        public let vSplitCount: Int
        /// U parameter values (ascending, bounded by the surface's own U range) at each split.
        public let uSplitParams: [Double]
        /// V parameter values (ascending, bounded by the surface's own V range) at each split.
        public let vSplitParams: [Double]
        /// 1-based indices into the surface's own U knot table, one per split:
        /// `uSplitParams[i] == bsplineUKnot(index: uSplitIndices[i])`.
        ///
        /// The analyzer reports indices and this call converts them, so before #562 the raw form
        /// was reachable only through a separate `bsplineKnotSplitValues(continuity:)`, which
        /// constructed the analyzer three more times to get it.
        public let uSplitIndices: [Int]
        /// 1-based indices into the surface's own V knot table, one per split:
        /// `vSplitParams[i] == bsplineVKnot(index: vSplitIndices[i])`.
        public let vSplitIndices: [Int]
    }

    /// Analyze where a BSpline surface would need to be split to achieve
    /// a given continuity level.
    ///
    /// A surface's discontinuities are inherently 2D -- U and V are independent parametric
    /// directions, each with its own knot vector -- so this reports counts *and* parameter
    /// locations per direction, unlike `Curve3D.continuityBreaks` (one 1D parameter list).
    ///
    /// The result is a set of *split* parameters, not a set of defects: each direction's own
    /// first and last knots are always included, so a direction that never drops below the
    /// requested continuity reports exactly those two rather than nothing.
    ///
    /// ```swift
    /// // Where does the surface actually kink?
    /// let kinks = bsplineSurface.knotSplitting()
    ///
    /// // A bicubic surface with simple interior knots is already C2 at every interior knot,
    /// // so .c3 is the order that reports them (.c0, .c1 and .c2 return only the bounds).
    /// let all = bsplineSurface.knotSplitting(uContinuity: .c3, vContinuity: .c3)
    /// // all.uSplitParams / all.vSplitParams are real U/V parameters, usable to split the
    /// // surface into same-continuity patches.
    ///
    /// // The raw knot-table indices are here too, and agree with the parameters by construction.
    /// let sameThing = all.uSplitIndices.map { bsplineSurface.bsplineUKnot(index: $0) }
    /// // sameThing == all.uSplitParams
    /// ```
    ///
    /// - Parameters:
    ///   - uContinuity: Minimum continuity to require of each U patch. This is a derivative
    ///     order, and `GeomConvert_BSplineSurfaceKnotSplitting` splits a knot only when
    ///     `U degree - multiplicity < uContinuity`, so the meaningful range is 0...U degree and
    ///     it saturates there. On a degree-4-or-higher surface ``ParametricContinuity/c3`` is
    ///     the strictest question this vocabulary can ask; `toBezierPatches()` is the dedicated
    ///     API for the every-knot split at the far end of that ladder (#480).
    ///   - vContinuity: Minimum continuity to require of each V patch, against the V degree
    ///     and V knots
    /// - Returns: Split counts, the actual U/V parameter values, and the knot-table indices those
    ///   parameters were read from, or all-empty/zero for a non-BSpline surface
    public func knotSplitting(
        uContinuity: ParametricContinuity = .c1,
        vContinuity: ParametricContinuity = .c1
    ) -> KnotSplitResult {
        // Same retry-on-truncation pattern as Curve3D.continuityBreaks: the bridge always
        // reports the true split counts even when it writes fewer, so one retry sized to
        // those counts is always enough.
        typealias Read = (OCCTSurfaceKnotSplitResult, [Double], [Double], [Int32], [Int32])
        func read(uCapacity: Int32, vCapacity: Int32) -> Read {
            var uParams = [Double](repeating: 0, count: Int(uCapacity))
            var vParams = [Double](repeating: 0, count: Int(vCapacity))
            var uIndices = [Int32](repeating: 0, count: Int(uCapacity))
            var vIndices = [Int32](repeating: 0, count: Int(vCapacity))
            let result = OCCTSurfaceKnotSplitting(
                handle, uContinuity.rawValue, vContinuity.rawValue,
                &uParams, &uIndices, uCapacity,
                &vParams, &vIndices, vCapacity)
            return (result, uParams, vParams, uIndices, vIndices)
        }

        var (result, uParams, vParams, uIndices, vIndices) = read(uCapacity: 64, vCapacity: 64)
        if result.nbUSplits > 64 || result.nbVSplits > 64 {
            (result, uParams, vParams, uIndices, vIndices) = read(
                uCapacity: max(result.nbUSplits, 1),
                vCapacity: max(result.nbVSplits, 1))
        }
        return KnotSplitResult(
            uSplitCount: Int(result.nbUSplits),
            vSplitCount: Int(result.nbVSplits),
            uSplitParams: Array(uParams.prefix(Int(result.nbUSplits))),
            vSplitParams: Array(vParams.prefix(Int(result.nbVSplits))),
            uSplitIndices: uIndices.prefix(Int(result.nbUSplits)).map(Int.init),
            vSplitIndices: vIndices.prefix(Int(result.nbVSplits)).map(Int.init)
        )
    }

    /// Join an array of Bezier surface patches into a single BSpline surface.
    ///
    /// The patches must form a rectangular grid where adjacent patches share
    /// boundary curves.
    ///
    /// - Parameters:
    ///   - patches: 2D array of Bezier surfaces (row-major order)
    ///   - rows: Number of rows in the patch grid
    ///   - cols: Number of columns in the patch grid
    /// - Returns: Combined BSpline surface, or nil on failure
    public static func joinBezierPatches(_ patches: [Surface], rows: Int, cols: Int) -> Surface? {
        guard patches.count == rows * cols, rows > 0, cols > 0 else { return nil }
        var handles: [OCCTSurfaceRef?] = patches.map { $0.handle }
        guard let ref = OCCTSurfaceJoinBezierPatches(&handles, Int32(rows), Int32(cols)) else {
            return nil
        }
        return Surface(handle: ref)
    }

    /// Result of trying to recognize an analytical surface.
    public struct AnalyticalConversion {
        /// Recognized analytical surface (plane, cylinder, cone, sphere, torus).
        public let surface: Surface
        /// Maximum deviation from the original surface.
        public let gap: Double
    }

    /// Try to recognize an analytical surface from a BSpline/Bezier surface.
    ///
    /// Attempts to identify if this surface is actually a plane, cylinder, cone,
    /// sphere, or torus within the given tolerance.
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: Recognized surface with gap, or nil if not recognizable
    public func convertToAnalytical(tolerance: Double = 1e-4) -> AnalyticalConversion? {
        let result = OCCTSurfaceConvertToAnalytical(handle, tolerance)
        guard let surfRef = result.surface else { return nil }
        return AnalyticalConversion(surface: Surface(handle: surfRef), gap: result.gap)
    }

    /// Result of surface continuity splitting analysis.
    public struct ContinuitySplitResult {
        /// Whether the surface was actually split.
        public let wasSplit: Bool
        /// Whether the surface already meets the criterion (no split needed).
        public let alreadyMeetsCriterion: Bool
        /// Number of U split values.
        public let uSplitCount: Int
        /// Number of V split values.
        public let vSplitCount: Int
    }

    /// Analyze and split a BSpline surface at continuity breaks.
    ///
    /// - Parameters:
    ///   - criterion: A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3; anything
    ///     above asks for CN, i.e. split at every break)
    ///   - tolerance: Tolerance for continuity checking
    /// - Returns: Split analysis result
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6)
        -> ContinuitySplitResult
    {
        let result = OCCTSurfaceSplitByContinuity(handle, Int32(criterion), tolerance)
        return ContinuitySplitResult(
            wasSplit: result.wasSplit,
            alreadyMeetsCriterion: result.isOk,
            uSplitCount: Int(result.nUSplits),
            vSplitCount: Int(result.nVSplits))
    }

    // MARK: - LocalAnalysis

    /// Result of surface continuity analysis at a junction point.
    ///
    /// The curve-side twin of this type is ``Curve3D/ContinuityAnalysis``; both wrap a
    /// `LocalAnalysis_*Continuity` and carry the same measured-set contract.
    public struct ContinuityAnalysis: Sendable {
        /// The order the junction was actually analysed at: the requested ``ContinuityClass``
        /// after saturation at ``ContinuityClass/c2``.
        ///
        /// This is the request, not a finding —
        /// `LocalAnalysis_SurfaceContinuity::ContinuityStatus()` returns the order it was
        /// constructed with verbatim. The findings are ``measured`` and ``holds(_:)``.
        public let order: ContinuityClass
        /// The continuity classes this ``order`` actually measured.
        ///
        /// Each order computes only its own branch — `.c0` measures C0; `.g1` measures C0 and G1;
        /// `.c1` measures C0 and C1; `.g2` measures C0, G1 and G2; `.c2` measures C0, C1 and C2.
        /// No order measures all five, not even the `.c2` default, which never looks at G1 or G2.
        public let measured: Set<ContinuityClass>
        /// Distance between surface points at junction.
        public let c0Value: Double
        /// Angle between normals (radians), or -1 if G1 was not measured or does not hold.
        public let g1Angle: Double
        /// Angle between U-derivatives, or -1.
        public let c1UAngle: Double
        /// Angle between V-derivatives, or -1.
        public let c1VAngle: Double
        /// Bitmask of the classes that hold: bit0=C0, bit1=G1, bit2=C1, bit3=G2, bit4=C2.
        ///
        /// Only ever sets bits for classes in ``measured``, so a clear bit means "does not hold
        /// *or* was not measured". Prefer ``holds(_:)``, which separates the two.
        public let flags: Int

        /// Whether `continuity` holds at the junction, or `nil` if this ``order`` never measured
        /// it.
        ///
        /// ```swift
        /// let a = plane.continuityWith(cylinder, u1: 0, v1: 0, u2: 0, v2: 0, order: .g2)!
        /// a.holds(.g2)   // measured — .g2 computes C0, G1 and G2
        /// a.holds(.c2)   // nil — .g2 never computes C2
        /// ```
        ///
        /// - Note: This asks *exact-class membership* — "did this analysis report this one
        ///   class?" — not a floor. It never infers one class from another, so a `true` for
        ///   ``ContinuityClass/g2`` implies nothing about ``ContinuityClass/c1``. To test a
        ///   *measured* class against a continuity floor instead, use
        ///   ``ContinuityClass/satisfies(_:)``; to rank two measured classes, compare them with
        ///   `<`/`>=`. Three different questions (#623).
        public func holds(_ continuity: ContinuityClass) -> Bool? {
            guard measured.contains(continuity) else { return nil }
            return flags & continuity.analysisFlagBit != 0
        }

        /// Whether the junction is positionally continuous (C0).
        ///
        /// Always measured.
        public var isC0: Bool? { holds(.c0) }
        /// Whether the junction is geometrically tangent-continuous (G1), or nil if ``order``
        /// did not measure G1 (only `.g1` and `.g2` do).
        public var isG1: Bool? { holds(.g1) }
        /// Whether the junction is parametrically tangent-continuous (C1), or nil if ``order``
        /// did not measure C1 (only `.c1` and `.c2` do).
        public var isC1: Bool? { holds(.c1) }
        /// Whether the junction is geometrically curvature-continuous (G2), or nil if ``order``
        /// was not `.g2`.
        public var isG2: Bool? { holds(.g2) }
        /// Whether the junction is parametrically curvature-continuous (C2), or nil if ``order``
        /// was not `.c2`.
        public var isC2: Bool? { holds(.c2) }

    }

    /// Analyze continuity between this surface at (u1, v1) and another surface at (u2, v2).
    ///
    /// ```swift
    /// // Do these two patches meet tangentially? Ask for G1 — the .c2 default never measures it.
    /// let a = patchA.continuityWith(patchB, u1: 1, v1: 0.5, u2: 0, v2: 0.5, order: .g1)
    /// if a?.holds(.g1) == true { print("tangent, normals differ by \(a!.g1Angle) rad") }
    /// ```
    ///
    /// - Parameters:
    ///   - other: Second surface
    ///   - u1: U parameter on this surface
    ///   - v1: V parameter on this surface
    ///   - u2: U parameter on second surface
    ///   - v2: V parameter on second surface
    ///   - order: Which continuity class to measure. This selects the analysis, not just a
    ///     ceiling: `LocalAnalysis_SurfaceContinuity` computes one branch of a switch, so the
    ///     classes outside it are never measured and ``ContinuityAnalysis/holds(_:)`` reports
    ///     `nil` for them. `.c2` is the strictest question the class can answer, so `.c3` and
    ///     `.cN` saturate to it, which ``ContinuityAnalysis/order`` reports back.
    /// - Returns: Continuity analysis result, or nil on failure
    public func continuityWith(
        _ other: Surface, u1: Double, v1: Double, u2: Double, v2: Double,
        order: ContinuityClass = .c2
    ) -> ContinuityAnalysis? {
        continuityAnalysis(with: other, u1: u1, v1: v1, u2: u2, v2: v2, rawOrder: order.rawValue)
    }

    private func continuityAnalysis(
        with other: Surface, u1: Double, v1: Double,
        u2: Double, v2: Double, rawOrder: Int32
    ) -> ContinuityAnalysis? {
        var outEffectiveOrder: Int32 = 0
        var outC0: Double = 0
        var outG1: Double = 0
        var outC1U: Double = 0
        var outC1V: Double = 0
        let ok = OCCTLocalAnalysisSurfaceContinuity(
            handle, u1, v1, other.handle, u2, v2, rawOrder,
            &outEffectiveOrder, &outC0, &outG1, &outC1U, &outC1V)
        guard ok else { return nil }
        var outMeasured: Int32 = 0
        let flags = Int(
            OCCTLocalAnalysisSurfaceContinuityFlags(
                handle, u1, v1, other.handle, u2, v2, rawOrder, &outMeasured))
        return ContinuityAnalysis(
            order: ContinuityClass(rawValue: outEffectiveOrder) ?? .c2,
            measured: ContinuityClass.set(fromAnalysisMask: outMeasured),
            c0Value: outC0, g1Angle: outG1,
            c1UAngle: outC1U, c1VAngle: outC1V, flags: flags)
    }

    // MARK: - GeomFill_NSections (v0.68.0)

    /// Create a BSpline surface by lofting through N section curves.
    ///
    /// - Parameters:
    ///   - curves: Array of 3D curves defining cross-sections
    ///   - params: Parameter values for each section (typically 0..1)
    /// - Returns: BSpline surface, or nil on failure
    public static func nSections(curves: [Curve3D], params: [Double]) -> Surface? {
        guard curves.count == params.count, curves.count >= 2 else { return nil }
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        return handles.withUnsafeBufferPointer { hBuf in
            params.withUnsafeBufferPointer { pBuf in
                guard
                    let h = OCCTGeomFillNSections(
                        hBuf.baseAddress!, pBuf.baseAddress!, Int32(curves.count))
                else { return nil as Surface? }
                return Surface(handle: h)
            }
        }
    }

    /// Query section info from N-sections surface creation.
    public static func nSectionsInfo(curves: [Curve3D], params: [Double]) -> (
        poleCount: Int, knotCount: Int, degree: Int
    )? {
        guard curves.count == params.count, curves.count >= 2 else { return nil }
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        var nbPoles: Int32 = 0
        var nbKnots: Int32 = 0
        var deg: Int32 = 0
        handles.withUnsafeBufferPointer { hBuf in
            params.withUnsafeBufferPointer { pBuf in
                OCCTGeomFillNSectionsInfo(
                    hBuf.baseAddress!, pBuf.baseAddress!, Int32(curves.count),
                    &nbPoles, &nbKnots, &deg)
            }
        }
        if nbPoles == 0 { return nil }
        return (Int(nbPoles), Int(nbKnots), Int(deg))
    }
}

// MARK: - NLPlate G2/G3, IncrementalSolve, GeomFill_Generator (v0.69.0)

extension Surface {

    /// Deform this surface with position + tangent + curvature constraints (NLPlate G0+G2).
    ///
    /// Each constraint specifies a (u,v) parameter, a target 3D position,
    /// tangent vectors (dU, dV), and second derivatives (dUU, dUV, dVV).
    ///
    /// - Parameters:
    ///   - constraints: Array of constraint tuples
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformedG2(
        constraints: [(
            uv: SIMD2<Double>, target: SIMD3<Double>,
            tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
            curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>
        )],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // 20 doubles per constraint
        var flat: [Double] = []
        flat.reserveCapacity(constraints.count * 20)
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
            flat.append(c.tangentU.x)
            flat.append(c.tangentU.y)
            flat.append(c.tangentU.z)
            flat.append(c.tangentV.x)
            flat.append(c.tangentV.y)
            flat.append(c.tangentV.z)
            flat.append(c.curvatureUU.x)
            flat.append(c.curvatureUU.y)
            flat.append(c.curvatureUU.z)
            flat.append(c.curvatureUV.x)
            flat.append(c.curvatureUV.y)
            flat.append(c.curvatureUV.z)
            flat.append(c.curvatureVV.x)
            flat.append(c.curvatureVV.y)
            flat.append(c.curvatureVV.z)
        }

        guard
            let h = OCCTSurfaceNLPlateG2(
                handle, &flat, Int32(constraints.count),
                Int32(maxIterations), tolerance
            )
        else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface with G0+G1+G2+G3 constraints (position + tangent + curvature + 3rd order).
    ///
    /// Each constraint has 32 doubles: uv(2) + target(3) + d1u(3) + d1v(3) +
    /// d2uu(3) + d2uv(3) + d2vv(3) + d3uuu(3) + d3uuv(3) + d3uvv(3) + d3vvv(3).
    ///
    /// - Parameters:
    ///   - constraints: Array of constraint tuples
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformedG3(
        constraints: [(
            uv: SIMD2<Double>, target: SIMD3<Double>,
            tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
            curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>,
            d3UUU: SIMD3<Double>, d3UUV: SIMD3<Double>, d3UVV: SIMD3<Double>, d3VVV: SIMD3<Double>
        )],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // 32 doubles per constraint
        var flat: [Double] = []
        flat.reserveCapacity(constraints.count * 32)
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
            flat.append(c.tangentU.x)
            flat.append(c.tangentU.y)
            flat.append(c.tangentU.z)
            flat.append(c.tangentV.x)
            flat.append(c.tangentV.y)
            flat.append(c.tangentV.z)
            flat.append(c.curvatureUU.x)
            flat.append(c.curvatureUU.y)
            flat.append(c.curvatureUU.z)
            flat.append(c.curvatureUV.x)
            flat.append(c.curvatureUV.y)
            flat.append(c.curvatureUV.z)
            flat.append(c.curvatureVV.x)
            flat.append(c.curvatureVV.y)
            flat.append(c.curvatureVV.z)
            flat.append(c.d3UUU.x)
            flat.append(c.d3UUU.y)
            flat.append(c.d3UUU.z)
            flat.append(c.d3UUV.x)
            flat.append(c.d3UUV.y)
            flat.append(c.d3UUV.z)
            flat.append(c.d3UVV.x)
            flat.append(c.d3UVV.y)
            flat.append(c.d3UVV.z)
            flat.append(c.d3VVV.x)
            flat.append(c.d3VVV.y)
            flat.append(c.d3VVV.z)
        }

        guard
            let h = OCCTSurfaceNLPlateG3(
                handle, &flat, Int32(constraints.count),
                Int32(maxIterations), tolerance
            )
        else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface with incremental G0 constraints (alternative solver strategy).
    ///
    /// Uses NLPlate IncrementalSolve which progressively adds constraints for
    /// better convergence on challenging constraint sets.
    ///
    /// - Parameters:
    ///   - constraints: Array of (uv parameter, target 3D position) pairs
    ///   - maxOrder: Maximum polynomial order (default 2)
    ///   - initConstraintOrder: Initial constraint order (default 1)
    ///   - nbIncrements: Number of increments (default 4)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformedIncremental(
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
        maxOrder: Int = 2,
        initConstraintOrder: Int = 1,
        nbIncrements: Int = 4
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        var flat: [Double] = []
        flat.reserveCapacity(constraints.count * 5)
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
        }

        guard
            let h = OCCTSurfaceNLPlateIncrementalG0(
                handle, &flat, Int32(constraints.count),
                Int32(maxOrder), Int32(initConstraintOrder), Int32(nbIncrements)
            )
        else { return nil }
        return Surface(handle: h)
    }

    /// Evaluate derivative of NLPlate solution at a UV point.
    ///
    /// Solves the NLPlate problem with G0 constraints and returns the derivative at (u,v).
    ///
    /// - Parameters:
    ///   - constraints: Array of G0 constraint (uv, target) pairs
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - iu: U derivative order
    ///   - iv: V derivative order
    /// - Returns: Derivative vector, or nil on failure
    public func nlPlateDerivative(
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
        u: Double, v: Double,
        iu: Int = 1, iv: Int = 0
    ) -> SIMD3<Double>? {
        guard !constraints.isEmpty else { return nil }

        var flat: [Double] = []
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
        }

        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        let ok = OCCTSurfaceNLPlateEvaluateDerivative(
            handle, &flat, Int32(constraints.count),
            u, v, Int32(iu), Int32(iv), &x, &y, &z
        )
        guard ok else { return nil }
        return SIMD3(x, y, z)
    }

    /// Generate a ruled/lofted surface from a sequence of section curves.
    ///
    /// Uses GeomFill_Generator which creates a surface with linear interpolation
    /// in the V direction between the given curves.
    ///
    /// - Parameters:
    ///   - curves: Array of section curves (at least 2)
    ///   - tolerance: Parametric tolerance (default 1e-6)
    /// - Returns: Generated surface, or nil on failure
    public static func generatedFromSections(
        curves: [Curve3D],
        tolerance: Double = 1e-6
    ) -> Surface? {
        guard curves.count >= 2 else { return nil }
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        return handles.withUnsafeBufferPointer { buf in
            guard let h = OCCTGeomFillGenerator(buf.baseAddress!, Int32(curves.count), tolerance)
            else { return nil as Surface? }
            return Surface(handle: h)
        }
    }

    /// Evaluate a degenerated boundary (single point repeated over parameter range).
    ///
    /// Returns the same point regardless of parameter, representing a boundary
    /// that has collapsed to a point (e.g., the apex of a cone).
    ///
    /// - Parameters:
    ///   - point: The degenerate point
    ///   - first: Start of parameter range
    ///   - last: End of parameter range
    ///   - parameter: Parameter to evaluate at
    /// - Returns: The point coordinates
    public static func degeneratedBoundaryValue(
        point: SIMD3<Double>,
        first: Double = 0, last: Double = 1,
        parameter: Double
    ) -> SIMD3<Double> {
        let result = OCCTGeomFillDegeneratedBoundValue(
            point.x, point.y, point.z, first, last, parameter)
        return SIMD3(result.x, result.y, result.z)
    }

    /// Check if a boundary is degenerated (always true for degenerated boundaries).
    public static func isDegeneratedBoundary(
        point: SIMD3<Double>,
        first: Double = 0, last: Double = 1
    ) -> Bool {
        OCCTGeomFillDegeneratedBoundIsDegenerated(
            point.x, point.y, point.z, first, last)
    }

    /// Evaluate a boundary-with-surface: a 2D curve on a surface.
    ///
    /// Returns the 3D point and surface normal at the given parameter.
    ///
    /// - Parameters:
    ///   - curve2d: The 2D curve on the surface
    ///   - first: Start parameter of the 2D curve
    ///   - last: End parameter of the 2D curve
    ///   - parameter: Parameter to evaluate at
    /// - Returns: Tuple of (point, normal), or nil on failure
    public func boundaryWithSurfaceEvaluate(
        curve2d: Curve2D,
        first: Double, last: Double,
        parameter: Double
    ) -> (point: SIMD3<Double>, normal: SIMD3<Double>)? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        let ok = OCCTGeomFillBoundWithSurfEvaluate(
            handle, curve2d.handle,
            first, last, parameter,
            &x, &y, &z, &nx, &ny, &nz)
        guard ok else { return nil }
        return (SIMD3(x, y, z), SIMD3(nx, ny, nz))
    }

    /// Compute average plane through a set of 3D points.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points
    ///   - boundaryPointCount: Number of boundary points (for plane orientation)
    ///   - tolerance: Tolerance for planarity check
    /// - Returns: Average plane result, or nil if computation fails
    public static func averagePlane(
        points: [SIMD3<Double>],
        boundaryPointCount: Int? = nil,
        tolerance: Double = 1e-3
    ) -> AveragePlaneResult? {
        guard points.count >= 3 else { return nil }
        var flat: [Double] = []
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        let nbBound = Int32(boundaryPointCount ?? points.count)
        let r = OCCTGeomPlateBuildAveragePlane(&flat, Int32(points.count), nbBound, tolerance)
        guard r.isPlane || r.isLine else { return nil }
        return AveragePlaneResult(
            isPlane: r.isPlane,
            isLine: r.isLine,
            normal: SIMD3(r.normalX, r.normalY, r.normalZ),
            origin: SIMD3(r.originX, r.originY, r.originZ),
            uvBox: (umin: r.umin, umax: r.umax, vmin: r.vmin, vmax: r.vmax),
            lineOrigin: SIMD3(r.lineOriginX, r.lineOriginY, r.lineOriginZ),
            lineDirection: SIMD3(r.lineDirX, r.lineDirY, r.lineDirZ)
        )
    }

    /// Result of average plane computation.
    public struct AveragePlaneResult: Sendable {
        /// Whether the points form a plane.
        public let isPlane: Bool
        /// Whether the points form a line (collinear).
        public let isLine: Bool
        /// Plane normal (meaningful when isPlane is true).
        public let normal: SIMD3<Double>
        /// Plane origin (meaningful when isPlane is true).
        public let origin: SIMD3<Double>
        /// UV bounding box on the plane.
        public let uvBox: (umin: Double, umax: Double, vmin: Double, vmax: Double)
        /// Line origin (meaningful when isLine is true).
        public let lineOrigin: SIMD3<Double>
        /// Line direction (meaningful when isLine is true).
        public let lineDirection: SIMD3<Double>
    }

    /// Get G0/G1/G2 errors from a plate surface construction.
    ///
    /// Builds a plate surface through the given points and reports the
    /// positional (G0), tangential (G1), and curvature (G2) errors.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points
    ///   - tolerance: Approximation tolerance
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum BSpline segments (default 9)
    /// - Returns: Tuple of (g0Error, g1Error, g2Error), or nil on failure
    public static func plateErrors(
        points: [SIMD3<Double>],
        tolerance: Double = 1e-3,
        maxDegree: Int = 8,
        maxSegments: Int = 9
    ) -> (g0Error: Double, g1Error: Double, g2Error: Double)? {
        guard points.count >= 3 else { return nil }
        var flat: [Double] = []
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        var g0: Double = 0
        var g1: Double = 0
        var g2: Double = 0
        let ok = OCCTGeomPlateErrors(
            &flat, Int32(points.count),
            tolerance, Int32(maxDegree), Int32(maxSegments),
            &g0, &g1, &g2)
        guard ok else { return nil }
        return (g0, g1, g2)
    }

    // MARK: - v0.80.0: Extrema, gce factories, GeomTools persistence

    /// Result of point-to-surface extrema.
    public struct PointSurfaceExtrema: Sendable {
        public let isDone: Bool
        public let count: Int
    }

    /// Point on surface from extrema result.
    public struct ExtremaPointOnSurface: Sendable {
        public let squareDistance: Double
        public let point: SIMD3<Double>
        public let u: Double
        public let v: Double
    }

    /// Compute point-to-surface extrema.
    public func extremaPS(point: SIMD3<Double>) -> PointSurfaceExtrema {
        let r = OCCTExtremaExtPS(point.x, point.y, point.z, handle)
        return PointSurfaceExtrema(isDone: r.isDone, count: Int(r.nbExt))
    }

    /// Get Nth extremum from point-surface computation (1-based).
    public func extremaPSPoint(point: SIMD3<Double>, index: Int) -> ExtremaPointOnSurface {
        let r = OCCTExtremaExtPSPoint(point.x, point.y, point.z, handle, Int32(index))
        return ExtremaPointOnSurface(
            squareDistance: r.squareDistance,
            point: SIMD3(r.x, r.y, r.z), u: r.u, v: r.v)
    }

    /// Result of surface-to-surface extrema.
    public struct SurfaceSurfaceExtrema: Sendable {
        public let isDone: Bool
        public let isParallel: Bool
        public let count: Int
    }

    /// Compute surface-to-surface extrema.
    public func extremaSS(other: Surface) -> SurfaceSurfaceExtrema {
        let r = OCCTExtremaExtSS(handle, other.handle)
        return SurfaceSurfaceExtrema(
            isDone: r.isDone, isParallel: r.isParallel, count: Int(r.nbExt))
    }

    /// Get Nth extremum from surface-surface computation.
    public func extremaSSPoint(other: Surface, index: Int) -> Curve3D.ExtremaPointPair {
        let r = OCCTExtremaExtSSPoint(handle, other.handle, Int32(index))
        return Curve3D.ExtremaPointPair(
            squareDistance: r.squareDistance,
            point1: SIMD3(r.x1, r.y1, r.z1), param1: r.param1,
            point2: SIMD3(r.x2, r.y2, r.z2), param2: r.param2)
    }

    /// Create a conical surface from 2 points (axis) + 2 radii.
    ///
    /// Equivalent to ``conicalSurface(point1:point2:r1:r2:)`` — same underlying
    /// `GC_MakeConicalSurface` construction, kept as a separate entry point for
    /// API discoverability under the "gce_Make"-style naming used elsewhere in
    /// this file. Previously this used an independent `gce_MakeCone` construction
    /// path; unified onto `GC_MakeConicalSurface` to avoid maintaining two
    /// implementations of the same operation (#420).
    ///
    /// ```swift
    /// let cone = Surface.coneFrom2PointsRadii(
    ///     p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10), radius1: 5.0, radius2: 2.0)
    /// ```
    public static func coneFrom2PointsRadii(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        radius1: Double, radius2: Double
    ) -> Surface? {
        conicalSurface(point1: p1, point2: p2, r1: radius1, r2: radius2)
    }

    /// Create a cylindrical surface from 3 points.
    ///
    /// Equivalent to ``cylindricalSurface(point1:point2:point3:)`` — same underlying
    /// `GC_MakeCylindricalSurface` construction, kept as a separate entry point for
    /// API discoverability under the "gce_Make"-style naming used elsewhere in
    /// this file. Previously this used an independent `gce_MakeCylinder` construction
    /// path; unified onto `GC_MakeCylindricalSurface` to avoid maintaining two
    /// implementations of the same operation (#420).
    ///
    /// ```swift
    /// let cyl = Surface.cylinderFrom3Points(
    ///     p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10), p3: SIMD3(5, 0, 5))
    /// ```
    public static func cylinderFrom3Points(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>
    ) -> Surface? {
        cylindricalSurface(point1: p1, point2: p2, point3: p3)
    }

    /// Create a plane from equation Ax+By+Cz+D=0 (gce_MakePln).
    public static func planeFromEquation(a: Double, b: Double, c: Double, d: Double) -> Surface? {
        guard let h = OCCTGceMakePlnFromEquation(a, b, c, d) else { return nil }
        return Surface(handle: h)
    }

    /// Create a plane from 3 points.
    ///
    /// A labeled-argument spelling of `planeFromPoints(_:_:_:)` (`gce_MakePln` instead of
    /// `GC_MakePlane`), and it delegates to it — the two cannot produce different planes for the
    /// same input (#421).
    ///
    /// - Parameters:
    ///   - p1: First point
    ///   - p2: Second point
    ///   - p3: Third point
    /// - Returns: Plane surface, or nil if points are collinear (including coincident)
    ///
    /// ```swift
    /// let base = Surface.planeFrom3Points(p1: SIMD3(0, 0, 0), p2: SIMD3(1, 0, 0), p3: SIMD3(0, 1, 0))
    /// #expect(base != nil)
    /// ```
    public static func planeFrom3Points(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>
    ) -> Surface? {
        planeFromPoints(p1, p2, p3)
    }

    /// Serialize surfaces to string via GeomTools_SurfaceSet.
    public static func serializeSurfaces(_ surfaces: [Surface]) -> String? {
        let handles = surfaces.map { $0.handle as OCCTSurfaceRef }
        guard
            let cStr = handles.withUnsafeBufferPointer({
                OCCTGeomToolsSurfaceSetWrite($0.baseAddress!, Int32(surfaces.count))
            })
        else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(cStr)
        return result
    }

    /// Deserialize surfaces from string via GeomTools_SurfaceSet.
    public static func deserializeSurfaces(_ data: String) -> [Surface]? {
        var count: Int32 = 0
        guard let arr = OCCTGeomToolsSurfaceSetRead(data, &count), count > 0 else { return nil }
        var surfaces: [Surface] = []
        for i in 0..<Int(count) {
            if let h = arr[i] {
                surfaces.append(Surface(handle: h))
            }
        }
        free(arr)
        return surfaces.isEmpty ? nil : surfaces
    }

    // MARK: - Geom_Plane Properties (v0.108.0)

    /// Access plane-specific properties.
    public struct PlaneProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The plane equation coefficients (Ax + By + Cz + D = 0).
        public var coefficients: (a: Double, b: Double, c: Double, d: Double) {
            var a = 0.0
            var b = 0.0
            var c = 0.0
            var d = 0.0
            OCCTSurfacePlaneCoefficients(handle, &a, &b, &c, &d)
            return (a, b, c, d)
        }

        /// A U iso-curve on the plane.
        public func uIso(_ u: Double) -> Curve3D? {
            guard let h = OCCTSurfacePlaneUIso(handle, u) else { return nil }
            return Curve3D(handle: h)
        }

        /// A V iso-curve on the plane.
        public func vIso(_ v: Double) -> Curve3D? {
            guard let h = OCCTSurfacePlaneVIso(handle, v) else { return nil }
            return Curve3D(handle: h)
        }

        /// The plane data (origin + normal).
        public var pln: (origin: SIMD3<Double>, normal: SIMD3<Double>) {
            let r = unwrapAxisComponents { OCCTSurfacePlanePln(handle, $0, $1, $2, $3, $4, $5) }
            return (origin: r.origin, normal: r.direction)
        }
    }

    /// Plane-specific properties (meaningful only when the underlying surface is a Geom_Plane).
    public var planeProperties: PlaneProperties { PlaneProperties(handle: handle) }

    // MARK: - Geom_SphericalSurface Properties (v0.108.0)

    /// Access sphere-specific properties.
    public struct SphereProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The radius.
        public var radius: Double { OCCTSurfaceSphereRadius(handle) }

        /// Set the radius.
        @discardableResult
        public func setRadius(_ r: Double) -> Bool { OCCTSurfaceSphereSetRadius(handle, r) }

        /// The surface area (4*pi*r^2).
        public var area: Double { OCCTSurfaceSphereArea(handle) }

        /// The volume (4/3*pi*r^3).
        public var volume: Double { OCCTSurfaceSphereVolume(handle) }

        /// The center point.
        public var center: SIMD3<Double> {
            unwrapVectorComponents { OCCTSurfaceSphereCenter(handle, $0, $1, $2) }
        }

        /// A U iso-curve on the sphere.
        public func uIso(_ u: Double) -> Curve3D? {
            guard let h = OCCTSurfaceSphereUIso(handle, u) else { return nil }
            return Curve3D(handle: h)
        }

        /// A V iso-curve on the sphere.
        public func vIso(_ v: Double) -> Curve3D? {
            guard let h = OCCTSurfaceSphereVIso(handle, v) else { return nil }
            return Curve3D(handle: h)
        }

        /// The gp_Sphere data (center + radius).
        public var sphere: (center: SIMD3<Double>, radius: Double) {
            var cx = 0.0
            var cy = 0.0
            var cz = 0.0
            var r = 0.0
            OCCTSurfaceSphereSphere(handle, &cx, &cy, &cz, &r)
            return (SIMD3(cx, cy, cz), r)
        }
    }

    /// Sphere-specific properties (meaningful only when the underlying surface is a Geom_SphericalSurface).
    public var sphereProperties: SphereProperties { SphereProperties(handle: handle) }

    // MARK: - Geom_ToroidalSurface Properties (v0.108.0)

    /// Access torus-specific properties.
    public struct TorusProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The major radius.
        public var majorRadius: Double { OCCTSurfaceTorusMajorRadius(handle) }

        /// The minor radius.
        public var minorRadius: Double { OCCTSurfaceTorusMinorRadius(handle) }

        /// Set the major radius.
        @discardableResult
        public func setMajorRadius(_ r: Double) -> Bool {
            OCCTSurfaceTorusSetMajorRadius(handle, r)
        }

        /// Set the minor radius.
        @discardableResult
        public func setMinorRadius(_ r: Double) -> Bool {
            OCCTSurfaceTorusSetMinorRadius(handle, r)
        }

        /// The surface area (4*pi^2*R*r).
        public var area: Double { OCCTSurfaceTorusArea(handle) }

        /// The volume (2*pi^2*R*r^2).
        public var volume: Double { OCCTSurfaceTorusVolume(handle) }
    }

    /// Torus-specific properties (meaningful only when the underlying surface is a Geom_ToroidalSurface).
    public var torusProperties: TorusProperties { TorusProperties(handle: handle) }

    // MARK: - Geom_CylindricalSurface Properties (v0.108.0)

    /// Access cylinder-specific properties.
    public struct CylinderProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The radius.
        public var radius: Double { OCCTSurfaceCylinderRadius(handle) }

        /// Set the radius.
        @discardableResult
        public func setRadius(_ r: Double) -> Bool { OCCTSurfaceCylinderSetRadius(handle, r) }

        /// The axis (position + direction).
        public var axis: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            let a = unwrapAxisComponents { OCCTSurfaceCylinderAxis(handle, $0, $1, $2, $3, $4, $5) }
            return (a.origin, a.direction)
        }

        /// A U iso-curve on the cylinder.
        public func uIso(_ u: Double) -> Curve3D? {
            guard let h = OCCTSurfaceCylinderUIso(handle, u) else { return nil }
            return Curve3D(handle: h)
        }
    }

    /// Cylinder-specific properties (meaningful only when the underlying surface is a Geom_CylindricalSurface).
    public var cylinderProperties: CylinderProperties { CylinderProperties(handle: handle) }

    // MARK: - Geom_ConicalSurface Properties (v0.108.0)

    /// Access cone-specific properties.
    public struct ConeProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The semi-angle of the cone.
        public var semiAngle: Double { OCCTSurfaceConeSemiAngle(handle) }

        /// The reference radius at the cone origin.
        public var refRadius: Double { OCCTSurfaceConeRefRadius(handle) }

        /// The apex of the cone.
        public var apex: SIMD3<Double> {
            unwrapVectorComponents { OCCTSurfaceConeApex(handle, $0, $1, $2) }
        }

        /// The axis of the cone (position + direction).
        public var axis: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            let a = unwrapAxisComponents { OCCTSurfaceConeAxis(handle, $0, $1, $2, $3, $4, $5) }
            return (a.origin, a.direction)
        }
    }

    /// Cone-specific properties (meaningful only when the underlying surface is a Geom_ConicalSurface).
    public var coneProperties: ConeProperties { ConeProperties(handle: handle) }

    // MARK: - Geom_SweptSurface Properties (v0.108.0)

    /// Access swept-surface-specific properties (extrusion or revolution).
    public struct SweptProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// The sweep direction.
        public var direction: SIMD3<Double> {
            unwrapVectorComponents { OCCTSurfaceSweptDirection(handle, $0, $1, $2) }
        }

        /// The basis curve of the swept surface.
        public var basisCurve: Curve3D? {
            guard let h = OCCTSurfaceSweptBasisCurve(handle) else { return nil }
            return Curve3D(handle: h)
        }
    }

    /// Swept-surface-specific properties (meaningful for extrusion or revolution surfaces).
    public var sweptProperties: SweptProperties { SweptProperties(handle: handle) }

    // MARK: - v0.115.0: Surface from point grid, normal, curvatures

    /// Approximate a BSpline surface through a grid of 3D points.
    ///
    /// Points are in row-major order: point[v*uCount+u].
    ///
    /// - Note: `degMax` is **clamped to the grid size** (`min(uCount, vCount) − 1`). A B-spline of
    ///   degree _d_ needs at least _d_+1 samples per direction; asking for a degree higher than the
    ///   grid supports (e.g. the default `degMax: 8` on a 7×7 grid) over-parameterises the fit, which
    ///   can oscillate/self-overlap in 3D and make downstream meshing (`BRepMesh`) never converge
    ///   (OCCTSwift #244). The clamp keeps the fit well-posed; pass a smaller `degMax` for an even
    ///   smoother result.
    ///
    /// `continuity` is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3). Unlike the
    /// `approximated` family, the fitter accepts every value without failing — it treats the
    /// request as an upper bound on what it will try to achieve.
    public static func fromPointGrid(
        points: [SIMD3<Double>], uCount: Int, vCount: Int,
        degMin: Int = 3, degMax: Int = 8,
        continuity: Int = 2, tolerance: Double = 1e-3
    ) -> Surface? {
        guard points.count == uCount * vCount, uCount >= 2, vCount >= 2 else { return nil }
        // Clamp the degree to what the grid can support (#244): degree ≤ samples − 1.
        let fitMaxDegree = max(1, min(uCount, vCount) - 1)
        let cappedMax = min(degMax, fitMaxDegree)
        let cappedMin = min(max(1, degMin), cappedMax)
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        guard
            let ref = flat.withUnsafeBufferPointer({ buf in
                OCCTPointsToSurfaceBSpline(
                    buf.baseAddress!, Int32(uCount), Int32(vCount),
                    Int32(cappedMin), Int32(cappedMax), Int32(continuity), tolerance)
            })
        else { return nil }
        return Surface(handle: ref)
    }

    /// Compute the surface normal at (u, v), returning the zero vector where it is undefined.
    ///
    /// This is the non-optional counterpart of `normal(atU:v:)`. Both evaluate the same
    /// `GeomLProp_SLProps` normal and use the same degeneracy test, so they always agree on
    /// *where* the normal exists — they differ only in how they report its absence: this method
    /// returns `SIMD3(0, 0, 0)`, `normal(atU:v:)` returns `nil`. Prefer `normal(atU:v:)` when you
    /// need to tell "undefined" apart from a genuine result.
    ///
    /// - Parameters:
    ///   - u: U parameter.
    ///   - v: V parameter.
    /// - Returns: The unit normal, or `SIMD3(0, 0, 0)` at a singular point (a sphere pole, a cone
    ///   apex) where the tangent plane is degenerate.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// let n = sphere.normal(u: 0, v: .pi / 4)     // unit length
    /// #expect(abs(simd_length(n) - 1) < 1e-9)
    ///
    /// // A cone apex is a genuine singularity: zero vector here, nil from normal(atU:v:).
    /// let cone = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    /// #expect(simd_length(cone.normal(u: 0, v: 0)) < 1e-12)
    /// #expect(cone.normal(atU: 0, v: 0) == nil)
    /// ```
    ///
    /// > A sphere pole (`v = ±π/2`) is *not* one of these points — `GeomLProp_SLProps` still
    /// > resolves a normal there, and both methods return it.
    public func normal(u: Double, v: Double) -> SIMD3<Double> {
        unwrapVectorComponents { OCCTSurfaceNormal(handle, u, v, $0, $1, $2) }
    }

    /// Compute Gaussian and mean curvature at (u, v) in one evaluation.
    ///
    /// - Parameters:
    ///   - u: U parameter.
    ///   - v: V parameter.
    /// - Returns: Both curvatures, or `nil` where curvature is undefined.
    ///
    /// Equivalent to calling `gaussianCurvature(atU:v:)` and `meanCurvature(atU:v:)` at the same
    /// point, for one `GeomLProp_SLProps` evaluation instead of two. All three share that one
    /// construction, so they agree exactly — including on whether curvature is defined at all.
    /// Before #405 this method built its own with a resolution ten times looser than its
    /// siblings' `Precision::Confusion()`, and could report `(0, 0)` for a point where they
    /// returned a real curvature. It returned `(0, 0)` for the undefined case too until #595 —
    /// which is also a plane's real answer, so the agreement this doc claims was not one it could
    /// express.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 5)!
    /// if let (gaussian, mean) = sphere.curvatures(u: 0, v: .pi / 4) {
    ///     #expect(gaussian == sphere.gaussianCurvature(atU: 0, v: .pi / 4))
    ///     #expect(mean == sphere.meanCurvature(atU: 0, v: .pi / 4))
    /// }
    /// ```
    public func curvatures(u: Double, v: Double) -> (gaussian: Double, mean: Double)? {
        var g = 0.0
        var m = 0.0
        guard OCCTSurfaceCurvatures(handle, u, v, &g, &m) else { return nil }
        return (g, m)
    }

    // MARK: - v0.125.0: BSpline Surface deep method completion

    /// Local evaluation D0 within a specific knot span.
    public func bsplineLocalD0(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int
    ) -> SIMD3<Double> {
        unwrapVectorComponents {
            OCCTSurfaceBSplineLocalD0(
                handle, u, v, Int32(fromUK1), Int32(toUK2),
                Int32(fromVK1), Int32(toVK2), $0, $1, $2)
        }
    }

    /// Local evaluation D1 within a specific knot span.
    public func bsplineLocalD1(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int
    )
        -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
    {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1ux = 0.0
        var d1uy = 0.0
        var d1uz = 0.0
        var d1vx = 0.0
        var d1vy = 0.0
        var d1vz = 0.0
        OCCTSurfaceBSplineLocalD1(
            handle, u, v, Int32(fromUK1), Int32(toUK2),
            Int32(fromVK1), Int32(toVK2),
            &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz))
    }

    /// Local evaluation D2 within a specific knot span.
    public func bsplineLocalD2(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int
    )
        -> (
            point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
            d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>
        )
    {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1ux = 0.0
        var d1uy = 0.0
        var d1uz = 0.0
        var d1vx = 0.0
        var d1vy = 0.0
        var d1vz = 0.0
        var d2ux = 0.0
        var d2uy = 0.0
        var d2uz = 0.0
        var d2vx = 0.0
        var d2vy = 0.0
        var d2vz = 0.0
        var d2uvx = 0.0
        var d2uvy = 0.0
        var d2uvz = 0.0
        OCCTSurfaceBSplineLocalD2(
            handle, u, v, Int32(fromUK1), Int32(toUK2),
            Int32(fromVK1), Int32(toVK2),
            &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
            &d2uvx, &d2uvy, &d2uvz)
        return (
            SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
            SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz)
        )
    }

    /// Local evaluation D3 within a specific knot span.
    public func bsplineLocalD3(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int
    )
        -> (
            point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
            d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>,
            d3u: SIMD3<Double>, d3v: SIMD3<Double>, d3uuv: SIMD3<Double>, d3uvv: SIMD3<Double>
        )
    {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1ux = 0.0
        var d1uy = 0.0
        var d1uz = 0.0
        var d1vx = 0.0
        var d1vy = 0.0
        var d1vz = 0.0
        var d2ux = 0.0
        var d2uy = 0.0
        var d2uz = 0.0
        var d2vx = 0.0
        var d2vy = 0.0
        var d2vz = 0.0
        var d2uvx = 0.0
        var d2uvy = 0.0
        var d2uvz = 0.0
        var d3ux = 0.0
        var d3uy = 0.0
        var d3uz = 0.0
        var d3vx = 0.0
        var d3vy = 0.0
        var d3vz = 0.0
        var d3uuvx = 0.0
        var d3uuvy = 0.0
        var d3uuvz = 0.0
        var d3uvvx = 0.0
        var d3uvvy = 0.0
        var d3uvvz = 0.0
        OCCTSurfaceBSplineLocalD3(
            handle, u, v, Int32(fromUK1), Int32(toUK2),
            Int32(fromVK1), Int32(toVK2),
            &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
            &d2uvx, &d2uvy, &d2uvz,
            &d3ux, &d3uy, &d3uz, &d3vx, &d3vy, &d3vz,
            &d3uuvx, &d3uuvy, &d3uuvz, &d3uvvx, &d3uvvy, &d3uvvz)
        return (
            SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
            SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz),
            SIMD3(d3ux, d3uy, d3uz), SIMD3(d3vx, d3vy, d3vz),
            SIMD3(d3uuvx, d3uuvy, d3uuvz), SIMD3(d3uvvx, d3uvvy, d3uvvz)
        )
    }

    /// Local derivative DN within a specific knot span.
    public func bsplineLocalDN(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int, nu: Int, nv: Int
    ) -> SIMD3<Double> {
        unwrapVectorComponents {
            OCCTSurfaceBSplineLocalDN(
                handle, u, v, Int32(fromUK1), Int32(toUK2),
                Int32(fromVK1), Int32(toVK2), Int32(nu), Int32(nv), $0, $1, $2)
        }
    }

    /// Local value within a specific knot span.
    public func bsplineLocalValue(
        u: Double, v: Double, fromUK1: Int, toUK2: Int,
        fromVK1: Int, toVK2: Int
    ) -> SIMD3<Double> {
        unwrapVectorComponents {
            OCCTSurfaceBSplineLocalValue(
                handle, u, v, Int32(fromUK1), Int32(toUK2),
                Int32(fromVK1), Int32(toVK2), $0, $1, $2)
        }
    }

    /// Extract U isoparametric curve from BSpline surface.
    public func bsplineUIso(u: Double) -> Curve3D? {
        guard let ref = OCCTSurfaceBSplineUIso(handle, u) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Extract V isoparametric curve from BSpline surface.
    public func bsplineVIso(v: Double) -> Curve3D? {
        guard let ref = OCCTSurfaceBSplineVIso(handle, v) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Locate U knot span.
    ///
    /// Returns (i1, i2) indices.
    public func bsplineLocateU(u: Double, paramTol: Double) -> (i1: Int, i2: Int) {
        var i1: Int32 = 0
        var i2: Int32 = 0
        OCCTSurfaceBSplineLocateU(handle, u, paramTol, &i1, &i2)
        return (Int(i1), Int(i2))
    }

    /// Locate V knot span.
    ///
    /// Returns (i1, i2) indices.
    public func bsplineLocateV(v: Double, paramTol: Double) -> (i1: Int, i2: Int) {
        var i1: Int32 = 0
        var i2: Int32 = 0
        OCCTSurfaceBSplineLocateV(handle, v, paramTol, &i1, &i2)
        return (Int(i1), Int(i2))
    }

    /// Get a single U knot value by index (1-based).
    public func bsplineUKnot(index: Int) -> Double {
        OCCTSurfaceBSplineUKnot(handle, Int32(index))
    }

    /// Get a single V knot value by index (1-based).
    public func bsplineVKnot(index: Int) -> Double {
        OCCTSurfaceBSplineVKnot(handle, Int32(index))
    }

    /// Get U multiplicity by index (1-based).
    public func bsplineUMultiplicity(index: Int) -> Int {
        Int(OCCTSurfaceBSplineUMultiplicity(handle, Int32(index)))
    }

    /// Get V multiplicity by index (1-based).
    public func bsplineVMultiplicity(index: Int) -> Int {
        Int(OCCTSurfaceBSplineVMultiplicity(handle, Int32(index)))
    }

    /// U knot distribution (0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier).
    public var bsplineUKnotDistribution: Int {
        Int(OCCTSurfaceBSplineUKnotDistribution(handle))
    }

    /// V knot distribution (0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier).
    public var bsplineVKnotDistribution: Int {
        Int(OCCTSurfaceBSplineVKnotDistribution(handle))
    }

    /// Get all poles as flat array for BSpline surface.
    public var bsplinePoles: [SIMD3<Double>] {
        let uCount = Int(OCCTSurfaceBSplineNbUPoles(handle))
        let vCount = Int(OCCTSurfaceBSplineNbVPoles(handle))
        guard uCount > 0 && vCount > 0 else { return [] }
        var flat = [Double](repeating: 0, count: uCount * vCount * 3)
        OCCTSurfaceBSplineGetPoles(handle, &flat)
        return unpackSIMD3(flat, count: uCount * vCount)
    }

    /// Get parameter bounds for BSpline surface.
    public var bsplineBounds: (u1: Double, u2: Double, v1: Double, v2: Double) {
        var u1 = 0.0
        var u2 = 0.0
        var v1 = 0.0
        var v2 = 0.0
        OCCTSurfaceBSplineBounds(handle, &u1, &u2, &v1, &v2)
        return (u1, u2, v1, v2)
    }

    /// Is the BSpline surface closed in U?
    public var bsplineIsUClosed: Bool {
        OCCTSurfaceBSplineIsUClosed(handle)
    }

    /// Is the BSpline surface closed in V?
    public var bsplineIsVClosed: Bool {
        OCCTSurfaceBSplineIsVClosed(handle)
    }

    // MARK: - v0.125.0: Bezier Surface deep method completion

    /// Extract U isoparametric curve from Bezier surface.
    public func bezierUIso(u: Double) -> Curve3D? {
        guard let ref = OCCTSurfaceBezierUIso(handle, u) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Extract V isoparametric curve from Bezier surface.
    public func bezierVIso(v: Double) -> Curve3D? {
        guard let ref = OCCTSurfaceBezierVIso(handle, v) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Is the Bezier surface closed in U?
    public var bezierIsUClosed: Bool {
        OCCTSurfaceBezierIsUClosed(handle)
    }

    /// Is the Bezier surface closed in V?
    public var bezierIsVClosed: Bool {
        OCCTSurfaceBezierIsVClosed(handle)
    }

    /// Is the Bezier surface periodic in U?
    public var bezierIsUPeriodic: Bool {
        OCCTSurfaceBezierIsUPeriodic(handle)
    }

    /// Is the Bezier surface periodic in V?
    public var bezierIsVPeriodic: Bool {
        OCCTSurfaceBezierIsVPeriodic(handle)
    }

    /// Bezier surface continuity, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// (`0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN`). A Bezier surface is CN by construction, so
    /// this is `6`; `0` if the surface is not a Bezier. Prefer ``ContinuityClass`` (#619).
    public var bezierContinuity: Int {
        Int(OCCTSurfaceBezierContinuity(handle))
    }

    /// Is the Bezier surface at least CN continuous in U?
    public func bezierIsCNu(_ n: Int) -> Bool {
        OCCTSurfaceBezierIsCNu(handle, Int32(n))
    }

    /// Is the Bezier surface at least CN continuous in V?
    public func bezierIsCNv(_ n: Int) -> Bool {
        OCCTSurfaceBezierIsCNv(handle, Int32(n))
    }

    /// Get all poles as flat array for Bezier surface.
    public var bezierPoles: [SIMD3<Double>] {
        let uCount = Int(OCCTSurfaceBezierNbUPoles(handle))
        let vCount = Int(OCCTSurfaceBezierNbVPoles(handle))
        guard uCount > 0 && vCount > 0 else { return [] }
        var flat = [Double](repeating: 0, count: uCount * vCount * 3)
        OCCTSurfaceBezierGetPoles(handle, &flat)
        return unpackSIMD3(flat, count: uCount * vCount)
    }

    /// Get all weights as flat array for Bezier surface.
    ///
    /// Returns nil if non-rational.
    public var bezierWeights: [Double]? {
        let uCount = Int(OCCTSurfaceBezierNbUPoles(handle))
        let vCount = Int(OCCTSurfaceBezierNbVPoles(handle))
        guard uCount > 0 && vCount > 0 else { return nil }
        var weights = [Double](repeating: 0, count: uCount * vCount)
        guard OCCTSurfaceBezierGetWeights(handle, &weights) else { return nil }
        return weights
    }

    /// Get parameter bounds for Bezier surface.
    public var bezierBounds: (u1: Double, u2: Double, v1: Double, v2: Double) {
        var u1 = 0.0
        var u2 = 0.0
        var v1 = 0.0
        var v2 = 0.0
        OCCTSurfaceBezierBounds(handle, &u1, &u2, &v1, &v2)
        return (u1, u2, v1, v2)
    }

    /// Number of U poles (rows) for a Bezier surface.
    public var bezierNbUPoles: Int {
        Int(OCCTSurfaceBezierNbUPoles(handle))
    }

    /// Number of V poles (columns) for a Bezier surface.
    public var bezierNbVPoles: Int {
        Int(OCCTSurfaceBezierNbVPoles(handle))
    }

    /// U degree for a Bezier surface.
    public var bezierUDegree: Int {
        Int(OCCTSurfaceBezierUDegree(handle))
    }

    /// V degree for a Bezier surface.
    public var bezierVDegree: Int {
        Int(OCCTSurfaceBezierVDegree(handle))
    }

    // MARK: - BSpline Surface completions (v0.126.0)

    /// Get all U multiplicities for a BSpline surface.
    public var bsplineUMultiplicities: [Int] {
        let count = Int(OCCTSurfaceBSplineNbUKnots(handle))
        guard count > 0 else { return [] }
        var mults = [Int32](repeating: 0, count: count)
        OCCTSurfaceBSplineGetUMultiplicities(handle, &mults)
        return mults.map { Int($0) }
    }

    /// Get all V multiplicities for a BSpline surface.
    public var bsplineVMultiplicities: [Int] {
        let count = Int(OCCTSurfaceBSplineNbVKnots(handle))
        guard count > 0 else { return [] }
        var mults = [Int32](repeating: 0, count: count)
        OCCTSurfaceBSplineGetVMultiplicities(handle, &mults)
        return mults.map { Int($0) }
    }

    /// Reverse the U parameter direction of a BSpline surface (in-place).
    @discardableResult
    public func bsplineUReverse() -> Bool {
        OCCTSurfaceBSplineUReverse(handle)
    }

    /// Reverse the V parameter direction of a BSpline surface (in-place).
    @discardableResult
    public func bsplineVReverse() -> Bool {
        OCCTSurfaceBSplineVReverse(handle)
    }

    /// Normalize U,V parameters for a periodic BSpline surface.
    public func bsplinePeriodicNormalization(u: inout Double, v: inout Double) -> Bool {
        OCCTSurfaceBSplinePeriodicNormalization(handle, &u, &v)
    }

    // MARK: - Bezier Surface completions (v0.126.0)

    /// Insert a pole column after index in a Bezier surface.
    ///
    /// Poles array is [SIMD3] of size NbUPoles.
    @discardableResult
    public func bezierInsertPoleColAfter(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleColAfter(
            handle, Int32(colIndex), flat, Int32(poles.count))
    }

    /// Insert a pole row after index in a Bezier surface.
    ///
    /// Poles array is [SIMD3] of size NbVPoles.
    @discardableResult
    public func bezierInsertPoleRowAfter(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleRowAfter(
            handle, Int32(rowIndex), flat, Int32(poles.count))
    }

    /// Remove a pole column from a Bezier surface (1-based index).
    @discardableResult
    public func bezierRemovePoleCol(_ colIndex: Int) -> Bool {
        OCCTSurfaceBezierRemovePoleCol(handle, Int32(colIndex))
    }

    /// Remove a pole row from a Bezier surface (1-based index).
    @discardableResult
    public func bezierRemovePoleRow(_ rowIndex: Int) -> Bool {
        OCCTSurfaceBezierRemovePoleRow(handle, Int32(rowIndex))
    }

    /// Increase the degree of a Bezier surface.
    @discardableResult
    public func bezierIncreaseDegree(uDeg: Int, vDeg: Int) -> Bool {
        OCCTSurfaceBezierIncreaseDegree(handle, Int32(uDeg), Int32(vDeg))
    }

    /// Reverse U parameter direction of a Bezier surface (in-place).
    @discardableResult
    public func bezierUReverse() -> Bool {
        OCCTSurfaceBezierUReverse(handle)
    }

    /// Reverse V parameter direction of a Bezier surface (in-place).
    @discardableResult
    public func bezierVReverse() -> Bool {
        OCCTSurfaceBezierVReverse(handle)
    }

    // MARK: - v0.127.0: Bezier surface completions

    /// Set a pole column with weights on a Bezier surface.
    /// - Parameters:
    ///   - vIndex: Column index (1-based)
    ///   - poles: Array of 3D points (must have NbUPoles elements)
    ///   - weights: Array of weights (must have NbUPoles elements)
    /// - Returns: true if the column was set, false on a count mismatch.
    @discardableResult
    public func bezierSetPoleColWeights(vIndex: Int, poles: [SIMD3<Double>], weights: [Double])
        -> Bool
    {
        guard poles.count == weights.count else { return false }
        var flat = [Double]()
        flat.reserveCapacity(poles.count * 3)
        for p in poles {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        return OCCTSurfaceBezierSetPoleColWeights(
            handle, Int32(vIndex), flat, weights, Int32(poles.count))
    }

    /// Set a pole row with weights on a Bezier surface.
    /// - Parameters:
    ///   - uIndex: Row index (1-based)
    ///   - poles: Array of 3D points (must have NbVPoles elements)
    ///   - weights: Array of weights (must have NbVPoles elements)
    /// - Returns: true if the row was set, false on a count mismatch.
    @discardableResult
    public func bezierSetPoleRowWeights(uIndex: Int, poles: [SIMD3<Double>], weights: [Double])
        -> Bool
    {
        guard poles.count == weights.count else { return false }
        var flat = [Double]()
        flat.reserveCapacity(poles.count * 3)
        for p in poles {
            flat.append(p.x)
            flat.append(p.y)
            flat.append(p.z)
        }
        return OCCTSurfaceBezierSetPoleRowWeights(
            handle, Int32(uIndex), flat, weights, Int32(poles.count))
    }

    // MARK: - v0.129.0: Bezier surface completions

    /// Insert a pole column before index in a Bezier surface.
    ///
    /// Poles array is [SIMD3] of size NbUPoles.
    @discardableResult
    public func bezierInsertPoleColBefore(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleColBefore(
            handle, Int32(colIndex), flat, Int32(poles.count))
    }

    /// Insert a pole row before index in a Bezier surface.
    ///
    /// Poles array is [SIMD3] of size NbVPoles.
    @discardableResult
    public func bezierInsertPoleRowBefore(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleRowBefore(
            handle, Int32(rowIndex), flat, Int32(poles.count))
    }

    /// Set a pole column (without weights) on a Bezier surface. vIndex is 1-based.
    @discardableResult
    public func bezierSetPoleCol(vIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierSetPoleCol(handle, Int32(vIndex), flat, Int32(poles.count))
    }

    /// Set a pole row (without weights) on a Bezier surface. uIndex is 1-based.
    @discardableResult
    public func bezierSetPoleRow(uIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierSetPoleRow(handle, Int32(uIndex), flat, Int32(poles.count))
    }

    /// Set a column of weights on a Bezier surface. vIndex is 1-based, count = NbUPoles.
    @discardableResult
    public func bezierSetWeightCol(vIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBezierSetWeightCol(handle, Int32(vIndex), weights, Int32(weights.count))
    }

    /// Set a row of weights on a Bezier surface. uIndex is 1-based, count = NbVPoles.
    @discardableResult
    public func bezierSetWeightRow(uIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBezierSetWeightRow(handle, Int32(uIndex), weights, Int32(weights.count))
    }
}

// MARK: - Surface Transform (v0.128.0)

extension Surface {

    /// Translate the surface in place by (dx, dy, dz).
    @discardableResult
    public func translate(dx: Double, dy: Double, dz: Double) -> Bool {
        OCCTSurfaceTransform(handle, 0, dx, dy, dz, 0, 0, 0, 0)
    }

    /// Rotate the surface in place around an axis by the given angle (radians).
    @discardableResult
    public func rotate(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double)
        -> Bool
    {
        OCCTSurfaceTransform(
            handle, 1,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z, angle)
    }

    /// Scale the surface in place from a center point by the given factor.
    @discardableResult
    public func scale(center: SIMD3<Double>, factor: Double) -> Bool {
        OCCTSurfaceTransform(handle, 2, center.x, center.y, center.z, factor, 0, 0, 0)
    }

    /// Mirror the surface in place through a point.
    @discardableResult
    public func mirrorPoint(_ point: SIMD3<Double>) -> Bool {
        OCCTSurfaceTransform(handle, 3, point.x, point.y, point.z, 0, 0, 0, 0)
    }

    /// Mirror the surface in place through an axis.
    @discardableResult
    public func mirrorAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Bool {
        OCCTSurfaceTransform(
            handle, 4,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z, 0)
    }

    /// Mirror the surface in place through a plane.
    @discardableResult
    public func mirrorPlane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Bool {
        OCCTSurfaceTransform(
            handle, 5,
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z, 0)
    }
}

// MARK: - GeomEval Surface Factories (v0.130.0)

extension Surface {

    /// Create a triaxial ellipsoid surface.
    /// P(u,v) = A*cos(v)*cos(u)*X + B*cos(v)*sin(u)*Y + C*sin(v)*Z
    /// - Parameters:
    ///   - a: semi-axis along X (> 0)
    ///   - b: semi-axis along Y (> 0)
    ///   - c: semi-axis along Z (> 0)
    /// - Returns: The constructed surface, or nil if a semi-axis is not positive.
    public static func ellipsoid(a: Double, b: Double, c: Double) -> Surface? {
        guard let ref = OCCTGeomEvalEllipsoidCreate(a, b, c) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a hyperboloid of revolution surface.
    /// - Parameters:
    ///   - r1: first semi-axis radius (> 0)
    ///   - r2: second semi-axis radius (> 0)
    ///   - twoSheets: if true, creates a two-sheet hyperboloid (default: one-sheet)
    /// - Returns: The constructed surface, or nil if a radius is not positive.
    public static func hyperboloid(r1: Double, r2: Double, twoSheets: Bool = false) -> Surface? {
        guard let ref = OCCTGeomEvalHyperboloidCreate(r1, r2, twoSheets ? 1 : 0) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a circular paraboloid of revolution surface.
    /// - Parameter focal: focal distance (> 0)
    /// - Returns: The constructed surface, or nil if `focal` is not positive.
    public static func paraboloid(focal: Double) -> Surface? {
        guard let ref = OCCTGeomEvalParaboloidCreate(focal) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a circular helicoid (ruled surface).
    /// S(u,v) = v*cos(u)*X + v*sin(u)*Y + (P*u/(2*Pi))*Z
    /// - Parameter pitch: axial advance per 2*Pi turn (must be != 0)
    /// - Returns: The constructed surface, or nil if `pitch` is zero.
    public static func circularHelicoid(pitch: Double) -> Surface? {
        guard let ref = OCCTGeomEvalCircularHelicoidCreate(pitch) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a hyperbolic paraboloid (saddle surface).
    /// P(u,v) = u*X + v*Y + (u^2/a^2 - v^2/b^2)*Z
    /// - Parameters:
    ///   - a: first semi-axis length (> 0)
    ///   - b: second semi-axis length (> 0)
    /// - Returns: The constructed surface, or nil if a semi-axis is not positive.
    public static func hyperbolicParaboloid(a: Double, b: Double) -> Surface? {
        guard let ref = OCCTGeomEvalHypParaboloidCreate(a, b) else { return nil }
        return Surface(handle: ref)
    }

    /// Build a Gordon surface from a network of profile and guide curves.
    ///
    /// Requires at least 2 profiles and 2 guides that form a complete grid.
    /// - Parameters:
    ///   - profiles: array of profile curves (V-direction)
    ///   - guides: array of guide curves (U-direction)
    ///   - tolerance: geometric tolerance for intersection detection
    /// - Returns: the Gordon B-spline surface, or nil on failure
    public static func gordon(profiles: [Curve3D], guides: [Curve3D], tolerance: Double = 1e-3)
        -> Surface?
    {
        guard profiles.count >= 2, guides.count >= 2 else { return nil }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        return profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else {
                    return nil as Surface?
                }
                guard
                    let ref = OCCTGeomFillGordon(
                        pPtr, Int32(profiles.count),
                        gPtr, Int32(guides.count),
                        tolerance)
                else { return nil }
                return Surface(handle: ref)
            }
        }
    }

    /// Result status of a Gordon surface build, mirroring `GeomFill_Gordon::ResultStatus`.
    public enum GordonResultStatus: Int, Sendable {
        case notStarted = 0
        case done
        case invalidInput
        case conversionFailed
        case intersectionFailed
        case orderingFailed
        case reparametrizationFailed
        case compatibilityFailed
        case curveCompatibilityFailed
        case rationalReparametrizationFailed
        case skinningFailed
        case referenceSurfaceFailed
        case knotAlignmentFailed
        case rationalDegreeOverflow
        case rationalConstructionFailed
        case periodicityFailed
        case approximationFailed
        case constructionFailed
    }

    /// Outcome of `gordonReport(...)`: surface (nil on failure), status, and whether the
    /// result was produced by approximate fallback (no exact interpolation guarantee).
    public struct GordonResult: Sendable {
        public let surface: Surface?
        public let status: GordonResultStatus
        public let isApproximate: Bool
    }

    /// Result status of a network-surface build, mirroring `GeomFill_NetworkSurface::ResultStatus`.
    public enum NetworkSurfaceStatus: Int, Sendable {
        case notStarted = 0
        case done
        case invalidInput
        case curveCompatibilityFailed
        case skinningFailed
        case referenceSurfaceFailed
        case knotAlignmentFailed
        case rationalDegreeOverflow
        case rationalConstructionFailed
        case constructionFailed
        case periodicityFailed
    }

    /// Build a Gordon surface, returning the result status and approximate flag.
    /// - Parameters:
    ///   - profiles: profile curves (V-direction), at least 2.
    ///   - guides: guide curves (U-direction), at least 2.
    ///   - tolerance: geometric tolerance for intersection detection.
    ///   - allowApproximateFallback: if true, permit a sampled B-spline fallback when exact
    ///     construction fails (result marked `isApproximate`); default false (`ExactOnly`).
    /// - Returns: The Gordon result, whose `status`/`isApproximate` describe how (or whether)
    ///   `surface` was built.
    public static func gordonReport(
        profiles: [Curve3D], guides: [Curve3D],
        tolerance: Double = 1e-3,
        allowApproximateFallback: Bool = false
    ) -> GordonResult {
        guard profiles.count >= 2, guides.count >= 2 else {
            return GordonResult(surface: nil, status: .invalidInput, isApproximate: false)
        }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        var statusRaw: Int32 = 0
        var isApprox: Bool = false
        let surfaceRef: OCCTSurfaceRef? = profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else {
                    return nil as OCCTSurfaceRef?
                }
                return OCCTGeomFillGordonReport(
                    pPtr, Int32(profiles.count),
                    gPtr, Int32(guides.count),
                    tolerance, allowApproximateFallback ? 1 : 0,
                    &statusRaw, &isApprox)
            }
        }
        let status = GordonResultStatus(rawValue: Int(statusRaw)) ?? .notStarted
        let surface = surfaceRef.map { Surface(handle: $0) }
        return GordonResult(surface: surface, status: status, isApproximate: isApprox)
    }

    /// Build a surface with the low-level `GeomFill_NetworkSurface` builder from a
    /// profile/guide curve network.
    ///
    /// The curves are converted to non-periodic B-splines; each
    /// profile/guide pair's real contact point and parameter are then found with
    /// `GeomAPI_ExtremaCurveCurve` (its nearest, not merely its first, extremum) and averaged
    /// across the family the way `GeomFill_Gordon` does, giving one locator value per profile
    /// and per guide, each already expressed in the domain the *other* family's skin needs.
    /// This is the low-level builder: it does not reorder a scrambled network or reparametrize
    /// curve families onto a common basis the way ``gordon(profiles:guides:tolerance:)`` /
    /// ``gordonReport(profiles:guides:tolerance:allowApproximateFallback:)`` do, so a network
    /// those can complete can still come back here as `.knotAlignmentFailed` or similar. A
    /// profile/guide pair with no real contact point (parallel curves, or an extrema search
    /// that finds nothing) rejects the whole network as `.invalidInput` rather than
    /// substituting an unmeasured point. Returns the surface (nil on failure) and the result
    /// status.
    ///
    /// Known limitation ([#748](https://github.com/SecondMouseAU/OCCTSwift/issues/748)): on
    /// every network tried so far, `.done` can still mean a wrong surface -- the two corners on
    /// one diagonal come back correct and the other two do not, a `GeomFill_NetworkSurface`
    /// kernel defect this entry point exposes rather than causes.
    /// ``gordon(profiles:guides:tolerance:)`` on the same curves is not affected; prefer it
    /// unless you specifically need this low-level builder's behavior.
    /// - Parameters:
    ///   - profiles: profile curves evaluated in U, at least 2.
    ///   - guides: guide curves evaluated in V, at least 2.
    ///   - tolerance: geometric tolerance for closed-seam checks.
    /// - Returns: The built surface (nil on failure) alongside a `status` describing why.
    ///
    /// ```swift
    /// let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)])!
    /// let p2 = Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(10, 10, 0)])!
    /// let g1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 10, 0)])!
    /// let g2 = Curve3D.interpolate(points: [SIMD3(10, 0, 0), SIMD3(10, 10, 0)])!
    /// let (surface, status) = Surface.networkSurface(profiles: [p1, p2], guides: [g1, g2],
    ///                                                tolerance: 1e-6)
    /// if status != .done { print("network builder declined:", status) }
    /// ```
    public static func networkSurface(
        profiles: [Curve3D], guides: [Curve3D],
        tolerance: Double = 1e-3
    )
        -> (surface: Surface?, status: NetworkSurfaceStatus)
    {
        guard profiles.count >= 2, guides.count >= 2 else { return (nil, .invalidInput) }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        var statusRaw: Int32 = 0
        let surfaceRef: OCCTSurfaceRef? = profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else {
                    return nil as OCCTSurfaceRef?
                }
                return OCCTGeomFillNetworkSurface(
                    pPtr, Int32(profiles.count),
                    gPtr, Int32(guides.count),
                    tolerance, &statusRaw)
            }
        }
        let status = NetworkSurfaceStatus(rawValue: Int(statusRaw)) ?? .notStarted
        let surface = surfaceRef.map { Surface(handle: $0) }
        return (surface, status)
    }
}

// MARK: - GeomEval TBezier / AHTBezier Surfaces (v0.131.0)

extension Surface {

    /// Create a Trigonometric Bezier surface.
    ///
    /// Tensor-product surface using trigonometric Bernstein-like bases in both U and V.
    /// Parameter domain: U in [0, pi/alphaU], V in [0, pi/alphaV].
    /// - Parameters:
    ///   - poles: control points grid in row-major order (uCount * vCount points)
    ///   - uCount: number of poles in U direction (must be odd >= 3)
    ///   - vCount: number of poles in V direction (must be odd >= 3)
    ///   - alphaU: frequency in U direction (> 0)
    ///   - alphaV: frequency in V direction (> 0)
    /// - Returns: Surface or nil on error
    public static func tBezier(
        poles: [SIMD3<Double>], uCount: Int, vCount: Int,
        alphaU: Double, alphaV: Double
    ) -> Surface? {
        guard poles.count == uCount * vCount,
            uCount >= 3, vCount >= 3,
            uCount % 2 == 1, vCount % 2 == 1
        else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x
            flat[i * 3 + 1] = p.y
            flat[i * 3 + 2] = p.z
        }
        guard
            let ref = OCCTGeomEvalTBezierSurfaceCreate(
                &flat, Int32(uCount), Int32(vCount),
                alphaU, alphaV)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Create an Algebraic-Hyperbolic-Trigonometric (AHT) Bezier surface.
    ///
    /// Tensor-product surface using mixed AHT bases in both U and V.
    /// Parameter domain: U in [0, 1], V in [0, 1].
    /// - Parameters:
    ///   - poles: control points grid in row-major order (uCount * vCount points)
    ///   - uCount: number of poles in U direction
    ///   - vCount: number of poles in V direction
    ///   - algDegreeU: algebraic degree in U (>= 0)
    ///   - algDegreeV: algebraic degree in V (>= 0)
    ///   - alphaU: hyperbolic frequency in U (>= 0)
    ///   - alphaV: hyperbolic frequency in V (>= 0)
    ///   - betaU: trigonometric frequency in U (>= 0)
    ///   - betaV: trigonometric frequency in V (>= 0)
    /// - Returns: Surface or nil on error
    public static func ahtBezier(
        poles: [SIMD3<Double>], uCount: Int, vCount: Int,
        algDegreeU: Int, algDegreeV: Int,
        alphaU: Double, alphaV: Double,
        betaU: Double, betaV: Double
    ) -> Surface? {
        guard poles.count == uCount * vCount, uCount >= 1, vCount >= 1 else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x
            flat[i * 3 + 1] = p.y
            flat[i * 3 + 2] = p.z
        }
        guard
            let ref = OCCTGeomEvalAHTBezierSurfaceCreate(
                &flat, Int32(uCount), Int32(vCount),
                Int32(algDegreeU), Int32(algDegreeV),
                alphaU, alphaV, betaU, betaV)
        else { return nil }
        return Surface(handle: ref)
    }
}

extension Surface {
    /// Convert surface to periodic form.
    ///
    /// Returns nil if already periodic or not convertible.
    public func convertToPeriodic() -> Surface? {
        guard let ref = OCCTSurfaceConvertToPeriodic(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get conversion gap (distance between original and converted surface).
    public var conversionGap: Double {
        OCCTSurfaceConversionGap(handle)
    }
}

extension Surface {
    // Continuity level for approximation is `ParametricContinuity` (Continuity.swift); the
    // `ApproxContinuity` copy Shape.swift used to declare is now a deprecated alias of it. See #398.

    /// Approximate this surface as a BSpline surface, reporting the fit's error and completion status.
    ///
    /// The same approximation ``Surface/approximated(tolerance:continuity:maxSegments:maxDegree:)``
    /// performs — one shared `GeomConvert_ApproxSurface` run behind both (#491) — with the
    /// diagnostics OCCT already computed for it. For identical arguments the two return the same
    /// surface; use this one when you need to know how close the fit actually came.
    ///
    /// `hasResult` is what decides whether `surface` is populated, and OCCT documents it as true
    /// even for a fit that is *not* within `tolerance` — `isDone` and `maxError` are how you find
    /// out. So a non-nil `surface` is not by itself a promise that `tolerance` was met; on a
    /// surface where `maxDegree` cannot reach the tolerance (a torus at 1e-9, say) OCCT returns a
    /// usable best effort with `isDone` false.
    ///
    /// The continuity defaults are C2, matching ``Surface/approximated(tolerance:continuity:maxSegments:maxDegree:)``.
    /// Before #491 they were C1 here, so the two no-continuity-argument calls fitted to different
    /// smoothness and returned different surfaces. An infinite/unbounded surface must be trimmed to
    /// a finite parameter domain first (see ``Surface/trimmed(u1:u2:v1:v2:)``).
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 10)!
    /// let fit = sphere.approxWithDetails(tolerance: 1e-5)
    /// if let bspline = fit.surface, fit.isDone {
    ///     print("fitted to \(fit.maxError) with \(bspline.uPoleCount)x\(bspline.vPoleCount) poles")
    /// }
    /// ```
    public func approxWithDetails(
        tolerance: Double, uContinuity: ParametricContinuity = .c2,
        vContinuity: ParametricContinuity = .c2,
        maxDegree: Int = 8, maxSegments: Int = 100
    ) -> ApproxSurfaceResult {
        let r = OCCTGeomConvertApproxSurface(
            handle, tolerance, uContinuity.rawValue,
            vContinuity.rawValue, Int32(maxDegree), Int32(maxSegments))
        let surf: Surface? = r.surface.map { Surface(handle: $0) }
        return ApproxSurfaceResult(
            surface: surf, maxError: r.maxError, isDone: r.isDone, hasResult: r.hasResult)
    }
}

extension Surface {
    /// Find the UV parameters of a 3D point on this surface.
    ///
    /// Returns nil if the point is beyond maxDistance from the surface.
    public func parametersOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> (
        u: Double, v: Double
    )? {
        var u: Double = 0
        var v: Double = 0
        let ok = OCCTGeomLibToolParametersSurface(
            handle, point.x, point.y, point.z, maxDistance, &u, &v)
        return ok ? (u, v) : nil
    }
}

extension Surface {
    /// Check if this surface is planar within tolerance.
    public func isPlanar(tolerance: Double = 1e-7) -> Bool {
        OCCTGeomLibIsPlanarSurface(handle, tolerance)
    }

    /// If planar, returns the plane parameters: origin, normal, X direction.
    ///
    /// Returns nil if the surface is not planar.
    public func planarPlane(tolerance: Double = 1e-7) -> (
        origin: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>
    )? {
        var ox: Double = 0
        var oy: Double = 0
        var oz: Double = 0
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        var xx: Double = 0
        var xy: Double = 0
        var xz: Double = 0
        let ok = OCCTGeomLibPlanarSurfacePlane(
            handle, tolerance,
            &ox, &oy, &oz, &nx, &ny, &nz, &xx, &xy, &xz)
        guard ok else { return nil }
        return (SIMD3(ox, oy, oz), SIMD3(nx, ny, nz), SIMD3(xx, xy, xz))
    }
}

extension Surface {
    /// Result of surface splitting.
    public struct SplitResult: Sendable {
        public let uSplitCount: Int
        public let vSplitCount: Int
    }

    /// Split this surface by continuity criterion, reporting U and V split counts.
    ///
    /// `criterion` is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3; anything
    /// above asks for CN). It used to be read as a `GeomAbs_Shape` ordinal here — 0=C0, 1=G1,
    /// 2=C1, 3=G2, 4=C2 — even though ``Surface/splitByContinuity(criterion:tolerance:)`` wraps
    /// the same `ShapeUpgrade_SplitSurfaceContinuity` and read the same integer as a parametric
    /// continuity, so `criterion: 2` asked for C1 through one entry point and C2 through the
    /// other. Both now agree. #490.
    ///
    /// ```swift
    /// // Where does this surface drop below C2?
    /// let split = bsplineSurface.splitSurfaceByContinuity(criterion: 2, tolerance: 1e-6)
    /// ```
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

extension Surface {
    /// Attempt to convert this surface to an analytical form, reporting the deviation.
    ///
    /// The detailed spelling of ``Surface/toAnalytical(tolerance:)``: same recognition, same
    /// success and failure cases, plus the gap.
    ///
    /// ```swift
    /// let bspline = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
    ///     .trimmed(u1: 0, u2: .pi, v1: -5, v2: 5)!.toBSpline()!
    /// if let r = bspline.toAnalyticalWithGap(tolerance: 1e-4) {
    ///     print(r.surface.surfaceKind, r.gap)   // .cylinder, ~1e-15
    /// }
    /// ```
    ///
    /// - Parameter tolerance: Recognition tolerance.
    /// - Returns: The recognized surface with its deviation, or nil if not recognizable.
    public func toAnalyticalWithGap(tolerance: Double) -> SurfaceToAnalyticalResult? {
        let result = OCCTGeomConvertSurfToAnalytical(handle, tolerance)
        guard result.success, let surfRef = result.surface else { return nil }
        return SurfaceToAnalyticalResult(surface: Surface(handle: surfRef), gap: result.gap)
    }

    /// Attempt to convert a UV sub-patch of this surface to an analytical form.
    ///
    /// Fits only `[uMin, uMax] × [vMin, vMax]`, so a surface that is a cylinder over part of its
    /// domain can be recognized there even when the whole domain is not. Inverted bounds
    /// (`uMin > uMax`) are rejected rather than normalized.
    ///
    /// ```swift
    /// let d = bsplineSurface.domain
    /// if let r = bsplineSurface.toAnalyticalWithGap(tolerance: 1e-4,
    ///                                               uMin: d.uMin, uMax: (d.uMin + d.uMax) / 2,
    ///                                               vMin: d.vMin, vMax: d.vMax) {
    ///     print(r.surface.surfaceKind)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - tolerance: Recognition tolerance.
    ///   - uMin: Lower U bound of the patch to fit.
    ///   - uMax: Upper U bound of the patch to fit.
    ///   - vMin: Lower V bound of the patch to fit.
    ///   - vMax: Upper V bound of the patch to fit.
    /// - Returns: The recognized surface with its deviation, or nil if not recognizable.
    public func toAnalyticalWithGap(
        tolerance: Double,
        uMin: Double, uMax: Double,
        vMin: Double, vMax: Double
    ) -> SurfaceToAnalyticalResult? {
        let result = OCCTGeomConvertSurfToAnalyticalBounded(
            handle, tolerance, uMin, uMax, vMin, vMax)
        guard result.success, let surfRef = result.surface else { return nil }
        return SurfaceToAnalyticalResult(surface: Surface(handle: surfRef), gap: result.gap)
    }

    /// Check if this surface is already a canonical (analytical) form.
    public var isCanonical: Bool {
        OCCTGeomConvertIsCanonical(handle)
    }
}

extension Surface {
    /// Result of stretch fill operation.
    public struct StretchFillResult {
        public let nbUPoles: Int
        public let nbVPoles: Int
        public let isRational: Bool
        public let poles: [SIMD3<Double>]
    }

    /// Create a stretch-filled surface from 4 boundary point arrays.
    public static func stretchFill(
        p1: [SIMD3<Double>], p2: [SIMD3<Double>],
        p3: [SIMD3<Double>], p4: [SIMD3<Double>]
    ) -> StretchFillResult? {
        let count = p1.count
        guard count == p2.count && count == p3.count && count == p4.count && count >= 2 else {
            return nil
        }

        let flat1 = p1.flatMap { [$0.x, $0.y, $0.z] }
        let flat2 = p2.flatMap { [$0.x, $0.y, $0.z] }
        let flat3 = p3.flatMap { [$0.x, $0.y, $0.z] }
        let flat4 = p4.flatMap { [$0.x, $0.y, $0.z] }

        let maxPoles = 1000
        var outPoles = [Double](repeating: 0, count: maxPoles * 3)
        let r = OCCTGeomFillStretch(
            flat1, flat2, flat3, flat4, Int32(count), &outPoles, Int32(maxPoles))

        guard r.nbUPoles > 0 && r.nbVPoles > 0 else { return nil }
        let totalPoles = Int(r.nbUPoles) * Int(r.nbVPoles)
        let poles = (0..<totalPoles).map { i in
            SIMD3(outPoles[i * 3], outPoles[i * 3 + 1], outPoles[i * 3 + 2])
        }
        return StretchFillResult(
            nbUPoles: Int(r.nbUPoles), nbVPoles: Int(r.nbVPoles),
            isRational: r.isRational, poles: poles)
    }
}

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
    ///
    /// Requires at least 2 curves. `GeomFill_AppSurf`'s underlying approximation solver
    /// (`AppDef_Compute`, reached through `AppBlend_AppSurf::InternalPerform`) is never driven
    /// with fewer than 2 sections anywhere in the kernel; at a single section the first and last
    /// constraint point are the same section evaluated twice, and the solver SIGSEGVs setting up
    /// degree-of-freedom bookkeeping that assumes at least one free interior span (#644, measured:
    /// counts of 0 and 1 crash, 2 and 3 return `isDone: true` cleanly). Matches the guard
    /// `nSections(curves:params:)` and `generatedFromSections(curves:tolerance:)` already carry
    /// for the same `GeomFill_*` section-curve family.
    ///
    /// ```swift
    /// let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)!
    /// let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 5)!
    /// let surf = Surface.appSurf(curves: [c1, c2])
    /// ```
    public static func appSurf(
        curves: [Curve3D], degMin: Int = 3, degMax: Int = 8,
        tol3d: Double = 1e-3, tol2d: Double = 1e-3
    ) -> AppSurfResult? {
        guard curves.count >= 2 else { return nil }
        let refs = curves.map { $0.handle as OCCTCurve3DRef }
        return refs.withUnsafeBufferPointer { buf in
            let r = OCCTGeomFillAppSurf(
                buf.baseAddress!, Int32(curves.count),
                Int32(degMin), Int32(degMax), tol3d, tol2d)
            guard r.isDone else { return nil }
            return AppSurfResult(
                uDegree: Int(r.uDegree), vDegree: Int(r.vDegree),
                nbUPoles: Int(r.nbUPoles), nbVPoles: Int(r.nbVPoles),
                nbUKnots: Int(r.nbUKnots), nbVKnots: Int(r.nbVKnots),
                isDone: r.isDone)
        }
    }
}

extension Surface {
    /// Create a rectangular trimmed surface.
    public static func rectangularTrimmed(
        basis: Surface,
        u1: Double, u2: Double,
        v1: Double, v2: Double
    ) -> Surface? {
        guard let ref = OCCTSurfaceCreateRectangularTrimmed(basis.handle, u1, u2, v1, v2) else {
            return nil
        }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in U direction only.
    public static func trimmedInU(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInU(basis.handle, param1, param2) else {
            return nil
        }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in V direction only.
    public static func trimmedInV(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInV(basis.handle, param1, param2) else {
            return nil
        }
        return Surface(handle: ref)
    }
}

extension Surface {

    /// Convert a sphere to a BSpline surface.
    public static func fromSphere(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double)
        -> Surface?
    {
        guard
            let ref = OCCTConvertSphereToBSplineSurface(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z, radius)
        else { return nil }
        return Surface(handle: ref)
    }
}

extension Surface {

    /// Convert a cylinder patch to a BSpline surface.
    public static func fromCylinder(
        origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
        u1: Double, u2: Double, v1: Double, v2: Double
    ) -> Surface? {
        guard
            let ref = OCCTConvertCylinderToBSplineSurface(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z, radius,
                u1, u2, v1, v2)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a cone patch to a BSpline surface.
    public static func fromCone(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        semiAngle: Double, refRadius: Double,
        u1: Double, u2: Double, v1: Double, v2: Double
    ) -> Surface? {
        guard
            let ref = OCCTConvertConeToBSplineSurface(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z,
                semiAngle, refRadius,
                u1, u2, v1, v2)
        else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a full torus to a BSpline surface.
    public static func fromTorus(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Surface? {
        guard
            let ref = OCCTConvertTorusToBSplineSurface(
                origin.x, origin.y, origin.z,
                axis.x, axis.y, axis.z,
                majorRadius, minorRadius)
        else { return nil }
        return Surface(handle: ref)
    }
}

extension Surface {

    /// Get the offset distance of this surface (only valid if it is an offset surface).
    public var offsetValue: Double {
        OCCTSurfaceOffsetValue(handle)
    }

    /// Set the offset distance of this surface (only has effect on offset surfaces).
    public func setOffsetValue(_ value: Double) {
        OCCTSurfaceSetOffsetValue(handle, value)
    }

    /// Get the basis (underlying) surface of an offset surface.
    ///
    /// Returns nil if this surface is not an offset surface.
    public var offsetBasis: Surface? {
        guard let ref = OCCTSurfaceOffsetBasis(handle) else { return nil }
        return Surface(handle: ref)
    }
}

extension Surface {

    /// Project a 3D point onto this surface using ShapeAnalysis_Surface, returning UV parameters and gap.
    ///
    /// Unlike `projectPoint(_:)` (GeomAPI), this uses ShapeAnalysis for robust projection.
    public func projectPointUV(_ point: SIMD3<Double>, precision: Double = 1e-6) -> (
        u: Double, v: Double, gap: Double
    ) {
        var u = 0.0
        var v = 0.0
        let gap = OCCTSurfaceProjectPointUV(handle, point.x, point.y, point.z, precision, &u, &v)
        return (u, v, gap)
    }

    /// Check if surface has singularities using ShapeAnalysis_Surface at the given precision.
    public func hasSingularitiesSA(precision: Double = 1e-6) -> Bool {
        OCCTSurfaceHasSingularities(handle, precision)
    }

    /// Number of singularities using ShapeAnalysis_Surface.
    public func singularityCountSA(precision: Double = 1e-6) -> Int {
        Int(OCCTSurfaceNbSingularities(handle, precision))
    }

    /// Check if surface is spatially U-closed using ShapeAnalysis_Surface.
    public func isUClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsUClosedSA(handle, precision)
    }

    /// Check if surface is spatially V-closed using ShapeAnalysis_Surface.
    public func isVClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsVClosedSA(handle, precision)
    }
}

extension Surface {
    /// Create a conical surface from axis (center+normal), semi-angle, and reference radius.
    public static func gcConicalSurface(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        semiAngle: Double, radius: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeConicalSurface(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                semiAngle, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 2 points and 2 radii.
    public static func gcConicalSurface2Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        r1: Double, r2: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeConicalSurface2Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                r1, r2)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 4 points (2 on each circle).
    public static func gcConicalSurface4Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>, p4: SIMD3<Double>
    ) -> Surface? {
        guard
            let h = OCCTGCMakeConicalSurface4Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                p3.x, p3.y, p3.z,
                p4.x, p4.y, p4.z)
        else { return nil }
        return Surface(handle: h)
    }
}

extension Surface {
    /// Create a cylindrical surface from axis (center+normal) and radius (GC variant).
    public static func gcCylindricalSurface(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeCylindricalSurface(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from 3 points (GC variant).
    public static func gcCylindricalSurface3Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>
    ) -> Surface? {
        guard
            let h = OCCTGCMakeCylindricalSurface3Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                p3.x, p3.y, p3.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from a circle (center+normal+radius).
    public static func gcCylindricalSurfaceFromCircle(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeCylindricalSurfaceFromCircle(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface parallel to another at a given distance.
    public static func gcCylindricalSurfaceParallel(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double, distance: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeCylindricalSurfaceParallel(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                radius, distance)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from axis (point+direction) and radius.
    public static func gcCylindricalSurfaceAxis(
        point: SIMD3<Double>, direction: SIMD3<Double>,
        radius: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeCylindricalSurfaceAxis(
                point.x, point.y, point.z,
                direction.x, direction.y, direction.z,
                radius)
        else { return nil }
        return Surface(handle: h)
    }
}

extension Surface {
    /// Create a trimmed cone from 2 points and 2 radii.
    public static func gcTrimmedCone2Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        r1: Double, r2: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeTrimmedCone2Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                r1, r2)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cone from 4 points.
    public static func gcTrimmedCone4Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>, p4: SIMD3<Double>
    ) -> Surface? {
        guard
            let h = OCCTGCMakeTrimmedCone4Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                p3.x, p3.y, p3.z,
                p4.x, p4.y, p4.z)
        else { return nil }
        return Surface(handle: h)
    }
}

extension Surface {
    /// Create a trimmed cylinder from a circle (center+normal+radius) and height.
    public static func gcTrimmedCylinderCircle(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double, height: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeTrimmedCylinderCircle(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                radius, height)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from axis (point+direction), radius, and height.
    public static func gcTrimmedCylinderAxis(
        point: SIMD3<Double>, direction: SIMD3<Double>,
        radius: Double, height: Double
    ) -> Surface? {
        guard
            let h = OCCTGCMakeTrimmedCylinderAxis(
                point.x, point.y, point.z,
                direction.x, direction.y, direction.z,
                radius, height)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from 3 points.
    public static func gcTrimmedCylinder3Pts(
        p1: SIMD3<Double>, p2: SIMD3<Double>,
        p3: SIMD3<Double>
    ) -> Surface? {
        guard
            let h = OCCTGCMakeTrimmedCylinder3Pts(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                p3.x, p3.y, p3.z)
        else { return nil }
        return Surface(handle: h)
    }
}

extension Surface {
    /// Measured global continuity of the surface, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order — `0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN` — not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// - Warning: The migration target for the retired `surfaceContinuityOrder`, but not a
    ///   drop-in one — see ``Curve3D/continuity`` for the constants that shift (#619).
    public var continuity: Int {
        Int(OCCTSurfaceGetContinuity(handle))
    }

    /// Get number of UV bound spans for the surface.
    public var nBounds: (uSpans: Int, vSpans: Int) {
        var u: Int32 = 0
        var v: Int32 = 0
        OCCTSurfaceGetNBounds(handle, &u, &v)
        return (Int(u), Int(v))
    }
}

extension Surface {

    /// BSpline-specific surface operations.
    public struct BSpline {
        let surface: Surface

        /// Number of U knots.
        public var nbUKnots: Int { Int(OCCTSurfaceBSplineNbUKnots(surface.handle)) }

        /// Number of V knots.
        public var nbVKnots: Int { Int(OCCTSurfaceBSplineNbVKnots(surface.handle)) }

        /// Number of U poles.
        public var nbUPoles: Int { Int(OCCTSurfaceBSplineNbUPoles(surface.handle)) }

        /// Number of V poles.
        public var nbVPoles: Int { Int(OCCTSurfaceBSplineNbVPoles(surface.handle)) }

        /// U degree.
        public var uDegree: Int { Int(OCCTSurfaceBSplineUDegree(surface.handle)) }

        /// V degree.
        public var vDegree: Int { Int(OCCTSurfaceBSplineVDegree(surface.handle)) }

        /// Whether the surface is U-rational.
        public var isURational: Bool { OCCTSurfaceBSplineIsURational(surface.handle) }

        /// Whether the surface is V-rational.
        public var isVRational: Bool { OCCTSurfaceBSplineIsVRational(surface.handle) }

        /// Get a pole at (uIndex, vIndex) — both 1-based.
        public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double> {
            unwrapVectorComponents {
                OCCTSurfaceBSplineGetPole(surface.handle, Int32(uIndex), Int32(vIndex), $0, $1, $2)
            }
        }

        /// Set a pole at (uIndex, vIndex) — both 1-based.
        @discardableResult
        public func setPole(uIndex: Int, vIndex: Int, to point: SIMD3<Double>) -> Bool {
            OCCTSurfaceBSplineSetPole(
                surface.handle, Int32(uIndex), Int32(vIndex), point.x, point.y, point.z)
        }

        /// Set the weight at (uIndex, vIndex).
        @discardableResult
        public func setWeight(uIndex: Int, vIndex: Int, to weight: Double) -> Bool {
            OCCTSurfaceBSplineSetWeight(surface.handle, Int32(uIndex), Int32(vIndex), weight)
        }

        /// Insert a U knot.
        @discardableResult
        public func insertUKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
        {
            OCCTSurfaceBSplineInsertUKnot(surface.handle, u, Int32(multiplicity), tolerance)
        }

        /// Insert a V knot.
        @discardableResult
        public func insertVKnot(v: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool
        {
            OCCTSurfaceBSplineInsertVKnot(surface.handle, v, Int32(multiplicity), tolerance)
        }

        /// Segment the surface to [u1,u2] x [v1,v2].
        @discardableResult
        public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool {
            OCCTSurfaceBSplineSegment(surface.handle, u1, u2, v1, v2)
        }

        /// Increase the degree to (uDeg, vDeg).
        @discardableResult
        public func increaseDegree(uDeg: Int, vDeg: Int) -> Bool {
            OCCTSurfaceBSplineIncreaseDegree(surface.handle, Int32(uDeg), Int32(vDeg))
        }

        /// Exchange U and V directions.
        @discardableResult
        public func exchangeUV() -> Bool {
            OCCTSurfaceBSplineExchangeUV(surface.handle)
        }
    }

    /// Access BSpline-specific surface operations.
    ///
    /// Works only if the underlying surface is a Geom_BSplineSurface.
    public var bsplineSurface: BSpline { BSpline(surface: self) }
}

extension Surface {

    /// Get the parameter bounds of the surface.
    public var parameterBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin = 0.0
        var uMax = 0.0
        var vMin = 0.0
        var vMax = 0.0
        OCCTSurfaceBounds(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it.
    ///
    /// Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Same retirement, same reasons, as ``Curve3D/continuityOrder``: the pre-#485 encoding was
    /// `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` and the value is now the real
    /// `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`), so every threshold
    /// check kept compiling and quietly changed meaning (#619).
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1, and an analytic surface answers 6, never 99.
    /// if surface.surfaceContinuityOrder >= 2 { offsetSafely() }
    ///
    /// // Ask it so it cannot drift again:
    /// if surface.continuityClass.satisfies(.c2) { offsetSafely() }
    /// ```
    @available(
        *, unavailable,
        message: """
            surfaceContinuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, \
            G1=-2, G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, \
            G2=3, C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
            continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
            analytic fast path, or continuity for the raw ordinal. Whichever you use, re-check the \
            constant you compare against. Note there is no longer an error sentinel: this returned \
            -1 for a null or unreadable handle, whereas continuity returns 0, which is an ordinary \
            C0, so a \
            migrated `< 0` error check can never fire (#619).
            """
    )
    public var surfaceContinuityOrder: Int { Int(OCCTSurfaceGetContinuity(handle)) }

    /// Create a deep copy of this surface.
    public func copy() -> Surface? {
        guard let ref = OCCTSurfaceCopy(handle) else { return nil }
        return Surface(handle: ref)
    }
}

extension Surface {

    /// Evaluate the surface point at (u, v).
    public func evalD0(u: Double, v: Double) -> SIMD3<Double> {
        unwrapVectorComponents { OCCTSurfaceEvalD0(handle, u, v, $0, $1, $2) }
    }

    /// Evaluate the surface point and first partial derivatives at (u, v).
    public func evalD1(u: Double, v: Double) -> (
        point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1ux = 0.0
        var d1uy = 0.0
        var d1uz = 0.0
        var d1vx = 0.0
        var d1vy = 0.0
        var d1vz = 0.0
        OCCTSurfaceEvalD1(handle, u, v, &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz))
    }

    /// Evaluate the surface point, first and second partial derivatives at (u, v).
    public func evalD2(u: Double, v: Double) -> (
        point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>, d2u: SIMD3<Double>,
        d2v: SIMD3<Double>, d2uv: SIMD3<Double>
    ) {
        var px = 0.0
        var py = 0.0
        var pz = 0.0
        var d1ux = 0.0
        var d1uy = 0.0
        var d1uz = 0.0
        var d1vx = 0.0
        var d1vy = 0.0
        var d1vz = 0.0
        var d2ux = 0.0
        var d2uy = 0.0
        var d2uz = 0.0
        var d2vx = 0.0
        var d2vy = 0.0
        var d2vz = 0.0
        var d2uvx = 0.0
        var d2uvy = 0.0
        var d2uvz = 0.0
        OCCTSurfaceEvalD2(
            handle, u, v, &px, &py, &pz,
            &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
            &d2uvx, &d2uvy, &d2uvz)
        return (
            SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
            SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz)
        )
    }
}

extension Surface {

    /// The geometric surface type (0=Plane, 1=Cylinder, 2=Cone, 3=Sphere, 4=Torus, ..., 10=OtherSurface).
    public var surfaceType: Int {
        Int(OCCTSurfaceGetType(handle))
    }
}

extension Surface {

    /// Local point-on-surface search from initial (u,v) guess.
    ///
    /// Returns (u, v, distance).
    public func locateNearestPoint(
        _ point: SIMD3<Double>, initU: Double, initV: Double, tolerance: Double = 1e-6
    ) -> (u: Double, v: Double, distance: Double)? {
        var u = 0.0
        var v = 0.0
        var dist = 0.0
        let ok = OCCTExtremaLocateOnSurface(
            handle, point.x, point.y, point.z,
            initU, initV, tolerance, &u, &v, &dist)
        return ok ? (u, v, dist) : nil
    }

    /// Global point-to-surface projection returning all extrema.
    ///
    /// Returns array of (u, v, distance).
    ///
    /// - Parameters:
    ///   - point: The 3D point to project.
    ///   - maxResults: Output *capacity* (default 10), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Every extremum found, up to `maxResults`.
    public func projectPointAll(_ point: SIMD3<Double>, maxResults: Int = 10) -> [(
        u: Double, v: Double, distance: Double
    )] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var us = [Double](repeating: 0, count: maxResults)
        var vs = [Double](repeating: 0, count: maxResults)
        var distances = [Double](repeating: 0, count: maxResults)
        let n = Int(
            OCCTExtremaPointSurface(
                handle, point.x, point.y, point.z,
                &us, &vs, &distances, Int32(maxResults)))
        return (0..<n).map { (us[$0], vs[$0], distances[$0]) }
    }
}

extension Surface {

    /// Set U knot at given index (1-based).
    public func bsplineSetUKnot(index: Int, value: Double) -> Bool {
        OCCTSurfaceBSplineSetUKnot(handle, Int32(index), value)
    }

    /// Set V knot at given index (1-based).
    public func bsplineSetVKnot(index: Int, value: Double) -> Bool {
        OCCTSurfaceBSplineSetVKnot(handle, Int32(index), value)
    }

    /// Get all U knots.
    public func bsplineUKnots() -> [Double] {
        let n = Int(OCCTSurfaceBSplineNbUKnots(handle))
        guard n > 0 else { return [] }
        var knots = [Double](repeating: 0, count: n)
        OCCTSurfaceBSplineGetUKnots(handle, &knots)
        return knots
    }

    /// Get all V knots.
    public func bsplineVKnots() -> [Double] {
        let n = Int(OCCTSurfaceBSplineNbVKnots(handle))
        guard n > 0 else { return [] }
        var knots = [Double](repeating: 0, count: n)
        OCCTSurfaceBSplineGetVKnots(handle, &knots)
        return knots
    }

    /// Get all weights (row-major, NbUPoles x NbVPoles).
    public func bsplineWeights() -> (weights: [Double], rows: Int, cols: Int) {
        let maxSize = 10000
        var weights = [Double](repeating: 0, count: maxSize)
        var rows: Int32 = 0
        var cols: Int32 = 0
        OCCTSurfaceBSplineGetWeights(handle, &weights, &rows, &cols)
        return (Array(weights.prefix(Int(rows) * Int(cols))), Int(rows), Int(cols))
    }

    /// Remove a U knot.
    ///
    /// Returns true if successful.
    public func bsplineRemoveUKnot(index: Int, multiplicity: Int, tolerance: Double) -> Bool {
        OCCTSurfaceBSplineRemoveUKnot(handle, Int32(index), Int32(multiplicity), tolerance)
    }
}

extension Surface {

    /// Evaluate the (Nu, Nv) partial derivative at (u, v).
    public func dn(u: Double, v: Double, nu: Int, nv: Int) -> SIMD3<Double> {
        unwrapVectorComponents { OCCTSurfaceDN(handle, u, v, Int32(nu), Int32(nv), $0, $1, $2) }
    }

    /// The type name of this surface (e.g. "Geom_Plane", "Geom_BSplineSurface").
    public var typeName: String? {
        guard let ptr = OCCTSurfaceTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

extension Surface {

    /// Surface curvature result at a point.
    public struct LocalCurvatures: Sendable {
        public let gaussian: Double
        public let mean: Double
        public let maxCurvature: Double
        public let minCurvature: Double
    }

    /// All four curvature scalars at a surface point, in one call.
    ///
    /// The same quantities ``Surface/curvatures(u:v:)``, ``Surface/gaussianCurvature(atU:v:)``,
    /// ``Surface/meanCurvature(atU:v:)`` and ``Surface/principalCurvatures(atU:v:)`` report, and
    /// now at the same tolerance — this used to ask at a 1000x tighter resolution, so it could
    /// report curvature near a degeneracy that every one of those called undefined (#494).
    ///
    /// - Parameters:
    ///   - u: Surface U parameter.
    ///   - v: Surface V parameter.
    /// - Returns: Gaussian, mean, max and min curvature, or `nil` where curvature is undefined —
    ///   a cone's apex, a sphere's pole, or any point whose surface normal is not defined.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 10)!
    /// if let c = sphere.localCurvatures(u: 0, v: 0.5) {
    ///     print(c.gaussian)      // 1/R^2 = 0.01
    ///     print(abs(c.mean))     // 1/R   = 0.1
    /// }
    ///
    /// // A cone's apex has no defined curvature.
    /// let cone = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    /// #expect(cone.localCurvatures(u: 0, v: 0) == nil)
    /// ```
    public func localCurvatures(u: Double, v: Double) -> LocalCurvatures? {
        var gaussian = 0.0
        var mean = 0.0
        var maxC = 0.0
        var minC = 0.0
        var isDefined = false
        OCCTSurfaceLocalCurvatures(handle, u, v, &gaussian, &mean, &maxC, &minC, &isDefined)
        return isDefined
            ? LocalCurvatures(
                gaussian: gaussian, mean: mean,
                maxCurvature: maxC, minCurvature: minC) : nil
    }

    /// Curvature direction result.
    public struct CurvatureDirections: Sendable {
        public let maxDirection: SIMD3<Double>
        public let minDirection: SIMD3<Double>
    }

    /// The principal curvature directions at a surface point.
    ///
    /// Shares its tolerance with ``Surface/principalCurvatures(atU:v:)``, which reports the same
    /// two directions alongside their curvatures; the two used to disagree about where curvature
    /// exists at all (#494).
    ///
    /// - Parameters:
    ///   - u: Surface U parameter.
    ///   - v: Surface V parameter.
    /// - Returns: The max- and min-curvature directions, or `nil` where curvature is undefined
    ///   **or** the point is umbilic, since equal principal curvatures single out no pair of
    ///   directions.
    ///
    /// Umbilic detection is OCCT's, and it is stricter than the geometry suggests: the two
    /// principal curvatures must land within one ULP of each other. A plane qualifies (both are
    /// exactly zero); an analytically-umbilic sphere qualifies only where the two computed values
    /// round to the same `Double`, which varies with radius and parameter. Treat a non-`nil`
    /// result on a sphere as normal, not as a bug.
    ///
    /// ```swift
    /// // A cylinder is not umbilic: one direction follows the axis, the other wraps around it.
    /// let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
    /// if let d = cylinder.localCurvatureDirections(u: 0, v: 0) {
    ///     print(d.maxDirection, d.minDirection)
    /// }
    ///
    /// // A plane is umbilic everywhere, so it has directions nowhere — but its curvature is
    /// // perfectly well defined (all four scalars are zero).
    /// let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
    /// #expect(plane.localCurvatures(u: 1, v: 2) != nil)
    /// #expect(plane.localCurvatureDirections(u: 1, v: 2) == nil)
    /// ```
    public func localCurvatureDirections(u: Double, v: Double) -> CurvatureDirections? {
        var maxDx = 0.0
        var maxDy = 0.0
        var maxDz = 0.0
        var minDx = 0.0
        var minDy = 0.0
        var minDz = 0.0
        var isDefined = false
        OCCTSurfaceLocalCurvatureDirections(
            handle, u, v,
            &maxDx, &maxDy, &maxDz,
            &minDx, &minDy, &minDz, &isDefined)
        return isDefined
            ? CurvatureDirections(
                maxDirection: SIMD3(maxDx, maxDy, maxDz),
                minDirection: SIMD3(minDx, minDy, minDz)) : nil
    }
}

extension Surface {
    /// Bezier surface properties (meaningful only when the underlying surface is Geom_BezierSurface).
    public struct BezierProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// Number of U poles.
        public var nbUPoles: Int { Int(OCCTSurfaceBezierNbUPoles(handle)) }

        /// Number of V poles.
        public var nbVPoles: Int { Int(OCCTSurfaceBezierNbVPoles(handle)) }

        /// U degree.
        public var uDegree: Int { Int(OCCTSurfaceBezierUDegree(handle)) }

        /// V degree.
        public var vDegree: Int { Int(OCCTSurfaceBezierVDegree(handle)) }

        /// Whether the surface is rational in U.
        public var isURational: Bool { OCCTSurfaceBezierIsURational(handle) }

        /// Whether the surface is rational in V.
        public var isVRational: Bool { OCCTSurfaceBezierIsVRational(handle) }

        /// Get a pole (1-based indices).
        public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double> {
            unwrapVectorComponents {
                OCCTSurfaceBezierGetPole(handle, Int32(uIndex), Int32(vIndex), $0, $1, $2)
            }
        }

        /// Set a pole (1-based indices).
        @discardableResult
        public func setPole(uIndex: Int, vIndex: Int, point: SIMD3<Double>) -> Bool {
            OCCTSurfaceBezierSetPole(
                handle, Int32(uIndex), Int32(vIndex), point.x, point.y, point.z)
        }

        /// Set a weight (1-based indices).
        @discardableResult
        public func setWeight(uIndex: Int, vIndex: Int, weight: Double) -> Bool {
            OCCTSurfaceBezierSetWeight(handle, Int32(uIndex), Int32(vIndex), weight)
        }

        /// Extract a segment of the Bezier surface.
        @discardableResult
        public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool {
            OCCTSurfaceBezierSegment(handle, u1, u2, v1, v2)
        }

        /// Exchange U and V parametric directions.
        @discardableResult
        public func exchangeUV() -> Bool {
            OCCTSurfaceBezierExchangeUV(handle)
        }
    }

    /// Bezier-surface-specific properties.
    public var bezierProperties: BezierProperties { BezierProperties(handle: handle) }

    // --- BSplineSurface extras ---

    /// Compute U and V parameter resolution for a given 3D tolerance (BSpline surface).
    public func bsplineResolution(tolerance3d: Double) -> (uResolution: Double, vResolution: Double)
    {
        var ur = 0.0
        var vr = 0.0
        OCCTSurfaceBSplineResolution(handle, tolerance3d, &ur, &vr)
        return (ur, vr)
    }

    /// Set U periodicity on a BSpline surface.
    @discardableResult
    public func bsplineSetUPeriodic(_ periodic: Bool) -> Bool {
        OCCTSurfaceBSplineSetUPeriodic(handle, periodic)
    }

    /// Set V periodicity on a BSpline surface.
    @discardableResult
    public func bsplineSetVPeriodic(_ periodic: Bool) -> Bool {
        OCCTSurfaceBSplineSetVPeriodic(handle, periodic)
    }

    /// Get a weight from a BSpline surface (1-based indices).
    public func bsplineWeight(uIndex: Int, vIndex: Int) -> Double {
        OCCTSurfaceBSplineGetWeight(handle, Int32(uIndex), Int32(vIndex))
    }
}

extension Surface {

    /// Check if this surface has at least Cn continuity in the U direction.
    public func isCNu(_ n: Int) -> Bool {
        OCCTSurfaceIsCNu(handle, Int32(n))
    }

    /// Check if this surface has at least Cn continuity in the V direction.
    public func isCNv(_ n: Int) -> Bool {
        OCCTSurfaceIsCNv(handle, Int32(n))
    }

    /// Create a U-reversed copy of this surface.
    public func uReversed() -> Surface? {
        guard let ref = OCCTSurfaceUReversed(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a V-reversed copy of this surface.
    public func vReversed() -> Surface? {
        guard let ref = OCCTSurfaceVReversed(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get the reversed U parameter value.
    public func uReversedParameter(_ u: Double) -> Double {
        OCCTSurfaceUReversedParameter(handle, u)
    }

    /// Get the reversed V parameter value.
    public func vReversedParameter(_ v: Double) -> Double {
        OCCTSurfaceVReversedParameter(handle, v)
    }

    /// Remove a V knot from a BSpline surface.
    ///
    /// Returns true if successful.
    @discardableResult
    public func bsplineRemoveVKnot(index: Int, mult: Int, tolerance: Double) -> Bool {
        OCCTSurfaceBSplineRemoveVKnot(handle, Int32(index), Int32(mult), tolerance)
    }

    /// Resolution for Bezier surfaces (U and V).
    public func bezierResolution(tolerance3d: Double) -> (u: Double, v: Double) {
        var ur = 0.0
        var vr = 0.0
        OCCTSurfaceBezierResolution(handle, tolerance3d, &ur, &vr)
        return (ur, vr)
    }

    /// Maximum degree for Bezier surfaces (static).
    public static var bezierMaxDegree: Int { Int(OCCTSurfaceBezierMaxDegree()) }

    /// Maximum degree for BSpline surfaces (static).
    public static var bsplineMaxDegree: Int { Int(OCCTSurfaceBSplineMaxDegree()) }
}

extension Surface {

    /// Remove U periodicity from BSpline surface.
    @discardableResult
    public func bsplineSetUNotPeriodic() -> Bool {
        OCCTSurfaceBSplineSetUNotPeriodic(handle)
    }

    /// Remove V periodicity from BSpline surface.
    @discardableResult
    public func bsplineSetVNotPeriodic() -> Bool {
        OCCTSurfaceBSplineSetVNotPeriodic(handle)
    }

    /// Set origin knot index in U direction (1-based).
    @discardableResult
    public func bsplineSetUOrigin(index: Int) -> Bool {
        OCCTSurfaceBSplineSetUOrigin(handle, Int32(index))
    }

    /// Set origin knot index in V direction (1-based).
    @discardableResult
    public func bsplineSetVOrigin(index: Int) -> Bool {
        OCCTSurfaceBSplineSetVOrigin(handle, Int32(index))
    }

    /// Increase U multiplicity at knot index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseUMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTSurfaceBSplineIncreaseUMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increase V multiplicity at knot index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseVMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTSurfaceBSplineIncreaseVMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Batch insert U knots with multiplicities.
    @discardableResult
    public func bsplineInsertUKnots(
        _ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10
    ) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTSurfaceBSplineInsertUKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Batch insert V knots with multiplicities.
    @discardableResult
    public func bsplineInsertVKnots(
        _ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10
    ) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTSurfaceBSplineInsertVKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Move BSpline surface to pass through point at (u,v), adjusting poles in range.
    @discardableResult
    public func bsplineMovePoint(
        u: Double, v: Double, to point: SIMD3<Double>,
        uPoleRange: ClosedRange<Int>, vPoleRange: ClosedRange<Int>
    ) -> Bool {
        OCCTSurfaceBSplineMovePoint(
            handle, u, v, point.x, point.y, point.z,
            Int32(uPoleRange.lowerBound), Int32(uPoleRange.upperBound),
            Int32(vPoleRange.lowerBound), Int32(vPoleRange.upperBound))
    }

    /// Set an entire column of poles (all U poles at vIndex, 1-based). coords is [x,y,z,...] with count = NbUPoles.
    @discardableResult
    public func bsplineSetPoleCol(vIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let coords = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBSplineSetPoleCol(handle, Int32(vIndex), coords, Int32(poles.count))
    }

    /// Set an entire row of poles (all V poles at uIndex, 1-based). coords is [x,y,z,...] with count = NbVPoles.
    @discardableResult
    public func bsplineSetPoleRow(uIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let coords = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBSplineSetPoleRow(handle, Int32(uIndex), coords, Int32(poles.count))
    }

    // --- v0.129.0 BSplineSurface completions ---

    /// Set a column of weights on BSpline surface. vIndex is 1-based, count = NbUPoles.
    @discardableResult
    public func bsplineSetWeightCol(vIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBSplineSetWeightCol(handle, Int32(vIndex), weights, Int32(weights.count))
    }

    /// Set a row of weights on BSpline surface. uIndex is 1-based, count = NbVPoles.
    @discardableResult
    public func bsplineSetWeightRow(uIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBSplineSetWeightRow(handle, Int32(uIndex), weights, Int32(weights.count))
    }

    /// Increment U knot multiplicities in range [fromIndex, toIndex] by step.
    @discardableResult
    public func bsplineIncrementUMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool {
        OCCTSurfaceBSplineIncrementUMultiplicity(
            handle, Int32(fromIndex), Int32(toIndex), Int32(step))
    }

    /// Increment V knot multiplicities in range [fromIndex, toIndex] by step.
    @discardableResult
    public func bsplineIncrementVMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool {
        OCCTSurfaceBSplineIncrementVMultiplicity(
            handle, Int32(fromIndex), Int32(toIndex), Int32(step))
    }

    /// First U knot index of BSpline surface.
    public var bsplineFirstUKnotIndex: Int { Int(OCCTSurfaceBSplineFirstUKnotIndex(handle)) }

    /// Last U knot index of BSpline surface.
    public var bsplineLastUKnotIndex: Int { Int(OCCTSurfaceBSplineLastUKnotIndex(handle)) }

    /// First V knot index of BSpline surface.
    public var bsplineFirstVKnotIndex: Int { Int(OCCTSurfaceBSplineFirstVKnotIndex(handle)) }

    /// Last V knot index of BSpline surface.
    public var bsplineLastVKnotIndex: Int { Int(OCCTSurfaceBSplineLastVKnotIndex(handle)) }

    /// Validate parameter ranges and segment the BSpline surface.
    @discardableResult
    public func bsplineCheckAndSegment(
        u1: Double, u2: Double, v1: Double, v2: Double,
        uTolerance: Double = 1e-10, vTolerance: Double = 1e-10
    ) -> Bool {
        OCCTSurfaceBSplineCheckAndSegment(handle, u1, u2, v1, v2, uTolerance, vTolerance)
    }
}

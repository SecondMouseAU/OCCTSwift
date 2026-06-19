import Foundation
import simd
import OCCTBridge

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
        case plane = 0, cylinder = 1, cone = 2, sphere = 3, torus = 4
        case bezierSurface = 5, bsplineSurface = 6
        case surfaceOfRevolution = 7, surfaceOfExtrusion = 8
        case offsetSurface = 9, other = 10
    }

    /// The specific geometric kind of this surface (Geom subclass).
    public var surfaceKind: SurfaceType {
        SurfaceType(rawValue: OCCTSurfaceGetType(handle)) ?? .other
    }

    /// Surface continuity class, derived from GeomAbs_Shape.
    public enum Continuity: Int32, Sendable, CaseIterable {
        case c0 = 0, g1 = 1, c1 = 2, g2 = 3, c2 = 4, c3 = 5, cN = 6
    }

    /// Typed overall continuity of the surface (wraps the Int-returning `continuity`).
    public var continuityClass: Continuity {
        Continuity(rawValue: OCCTSurfaceGetContinuity(handle)) ?? .c0
    }

    public var isPlane:              Bool { surfaceKind == .plane }
    public var isCylinder:           Bool { surfaceKind == .cylinder }
    public var isCone:               Bool { surfaceKind == .cone }
    public var isSphere:             Bool { surfaceKind == .sphere }
    public var isTorus:              Bool { surfaceKind == .torus }
    public var isBezier:             Bool { surfaceKind == .bezierSurface }
    public var isBSpline:            Bool { surfaceKind == .bsplineSurface }
    public var isSurfaceOfRevolution:Bool { surfaceKind == .surfaceOfRevolution }
    public var isSurfaceOfExtrusion: Bool { surfaceKind == .surfaceOfExtrusion }
    public var isOffsetSurface:      Bool { surfaceKind == .offsetSurface }

    /// Parameter domain (uMin, uMax, vMin, vMax)
    public var domain: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin: Double = 0, uMax: Double = 0, vMin: Double = 0, vMax: Double = 0
        OCCTSurfaceGetDomain(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Whether the surface is closed in U direction
    public var isUClosed: Bool {
        OCCTSurfaceIsUClosed(handle)
    }

    /// Whether the surface is closed in V direction
    public var isVClosed: Bool {
        OCCTSurfaceIsVClosed(handle)
    }

    /// Whether the surface is periodic in U direction
    public var isUPeriodic: Bool {
        OCCTSurfaceIsUPeriodic(handle)
    }

    /// Whether the surface is periodic in V direction
    public var isVPeriodic: Bool {
        OCCTSurfaceIsVPeriodic(handle)
    }

    /// Period in U direction (nil if not periodic)
    public var uPeriod: Double? {
        guard isUPeriodic else { return nil }
        return OCCTSurfaceGetUPeriod(handle)
    }

    /// Period in V direction (nil if not periodic)
    public var vPeriod: Double? {
        guard isVPeriodic else { return nil }
        return OCCTSurfaceGetVPeriod(handle)
    }

    // MARK: - Evaluation

    /// Evaluate surface point at (u, v)
    public func point(atU u: Double, v: Double) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTSurfaceGetPoint(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// First-order derivatives at (u, v)
    public func d1(atU u: Double, v: Double) -> (point: SIMD3<Double>, du: SIMD3<Double>, dv: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var dux: Double = 0, duy: Double = 0, duz: Double = 0
        var dvx: Double = 0, dvy: Double = 0, dvz: Double = 0
        OCCTSurfaceD1(handle, u, v, &px, &py, &pz, &dux, &duy, &duz, &dvx, &dvy, &dvz)
        return (SIMD3(px, py, pz), SIMD3(dux, duy, duz), SIMD3(dvx, dvy, dvz))
    }

    /// Second-order derivatives at (u, v)
    public func d2(atU u: Double, v: Double) -> (
        point: SIMD3<Double>,
        d1u: SIMD3<Double>, d1v: SIMD3<Double>,
        d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>
    ) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var d1ux: Double = 0, d1uy: Double = 0, d1uz: Double = 0
        var d1vx: Double = 0, d1vy: Double = 0, d1vz: Double = 0
        var d2ux: Double = 0, d2uy: Double = 0, d2uz: Double = 0
        var d2vx: Double = 0, d2vy: Double = 0, d2vz: Double = 0
        var d2uvx: Double = 0, d2uvy: Double = 0, d2uvz: Double = 0
        OCCTSurfaceD2(handle, u, v, &px, &py, &pz,
                       &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                       &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                       &d2uvx, &d2uvy, &d2uvz)
        return (SIMD3(px, py, pz),
                SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz),
                SIMD3(d2uvx, d2uvy, d2uvz))
    }

    /// Surface normal at (u, v)
    public func normal(atU u: Double, v: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTSurfaceGetNormal(handle, u, v, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    // MARK: - Analytic Surfaces

    /// Create an infinite plane from a point and normal direction
    public static func plane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreatePlane(origin.x, origin.y, origin.z,
                                              normal.x, normal.y, normal.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface
    public static func cylinder(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateCylinder(origin.x, origin.y, origin.z,
                                                 axis.x, axis.y, axis.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface
    public static func cone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                            radius: Double, semiAngle: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateCone(origin.x, origin.y, origin.z,
                                             axis.x, axis.y, axis.z,
                                             radius, semiAngle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a spherical surface
    public static func sphere(center: SIMD3<Double>, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateSphere(center.x, center.y, center.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a toroidal surface
    public static func torus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                             majorRadius: Double, minorRadius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateTorus(origin.x, origin.y, origin.z,
                                              axis.x, axis.y, axis.z,
                                              majorRadius, minorRadius)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Swept Surfaces

    /// Create a surface by extruding a curve along a direction
    public static func extrusion(profile: Curve3D, direction: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreateExtrusion(profile.handle,
                                                  direction.x, direction.y, direction.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a surface of revolution by revolving a curve around an axis
    public static func revolution(meridian: Curve3D,
                                  axisOrigin: SIMD3<Double>,
                                  axisDirection: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreateRevolution(meridian.handle,
                                                   axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                   axisDirection.x, axisDirection.y, axisDirection.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Freeform Surfaces

    /// Create a Bezier surface from control points
    /// - Parameters:
    ///   - poles: 2D array of control points [uRow][vCol]
    ///   - weights: Optional 2D array of weights (same dimensions as poles)
    public static func bezier(poles: [[SIMD3<Double>]],
                              weights: [[Double]]? = nil) -> Surface? {
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
                    OCCTSurfaceCreateBezier(pPtr.baseAddress, uCount, vCount,
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

    /// Create a BSpline surface
    /// - Parameters:
    ///   - poles: 2D array of control points [uRow][vCol]
    ///   - weights: Optional 2D array of weights
    ///   - knotsU: Knot values in U direction
    ///   - multiplicitiesU: Knot multiplicities in U direction
    ///   - knotsV: Knot values in V direction
    ///   - multiplicitiesV: Knot multiplicities in V direction
    ///   - degreeU: Polynomial degree in U
    ///   - degreeV: Polynomial degree in V
    public static func bspline(poles: [[SIMD3<Double>]],
                               weights: [[Double]]? = nil,
                               knotsU: [Double], multiplicitiesU: [Int32],
                               knotsV: [Double], multiplicitiesV: [Int32],
                               degreeU: Int, degreeV: Int) -> Surface? {
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

    /// Create a rectangular trim of this surface
    public func trimmed(u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let h = OCCTSurfaceTrim(handle, u1, u2, v1, v2) else { return nil }
        return Surface(handle: h)
    }

    /// Create an offset surface at a given distance from this surface
    public func offset(distance: Double) -> Surface? {
        guard let h = OCCTSurfaceOffset(handle, distance) else { return nil }
        return Surface(handle: h)
    }

    /// Translated copy
    public func translated(by delta: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceTranslate(handle, delta.x, delta.y, delta.z) else { return nil }
        return Surface(handle: h)
    }

    /// Rotated copy around an axis
    public func rotated(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
                        angle: Double) -> Surface? {
        guard let h = OCCTSurfaceRotate(handle,
                                         axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                         axisDirection.x, axisDirection.y, axisDirection.z,
                                         angle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Scaled copy from a center point
    public func scaled(center: SIMD3<Double>, factor: Double) -> Surface? {
        guard let h = OCCTSurfaceScale(handle, center.x, center.y, center.z, factor)
        else { return nil }
        return Surface(handle: h)
    }

    /// Mirrored copy across a plane
    public func mirrored(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceMirrorPlane(handle,
                                              planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                              planeNormal.x, planeNormal.y, planeNormal.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Conversion

    /// Convert to BSpline representation
    public func toBSpline() -> Surface? {
        guard let h = OCCTSurfaceToBSpline(handle) else { return nil }
        return Surface(handle: h)
    }

    /// Approximate as a BSpline surface within tolerance
    public func approximated(tolerance: Double = 0.01, continuity: Int = 2,
                             maxSegments: Int = 100, maxDegree: Int = 10) -> Surface? {
        guard let h = OCCTSurfaceApproximate(handle, tolerance, Int32(continuity),
                                              Int32(maxSegments), Int32(maxDegree))
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Iso Curves

    /// Extract a U-iso curve (constant U, varying V)
    public func uIso(at u: Double) -> Curve3D? {
        guard let h = OCCTSurfaceUIso(handle, u) else { return nil }
        return Curve3D(handle: h)
    }

    /// Extract a V-iso curve (constant V, varying U)
    public func vIso(at v: Double) -> Curve3D? {
        guard let h = OCCTSurfaceVIso(handle, v) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - Pipe Surfaces

    /// Create a pipe surface by sweeping a circle along a path
    public static func pipe(path: Curve3D, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreatePipe(path.handle, radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a pipe surface by sweeping a section curve along a path
    public static func pipe(path: Curve3D, section: Curve3D) -> Surface? {
        guard let h = OCCTSurfaceCreatePipeWithSection(path.handle, section.handle)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Draw Methods

    /// Draw iso-parameter grid lines for Metal visualization
    /// - Parameters:
    ///   - uLineCount: Number of U-iso lines
    ///   - vLineCount: Number of V-iso lines
    ///   - pointsPerLine: Points per iso line
    /// - Returns: Array of polylines, each a [SIMD3<Double>]
    public func drawGrid(uLineCount: Int = 10, vLineCount: Int = 10,
                         pointsPerLine: Int = 50) -> [[SIMD3<Double>]] {
        let maxLines = uLineCount + vLineCount
        let maxPoints = maxLines * pointsPerLine
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        var lineLengths = [Int32](repeating: 0, count: maxLines)

        let totalPoints = Int(OCCTSurfaceDrawGrid(
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

    /// Sample a uniform mesh grid of points for Metal visualization
    /// - Returns: 2D array [uIndex][vIndex] of surface points
    public func drawMesh(uCount: Int = 20, vCount: Int = 20) -> [[SIMD3<Double>]] {
        let total = uCount * vCount
        var buffer = [Double](repeating: 0, count: total * 3)
        let n = Int(OCCTSurfaceDrawMesh(handle, Int32(uCount), Int32(vCount), &buffer))
        guard n == total else { return [] }

        var grid = [[SIMD3<Double>]]()
        grid.reserveCapacity(uCount)
        for i in 0..<uCount {
            var row = [SIMD3<Double>]()
            row.reserveCapacity(vCount)
            for j in 0..<vCount {
                let idx = (i * vCount + j) * 3
                row.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            grid.append(row)
        }
        return grid
    }

    // MARK: - Local Properties

    /// Gaussian curvature at (u, v)
    public func gaussianCurvature(atU u: Double, v: Double) -> Double {
        OCCTSurfaceGetGaussianCurvature(handle, u, v)
    }

    /// Mean curvature at (u, v)
    public func meanCurvature(atU u: Double, v: Double) -> Double {
        OCCTSurfaceGetMeanCurvature(handle, u, v)
    }

    /// Principal curvature result
    public struct PrincipalCurvatures: Sendable {
        public let kMin: Double
        public let kMax: Double
        public let dirMin: SIMD3<Double>
        public let dirMax: SIMD3<Double>
    }

    /// Principal curvatures and directions at (u, v)
    public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures? {
        var kMin: Double = 0, kMax: Double = 0
        var d1x: Double = 0, d1y: Double = 0, d1z: Double = 0
        var d2x: Double = 0, d2y: Double = 0, d2z: Double = 0
        guard OCCTSurfaceGetPrincipalCurvatures(handle, u, v, &kMin, &kMax,
                                                 &d1x, &d1y, &d1z,
                                                 &d2x, &d2y, &d2z)
        else { return nil }
        return PrincipalCurvatures(kMin: kMin, kMax: kMax,
                                   dirMin: SIMD3(d1x, d1y, d1z),
                                   dirMax: SIMD3(d2x, d2y, d2z))
    }

    // MARK: - Bounding Box

    /// Axis-aligned bounding box (nil for infinite surfaces)
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xMin: Double = 0, yMin: Double = 0, zMin: Double = 0
        var xMax: Double = 0, yMax: Double = 0, zMax: Double = 0
        guard OCCTSurfaceGetBoundingBox(handle, &xMin, &yMin, &zMin,
                                         &xMax, &yMax, &zMax)
        else { return nil }
        return (SIMD3(xMin, yMin, zMin), SIMD3(xMax, yMax, zMax))
    }

    // MARK: - BSpline/Bezier Queries

    /// Number of control points in U direction (0 if not BSpline/Bezier)
    public var uPoleCount: Int {
        Int(OCCTSurfaceGetUPoleCount(handle))
    }

    /// Number of control points in V direction (0 if not BSpline/Bezier)
    public var vPoleCount: Int {
        Int(OCCTSurfaceGetVPoleCount(handle))
    }

    /// Control points as 2D array [uRow][vCol] (empty if not BSpline/Bezier)
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

    /// Polynomial degree in U direction (0 if not BSpline/Bezier)
    public var uDegree: Int {
        Int(OCCTSurfaceGetUDegree(handle))
    }

    /// Polynomial degree in V direction (0 if not BSpline/Bezier)
    public var vDegree: Int {
        Int(OCCTSurfaceGetVDegree(handle))
    }

    // MARK: - Curve Projection (v0.22.0)

    /// Result of projecting a point onto a surface
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
            OCCTSurfaceProjectCurveSegments(handle, curve.handle, tolerance,
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
        var u: Double = 0, v: Double = 0, distance: Double = 0
        guard OCCTSurfaceProjectPoint(handle, point.x, point.y, point.z,
                                       &u, &v, &distance) else {
            return nil
        }
        return SurfaceProjection(u: u, v: v, distance: distance)
    }

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface (parametric) interpolating through 3D points.
    ///
    /// Uses `GeomPlate_BuildPlateSurface` + `GeomPlate_MakeApprox` to produce
    /// a BSpline surface that passes through all given points.
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

        guard let h = OCCTSurfacePlateThrough(
            &flatPoints, Int32(points.count),
            Int32(degree), tolerance
        ) else { return nil }
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

        guard let h = OCCTSurfaceNLPlateG0(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
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
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>, tangentU: SIMD3<Double>, tangentV: SIMD3<Double>)],
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

        guard let h = OCCTSurfaceNLPlateG1(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Batch Evaluation (v0.29.0)

extension Surface {
    /// Evaluate the surface at a UV grid in one call.
    ///
    /// Returns points in row-major order (u varies fastest).
    ///
    /// - Parameters:
    ///   - uParameters: Array of U parameter values
    ///   - vParameters: Array of V parameter values
    /// - Returns: 2D array of evaluated 3D points [v][u]
    public func evaluateGrid(uParameters: [Double], vParameters: [Double]) -> [[SIMD3<Double>]] {
        guard !uParameters.isEmpty, !vParameters.isEmpty else { return [] }
        let total = uParameters.count * vParameters.count
        var outXYZ = [Double](repeating: 0, count: total * 3)
        let n = Int(OCCTSurfaceEvaluateGrid(handle,
                                             uParameters, Int32(uParameters.count),
                                             vParameters, Int32(vParameters.count),
                                             &outXYZ))
        guard n == total else { return [] }
        var result = [[SIMD3<Double>]]()
        for v in 0..<vParameters.count {
            var row = [SIMD3<Double>]()
            for u in 0..<uParameters.count {
                let i = v * uParameters.count + u
                row.append(SIMD3(outXYZ[i * 3], outXYZ[i * 3 + 1], outXYZ[i * 3 + 2]))
            }
            result.append(row)
        }
        return result
    }
}

// MARK: - Surface Intersection & Conversion (v0.30.0)

extension Surface {
    /// Intersect this surface with another surface.
    ///
    /// - Parameters:
    ///   - other: The other surface
    ///   - tolerance: Intersection tolerance
    ///   - maxCurves: Maximum number of intersection curves
    /// - Returns: Array of intersection curves
    public func intersections(with other: Surface, tolerance: Double = 1e-6, maxCurves: Int = 50) -> [Curve3D] {
        var handles = [OCCTCurve3DRef?](repeating: nil, count: maxCurves)
        let n = Int(OCCTSurfaceIntersect(handle, other.handle, tolerance, &handles, Int32(maxCurves)))
        return (0..<n).compactMap { i in
            guard let h = handles[i] else { return nil }
            return Curve3D(handle: h)
        }
    }

    /// Convert this freeform surface to an analytical surface if possible.
    ///
    /// Recognizes if the surface is actually a plane, cylinder, cone,
    /// sphere, or torus within the given tolerance.
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The analytical surface, or nil if not recognizable
    public func toAnalytical(tolerance: Double = 1e-4) -> Surface? {
        guard let h = OCCTSurfaceToAnalytical(handle, tolerance) else { return nil }
        return Surface(handle: h)
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
    public static func bezierFill(_ c1: Curve3D, _ c2: Curve3D, _ c3: Curve3D, _ c4: Curve3D,
                                  style: BezierFillStyle = .stretch) -> Surface? {
        guard let h = OCCTSurfaceBezierFill4(c1.handle, c2.handle, c3.handle, c4.handle,
                                              style.rawValue) else { return nil }
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
    public static func bezierFill(_ c1: Curve3D, _ c2: Curve3D,
                                  style: BezierFillStyle = .stretch) -> Surface? {
        guard let h = OCCTSurfaceBezierFill2(c1.handle, c2.handle, style.rawValue) else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Face from Surface (v0.33.0)

    /// Create a face from this surface using its full parameter domain.
    ///
    /// - Parameter tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(tolerance: Double = 1e-6) -> Shape? {
        let d = domain
        return Shape.face(from: self, uRange: d.uMin...d.uMax, vRange: d.vMin...d.vMax, tolerance: tolerance)
    }

    /// Create a face from this surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(uRange: ClosedRange<Double>, vRange: ClosedRange<Double>,
                       tolerance: Double = 1e-6) -> Shape? {
        return Shape.face(from: self, uRange: uRange, vRange: vRange, tolerance: tolerance)
    }

    /// Create a face trimmed to a **non-rectangular** region of this surface, given by a closed
    /// boundary polygon in **UV space** (≥ 3 points, e.g. `[SIMD2(u,v), …]`). Each segment becomes
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
        var flat = [Double](); flat.reserveCapacity(uvBoundary.count * 2)
        for p in uvBoundary { flat.append(p.x); flat.append(p.y) }
        guard let h = flat.withUnsafeBufferPointer({ buf in
            OCCTShapeCreateFaceFromSurfaceUVPolygon(handle, buf.baseAddress, Int32(uvBoundary.count))
        }) else { return nil }
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
            OCCTSurfaceSurfaceIntersect(handle, other.handle, tolerance,
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
    /// 3D intersection point
    public var point: SIMD3<Double>
    /// Surface parameters (u, v) at the intersection
    public var surfaceUV: SIMD2<Double>
    /// Curve parameter at the intersection
    public var curveParameter: Double
}

extension Curve3D {
    /// Compute intersection points between this curve and a surface.
    ///
    /// - Parameter surface: The surface to intersect with
    /// - Returns: Array of intersection results with 3D points, surface UV, and curve parameter
    public func intersections(with surface: Surface) -> [CurveSurfaceIntersection] {
        let maxPoints: Int32 = 64
        var points = [OCCTCurveSurfacePoint](repeating: OCCTCurveSurfacePoint(), count: Int(maxPoints))
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
    /// Convert this surface to an array of Bezier surface patches.
    ///
    /// Decomposes a B-spline surface into a grid of Bezier patches. The surface
    /// is first converted to B-spline if needed.
    ///
    /// - Returns: Array of Bezier surface patches, or empty if conversion fails
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

    /// Result of decomposing a BSpline surface into Bezier patches
    public struct BezierPatchGrid {
        /// Number of patches in U direction
        public let uCount: Int
        /// Number of patches in V direction
        public let vCount: Int
        /// Patches in row-major order (U varies faster)
        public let patches: [Surface]
    }

    /// Decompose this BSpline surface into a grid of Bezier patches
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
    public static func bsplineFill(curve1: Curve3D, curve2: Curve3D, style: FillStyle = .coons) -> Surface? {
        guard let ref = OCCTSurfaceFillBSpline2Curves(curve1.handle, curve2.handle, style.rawValue) else {
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
    public static func bsplineFill(curves: (Curve3D, Curve3D, Curve3D, Curve3D), style: FillStyle = .coons) -> Surface? {
        guard let ref = OCCTSurfaceFillBSpline4Curves(
            curves.0.handle, curves.1.handle, curves.2.handle, curves.3.handle,
            style.rawValue
        ) else {
            return nil
        }
        return Surface(handle: ref)
    }

    // MARK: - Surface Extrema

    /// Result of surface-to-surface extrema computation.
    public struct SurfaceExtremaResult {
        /// Minimum distance between the surfaces
        public let distance: Double
        /// Nearest point on the first surface
        public let point1: SIMD3<Double>
        /// Nearest point on the second surface
        public let point2: SIMD3<Double>
        /// UV parameters on the first surface
        public let uv1: SIMD2<Double>
        /// UV parameters on the second surface
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
    public func extrema(to other: Surface,
                        uvBounds1: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil,
                        uvBounds2: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? = nil) -> SurfaceExtremaResult? {
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

    /// Result of projecting a 3D point to surface UV parameters
    public struct UVProjection: Sendable {
        /// UV parameters on the surface
        public let uv: SIMD2<Double>
        /// Gap: distance between the 3D point and the surface at the found UV
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
    public func nextValueOfUV(previousUV: SIMD2<Double>, point: SIMD3<Double>, precision: Double = 1e-6) -> UVProjection {
        let result = OCCTSurfaceNextValueOfUV(handle, previousUV.x, previousUV.y,
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
        guard let ref = OCCTSurfaceConicalFromAxis(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            semiAngle, radius) else { return nil }
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
        guard let ref = OCCTSurfaceConicalFromPointsRadii(
            point1.x, point1.y, point1.z,
            point2.x, point2.y, point2.z,
            r1, r2) else { return nil }
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
        guard let ref = OCCTSurfaceCylindricalFromAxis(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius) else { return nil }
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
        guard let ref = OCCTSurfaceCylindricalFromPoints(
            point1.x, point1.y, point1.z,
            point2.x, point2.y, point2.z,
            point3.x, point3.y, point3.z) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a plane surface through three points.
    ///
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    ///   - point3: Third point
    /// - Returns: Plane surface, or nil if points are collinear
    public static func planeFromPoints(
        _ point1: SIMD3<Double>,
        _ point2: SIMD3<Double>,
        _ point3: SIMD3<Double>
    ) -> Surface? {
        guard let ref = OCCTSurfacePlaneFromPoints(
            point1.x, point1.y, point1.z,
            point2.x, point2.y, point2.z,
            point3.x, point3.y, point3.z) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a plane surface from a point and normal direction.
    ///
    /// - Parameters:
    ///   - point: A point on the plane
    ///   - normal: Normal direction of the plane
    /// - Returns: Plane surface, or nil on failure
    public static func planeFromPointNormal(
        point: SIMD3<Double>,
        normal: SIMD3<Double>
    ) -> Surface? {
        guard let ref = OCCTSurfacePlaneFromPointNormal(
            point.x, point.y, point.z,
            normal.x, normal.y, normal.z) else { return nil }
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
        guard let ref = OCCTSurfaceTrimmedCone(
            point1.x, point1.y, point1.z,
            point2.x, point2.y, point2.z,
            r1, r2) else { return nil }
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
        guard let ref = OCCTSurfaceTrimmedCylinder(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            radius, height) else { return nil }
        return Surface(handle: ref)
    }

    /// Result of BSpline surface knot splitting analysis.
    public struct KnotSplitResult {
        /// Number of U split indices needed for the requested continuity
        public let uSplitCount: Int
        /// Number of V split indices needed for the requested continuity
        public let vSplitCount: Int
    }

    /// Analyze where a BSpline surface would need to be split to achieve
    /// a given continuity level.
    ///
    /// - Parameters:
    ///   - uContinuity: Desired U continuity (0=C0, 1=C1, 2=C2)
    ///   - vContinuity: Desired V continuity (0=C0, 1=C1, 2=C2)
    /// - Returns: Number of U and V splits needed
    public func knotSplitting(uContinuity: Int = 1, vContinuity: Int = 1) -> KnotSplitResult {
        let result = OCCTSurfaceKnotSplitting(handle, Int32(uContinuity), Int32(vContinuity))
        return KnotSplitResult(uSplitCount: Int(result.nbUSplits), vSplitCount: Int(result.nbVSplits))
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
        guard let ref = OCCTSurfaceJoinBezierPatches(&handles, Int32(rows), Int32(cols)) else { return nil }
        return Surface(handle: ref)
    }

    /// Result of trying to recognize an analytical surface.
    public struct AnalyticalConversion {
        /// Recognized analytical surface (plane, cylinder, cone, sphere, torus)
        public let surface: Surface
        /// Maximum deviation from the original surface
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
        /// Whether the surface was actually split
        public let wasSplit: Bool
        /// Whether the surface already meets the criterion (no split needed)
        public let alreadyMeetsCriterion: Bool
        /// Number of U split values
        public let uSplitCount: Int
        /// Number of V split values
        public let vSplitCount: Int
    }

    /// Analyze and split a BSpline surface at continuity breaks.
    ///
    /// - Parameters:
    ///   - criterion: Continuity level (0=C0, 1=C1, 2=C2, 3=C3)
    ///   - tolerance: Tolerance for continuity checking
    /// - Returns: Split analysis result
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> ContinuitySplitResult {
        let result = OCCTSurfaceSplitByContinuity(handle, Int32(criterion), tolerance)
        return ContinuitySplitResult(
            wasSplit: result.wasSplit,
            alreadyMeetsCriterion: result.isOk,
            uSplitCount: Int(result.nUSplits),
            vSplitCount: Int(result.nVSplits))
    }

    // MARK: - LocalAnalysis

    /// Result of surface continuity analysis at a junction point.
    public struct ContinuityAnalysis: Sendable {
        /// Continuity status as GeomAbs_Shape value
        public let status: Int
        /// Distance between surface points at junction
        public let c0Value: Double
        /// Angle between normals (radians)
        public let g1Angle: Double
        /// Angle between U-derivatives
        public let c1UAngle: Double
        /// Angle between V-derivatives
        public let c1VAngle: Double
        /// Bitmask: bit0=C0, bit1=G1, bit2=C1, bit3=G2, bit4=C2
        public let flags: Int

        /// Whether the junction is positionally continuous (C0)
        public var isC0: Bool { flags & 1 != 0 }
        /// Whether the junction is geometrically tangent-continuous (G1)
        public var isG1: Bool { flags & 2 != 0 }
        /// Whether the junction is parametrically tangent-continuous (C1)
        public var isC1: Bool { flags & 4 != 0 }
        /// Whether the junction is geometrically curvature-continuous (G2)
        public var isG2: Bool { flags & 8 != 0 }
        /// Whether the junction is parametrically curvature-continuous (C2)
        public var isC2: Bool { flags & 16 != 0 }
    }

    /// Analyze continuity between this surface at (u1, v1) and another surface at (u2, v2).
    ///
    /// - Parameters:
    ///   - u1: U parameter on this surface
    ///   - v1: V parameter on this surface
    ///   - other: Second surface
    ///   - u2: U parameter on second surface
    ///   - v2: V parameter on second surface
    ///   - order: Maximum continuity order to check (0=C0, 1=G1, 2=C1, 3=G2, 4=C2)
    /// - Returns: Continuity analysis result, or nil on failure
    public func continuityWith(_ other: Surface, u1: Double, v1: Double, u2: Double, v2: Double, order: Int = 4) -> ContinuityAnalysis? {
        var outStatus: Int32 = 0
        var outC0: Double = 0, outG1: Double = 0
        var outC1U: Double = 0, outC1V: Double = 0
        let ok = OCCTLocalAnalysisSurfaceContinuity(
            handle, u1, v1, other.handle, u2, v2, Int32(order),
            &outStatus, &outC0, &outG1, &outC1U, &outC1V)
        guard ok else { return nil }
        let flags = Int(OCCTLocalAnalysisSurfaceContinuityFlags(
            handle, u1, v1, other.handle, u2, v2, Int32(order)))
        return ContinuityAnalysis(
            status: Int(outStatus), c0Value: outC0, g1Angle: outG1,
            c1UAngle: outC1U, c1VAngle: outC1V, flags: flags)
    }

    // MARK: - GeomFill_NSections (v0.68.0)

    /// Create a BSpline surface by lofting through N section curves.
    ///
    /// - Parameters:
    ///   - sections: Array of 3D curves defining cross-sections
    ///   - params: Parameter values for each section (typically 0..1)
    /// - Returns: BSpline surface, or nil on failure
    public static func nSections(curves: [Curve3D], params: [Double]) -> Surface? {
        guard curves.count == params.count, curves.count >= 2 else { return nil }
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        return handles.withUnsafeBufferPointer { hBuf in
            params.withUnsafeBufferPointer { pBuf in
                guard let h = OCCTGeomFillNSections(hBuf.baseAddress!, pBuf.baseAddress!, Int32(curves.count)) else { return nil as Surface? }
                return Surface(handle: h)
            }
        }
    }

    /// Query section info from N-sections surface creation.
    public static func nSectionsInfo(curves: [Curve3D], params: [Double]) -> (poleCount: Int, knotCount: Int, degree: Int)? {
        guard curves.count == params.count, curves.count >= 2 else { return nil }
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        var nbPoles: Int32 = 0, nbKnots: Int32 = 0, deg: Int32 = 0
        handles.withUnsafeBufferPointer { hBuf in
            params.withUnsafeBufferPointer { pBuf in
                OCCTGeomFillNSectionsInfo(hBuf.baseAddress!, pBuf.baseAddress!, Int32(curves.count),
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
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>,
                        tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
                        curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>)],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // 20 doubles per constraint
        var flat: [Double] = []
        flat.reserveCapacity(constraints.count * 20)
        for c in constraints {
            flat.append(c.uv.x); flat.append(c.uv.y)
            flat.append(c.target.x); flat.append(c.target.y); flat.append(c.target.z)
            flat.append(c.tangentU.x); flat.append(c.tangentU.y); flat.append(c.tangentU.z)
            flat.append(c.tangentV.x); flat.append(c.tangentV.y); flat.append(c.tangentV.z)
            flat.append(c.curvatureUU.x); flat.append(c.curvatureUU.y); flat.append(c.curvatureUU.z)
            flat.append(c.curvatureUV.x); flat.append(c.curvatureUV.y); flat.append(c.curvatureUV.z)
            flat.append(c.curvatureVV.x); flat.append(c.curvatureVV.y); flat.append(c.curvatureVV.z)
        }

        guard let h = OCCTSurfaceNLPlateG2(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
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
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>,
                        tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
                        curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>,
                        d3UUU: SIMD3<Double>, d3UUV: SIMD3<Double>, d3UVV: SIMD3<Double>, d3VVV: SIMD3<Double>)],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // 32 doubles per constraint
        var flat: [Double] = []
        flat.reserveCapacity(constraints.count * 32)
        for c in constraints {
            flat.append(c.uv.x); flat.append(c.uv.y)
            flat.append(c.target.x); flat.append(c.target.y); flat.append(c.target.z)
            flat.append(c.tangentU.x); flat.append(c.tangentU.y); flat.append(c.tangentU.z)
            flat.append(c.tangentV.x); flat.append(c.tangentV.y); flat.append(c.tangentV.z)
            flat.append(c.curvatureUU.x); flat.append(c.curvatureUU.y); flat.append(c.curvatureUU.z)
            flat.append(c.curvatureUV.x); flat.append(c.curvatureUV.y); flat.append(c.curvatureUV.z)
            flat.append(c.curvatureVV.x); flat.append(c.curvatureVV.y); flat.append(c.curvatureVV.z)
            flat.append(c.d3UUU.x); flat.append(c.d3UUU.y); flat.append(c.d3UUU.z)
            flat.append(c.d3UUV.x); flat.append(c.d3UUV.y); flat.append(c.d3UUV.z)
            flat.append(c.d3UVV.x); flat.append(c.d3UVV.y); flat.append(c.d3UVV.z)
            flat.append(c.d3VVV.x); flat.append(c.d3VVV.y); flat.append(c.d3VVV.z)
        }

        guard let h = OCCTSurfaceNLPlateG3(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
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
            flat.append(c.uv.x); flat.append(c.uv.y)
            flat.append(c.target.x); flat.append(c.target.y); flat.append(c.target.z)
        }

        guard let h = OCCTSurfaceNLPlateIncrementalG0(
            handle, &flat, Int32(constraints.count),
            Int32(maxOrder), Int32(initConstraintOrder), Int32(nbIncrements)
        ) else { return nil }
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
            flat.append(c.uv.x); flat.append(c.uv.y)
            flat.append(c.target.x); flat.append(c.target.y); flat.append(c.target.z)
        }

        var x: Double = 0, y: Double = 0, z: Double = 0
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
        var x: Double = 0, y: Double = 0, z: Double = 0
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
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
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
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
        /// Whether the points form a plane
        public let isPlane: Bool
        /// Whether the points form a line (collinear)
        public let isLine: Bool
        /// Plane normal (meaningful when isPlane is true)
        public let normal: SIMD3<Double>
        /// Plane origin (meaningful when isPlane is true)
        public let origin: SIMD3<Double>
        /// UV bounding box on the plane
        public let uvBox: (umin: Double, umax: Double, vmin: Double, vmax: Double)
        /// Line origin (meaningful when isLine is true)
        public let lineOrigin: SIMD3<Double>
        /// Line direction (meaningful when isLine is true)
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
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
        }
        var g0: Double = 0, g1: Double = 0, g2: Double = 0
        let ok = OCCTGeomPlateErrors(&flat, Int32(points.count),
            tolerance, Int32(maxDegree), Int32(maxSegments),
            &g0, &g1, &g2)
        guard ok else { return nil }
        return (g0, g1, g2)
    }

    // MARK: - v0.80.0: Extrema, gce factories, GeomTools persistence

    /// Result of point-to-surface extrema
    public struct PointSurfaceExtrema: Sendable {
        public let isDone: Bool
        public let count: Int
    }

    /// Point on surface from extrema result
    public struct ExtremaPointOnSurface: Sendable {
        public let squareDistance: Double
        public let point: SIMD3<Double>
        public let u: Double
        public let v: Double
    }

    /// Compute point-to-surface extrema
    public func extremaPS(point: SIMD3<Double>) -> PointSurfaceExtrema {
        let r = OCCTExtremaExtPS(point.x, point.y, point.z, handle)
        return PointSurfaceExtrema(isDone: r.isDone, count: Int(r.nbExt))
    }

    /// Get Nth extremum from point-surface computation (1-based)
    public func extremaPSPoint(point: SIMD3<Double>, index: Int) -> ExtremaPointOnSurface {
        let r = OCCTExtremaExtPSPoint(point.x, point.y, point.z, handle, Int32(index))
        return ExtremaPointOnSurface(squareDistance: r.squareDistance,
                                     point: SIMD3(r.x, r.y, r.z), u: r.u, v: r.v)
    }

    /// Result of surface-to-surface extrema
    public struct SurfaceSurfaceExtrema: Sendable {
        public let isDone: Bool
        public let isParallel: Bool
        public let count: Int
    }

    /// Compute surface-to-surface extrema
    public func extremaSS(other: Surface) -> SurfaceSurfaceExtrema {
        let r = OCCTExtremaExtSS(handle, other.handle)
        return SurfaceSurfaceExtrema(isDone: r.isDone, isParallel: r.isParallel, count: Int(r.nbExt))
    }

    /// Get Nth extremum from surface-surface computation
    public func extremaSSPoint(other: Surface, index: Int) -> Curve3D.ExtremaPointPair {
        let r = OCCTExtremaExtSSPoint(handle, other.handle, Int32(index))
        return Curve3D.ExtremaPointPair(squareDistance: r.squareDistance,
                                        point1: SIMD3(r.x1, r.y1, r.z1), param1: r.param1,
                                        point2: SIMD3(r.x2, r.y2, r.z2), param2: r.param2)
    }

    /// Create a conical surface from 2 points (axis) + 2 radii (gce_MakeCone)
    public static func coneFrom2PointsRadii(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                            radius1: Double, radius2: Double) -> Surface? {
        guard let h = OCCTGceMakeCone(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z,
                                       radius1, radius2) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from 3 points (gce_MakeCylinder)
    public static func cylinderFrom3Points(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                           p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGceMakeCylinderFrom3Points(p1.x, p1.y, p1.z,
                                                      p2.x, p2.y, p2.z,
                                                      p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }

    /// Create a plane from equation Ax+By+Cz+D=0 (gce_MakePln)
    public static func planeFromEquation(a: Double, b: Double, c: Double, d: Double) -> Surface? {
        guard let h = OCCTGceMakePlnFromEquation(a, b, c, d) else { return nil }
        return Surface(handle: h)
    }

    /// Create a plane from 3 points (gce_MakePln)
    public static func planeFrom3Points(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                        p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGceMakePlnFrom3Points(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z,
                                                 p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }

    /// Serialize surfaces to string via GeomTools_SurfaceSet
    public static func serializeSurfaces(_ surfaces: [Surface]) -> String? {
        let handles = surfaces.map { $0.handle as OCCTSurfaceRef }
        guard let cStr = handles.withUnsafeBufferPointer({
            OCCTGeomToolsSurfaceSetWrite($0.baseAddress!, Int32(surfaces.count))
        }) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(cStr)
        return result
    }

    /// Deserialize surfaces from string via GeomTools_SurfaceSet
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
            var a = 0.0, b = 0.0, c = 0.0, d = 0.0
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
            var px = 0.0, py = 0.0, pz = 0.0, nx = 0.0, ny = 0.0, nz = 0.0
            OCCTSurfacePlanePln(handle, &px, &py, &pz, &nx, &ny, &nz)
            return (SIMD3(px, py, pz), SIMD3(nx, ny, nz))
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
            var x = 0.0, y = 0.0, z = 0.0
            OCCTSurfaceSphereCenter(handle, &x, &y, &z)
            return SIMD3(x, y, z)
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
            var cx = 0.0, cy = 0.0, cz = 0.0, r = 0.0
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
        public func setMajorRadius(_ r: Double) -> Bool { OCCTSurfaceTorusSetMajorRadius(handle, r) }

        /// Set the minor radius.
        @discardableResult
        public func setMinorRadius(_ r: Double) -> Bool { OCCTSurfaceTorusSetMinorRadius(handle, r) }

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
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTSurfaceCylinderAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
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
            var x = 0.0, y = 0.0, z = 0.0
            OCCTSurfaceConeApex(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The axis of the cone (position + direction).
        public var axis: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTSurfaceConeAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
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
            var dx = 0.0, dy = 0.0, dz = 0.0
            OCCTSurfaceSweptDirection(handle, &dx, &dy, &dz)
            return SIMD3(dx, dy, dz)
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
    /// Points are in row-major order: point[v*uCount+u].
    public static func fromPointGrid(points: [SIMD3<Double>], uCount: Int, vCount: Int,
                                     degMin: Int = 3, degMax: Int = 8,
                                     continuity: Int = 2, tolerance: Double = 1e-3) -> Surface? {
        guard points.count == uCount * vCount else { return nil }
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        guard let ref = flat.withUnsafeBufferPointer({ buf in
            OCCTPointsToSurfaceBSpline(buf.baseAddress!, Int32(uCount), Int32(vCount),
                                        Int32(degMin), Int32(degMax), Int32(continuity), tolerance)
        }) else { return nil }
        return Surface(handle: ref)
    }

    /// Compute the surface normal at (u, v).
    public func normal(u: Double, v: Double) -> SIMD3<Double> {
        var nx = 0.0, ny = 0.0, nz = 0.0
        OCCTSurfaceNormal(handle, u, v, &nx, &ny, &nz)
        return SIMD3(nx, ny, nz)
    }

    /// Compute Gaussian and mean curvature at (u, v).
    public func curvatures(u: Double, v: Double) -> (gaussian: Double, mean: Double) {
        var g = 0.0, m = 0.0
        OCCTSurfaceCurvatures(handle, u, v, &g, &m)
        return (g, m)
    }

    // MARK: - v0.125.0: BSpline Surface deep method completion

    /// Local evaluation D0 within a specific knot span.
    public func bsplineLocalD0(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                fromVK1: Int, toVK2: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTSurfaceBSplineLocalD0(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                   Int32(fromVK1), Int32(toVK2), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Local evaluation D1 within a specific knot span.
    public func bsplineLocalD1(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                fromVK1: Int, toVK2: Int)
        -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0
        var d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        OCCTSurfaceBSplineLocalD1(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                   Int32(fromVK1), Int32(toVK2),
                                   &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz))
    }

    /// Local evaluation D2 within a specific knot span.
    public func bsplineLocalD2(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                fromVK1: Int, toVK2: Int)
        -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
            d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0, d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        var d2ux = 0.0, d2uy = 0.0, d2uz = 0.0, d2vx = 0.0, d2vy = 0.0, d2vz = 0.0
        var d2uvx = 0.0, d2uvy = 0.0, d2uvz = 0.0
        OCCTSurfaceBSplineLocalD2(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                   Int32(fromVK1), Int32(toVK2),
                                   &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                                   &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                                   &d2uvx, &d2uvy, &d2uvz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz))
    }

    /// Local evaluation D3 within a specific knot span.
    public func bsplineLocalD3(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                fromVK1: Int, toVK2: Int)
        -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>,
            d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>,
            d3u: SIMD3<Double>, d3v: SIMD3<Double>, d3uuv: SIMD3<Double>, d3uvv: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0, d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        var d2ux = 0.0, d2uy = 0.0, d2uz = 0.0, d2vx = 0.0, d2vy = 0.0, d2vz = 0.0
        var d2uvx = 0.0, d2uvy = 0.0, d2uvz = 0.0
        var d3ux = 0.0, d3uy = 0.0, d3uz = 0.0, d3vx = 0.0, d3vy = 0.0, d3vz = 0.0
        var d3uuvx = 0.0, d3uuvy = 0.0, d3uuvz = 0.0, d3uvvx = 0.0, d3uvvy = 0.0, d3uvvz = 0.0
        OCCTSurfaceBSplineLocalD3(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                   Int32(fromVK1), Int32(toVK2),
                                   &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                                   &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                                   &d2uvx, &d2uvy, &d2uvz,
                                   &d3ux, &d3uy, &d3uz, &d3vx, &d3vy, &d3vz,
                                   &d3uuvx, &d3uuvy, &d3uuvz, &d3uvvx, &d3uvvy, &d3uvvz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz),
                SIMD3(d3ux, d3uy, d3uz), SIMD3(d3vx, d3vy, d3vz),
                SIMD3(d3uuvx, d3uuvy, d3uuvz), SIMD3(d3uvvx, d3uvvy, d3uvvz))
    }

    /// Local derivative DN within a specific knot span.
    public func bsplineLocalDN(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                fromVK1: Int, toVK2: Int, nu: Int, nv: Int) -> SIMD3<Double> {
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTSurfaceBSplineLocalDN(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                   Int32(fromVK1), Int32(toVK2), Int32(nu), Int32(nv), &vx, &vy, &vz)
        return SIMD3(vx, vy, vz)
    }

    /// Local value within a specific knot span.
    public func bsplineLocalValue(u: Double, v: Double, fromUK1: Int, toUK2: Int,
                                   fromVK1: Int, toVK2: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTSurfaceBSplineLocalValue(handle, u, v, Int32(fromUK1), Int32(toUK2),
                                      Int32(fromVK1), Int32(toVK2), &x, &y, &z)
        return SIMD3(x, y, z)
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

    /// Locate U knot span. Returns (i1, i2) indices.
    public func bsplineLocateU(u: Double, paramTol: Double) -> (i1: Int, i2: Int) {
        var i1: Int32 = 0, i2: Int32 = 0
        OCCTSurfaceBSplineLocateU(handle, u, paramTol, &i1, &i2)
        return (Int(i1), Int(i2))
    }

    /// Locate V knot span. Returns (i1, i2) indices.
    public func bsplineLocateV(v: Double, paramTol: Double) -> (i1: Int, i2: Int) {
        var i1: Int32 = 0, i2: Int32 = 0
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
        var result = [SIMD3<Double>]()
        result.reserveCapacity(uCount * vCount)
        for i in stride(from: 0, to: flat.count, by: 3) {
            result.append(SIMD3(flat[i], flat[i + 1], flat[i + 2]))
        }
        return result
    }

    /// Get parameter bounds for BSpline surface.
    public var bsplineBounds: (u1: Double, u2: Double, v1: Double, v2: Double) {
        var u1 = 0.0, u2 = 0.0, v1 = 0.0, v2 = 0.0
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

    /// Bezier surface continuity (0=C0, 1=C1, 2=C2, 3=C3, 4=CN).
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
        var result = [SIMD3<Double>]()
        result.reserveCapacity(uCount * vCount)
        for i in stride(from: 0, to: flat.count, by: 3) {
            result.append(SIMD3(flat[i], flat[i + 1], flat[i + 2]))
        }
        return result
    }

    /// Get all weights as flat array for Bezier surface. Returns nil if non-rational.
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
        var u1 = 0.0, u2 = 0.0, v1 = 0.0, v2 = 0.0
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

    /// Insert a pole column after index in a Bezier surface. Poles array is [SIMD3] of size NbUPoles.
    @discardableResult
    public func bezierInsertPoleColAfter(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleColAfter(handle, Int32(colIndex), flat, Int32(poles.count))
    }

    /// Insert a pole row after index in a Bezier surface. Poles array is [SIMD3] of size NbVPoles.
    @discardableResult
    public func bezierInsertPoleRowAfter(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleRowAfter(handle, Int32(rowIndex), flat, Int32(poles.count))
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
    @discardableResult
    public func bezierSetPoleColWeights(vIndex: Int, poles: [SIMD3<Double>], weights: [Double]) -> Bool {
        guard poles.count == weights.count else { return false }
        var flat = [Double]()
        flat.reserveCapacity(poles.count * 3)
        for p in poles { flat.append(p.x); flat.append(p.y); flat.append(p.z) }
        return OCCTSurfaceBezierSetPoleColWeights(handle, Int32(vIndex), flat, weights, Int32(poles.count))
    }

    /// Set a pole row with weights on a Bezier surface.
    /// - Parameters:
    ///   - uIndex: Row index (1-based)
    ///   - poles: Array of 3D points (must have NbVPoles elements)
    ///   - weights: Array of weights (must have NbVPoles elements)
    @discardableResult
    public func bezierSetPoleRowWeights(uIndex: Int, poles: [SIMD3<Double>], weights: [Double]) -> Bool {
        guard poles.count == weights.count else { return false }
        var flat = [Double]()
        flat.reserveCapacity(poles.count * 3)
        for p in poles { flat.append(p.x); flat.append(p.y); flat.append(p.z) }
        return OCCTSurfaceBezierSetPoleRowWeights(handle, Int32(uIndex), flat, weights, Int32(poles.count))
    }

    // MARK: - v0.129.0: Bezier surface completions

    /// Insert a pole column before index in a Bezier surface. Poles array is [SIMD3] of size NbUPoles.
    @discardableResult
    public func bezierInsertPoleColBefore(_ colIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleColBefore(handle, Int32(colIndex), flat, Int32(poles.count))
    }

    /// Insert a pole row before index in a Bezier surface. Poles array is [SIMD3] of size NbVPoles.
    @discardableResult
    public func bezierInsertPoleRowBefore(_ rowIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let flat = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBezierInsertPoleRowBefore(handle, Int32(rowIndex), flat, Int32(poles.count))
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
    public func rotate(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double) -> Bool {
        OCCTSurfaceTransform(handle, 1,
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
        OCCTSurfaceTransform(handle, 4,
                              origin.x, origin.y, origin.z,
                              direction.x, direction.y, direction.z, 0)
    }

    /// Mirror the surface in place through a plane.
    @discardableResult
    public func mirrorPlane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Bool {
        OCCTSurfaceTransform(handle, 5,
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
    public static func ellipsoid(a: Double, b: Double, c: Double) -> Surface? {
        guard let ref = OCCTGeomEvalEllipsoidCreate(a, b, c) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a hyperboloid of revolution surface.
    /// - Parameters:
    ///   - r1: first semi-axis radius (> 0)
    ///   - r2: second semi-axis radius (> 0)
    ///   - twoSheets: if true, creates a two-sheet hyperboloid (default: one-sheet)
    public static func hyperboloid(r1: Double, r2: Double, twoSheets: Bool = false) -> Surface? {
        guard let ref = OCCTGeomEvalHyperboloidCreate(r1, r2, twoSheets ? 1 : 0) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a circular paraboloid of revolution surface.
    /// - Parameter focal: focal distance (> 0)
    public static func paraboloid(focal: Double) -> Surface? {
        guard let ref = OCCTGeomEvalParaboloidCreate(focal) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a circular helicoid (ruled surface).
    /// S(u,v) = v*cos(u)*X + v*sin(u)*Y + (P*u/(2*Pi))*Z
    /// - Parameter pitch: axial advance per 2*Pi turn (must be != 0)
    public static func circularHelicoid(pitch: Double) -> Surface? {
        guard let ref = OCCTGeomEvalCircularHelicoidCreate(pitch) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a hyperbolic paraboloid (saddle surface).
    /// P(u,v) = u*X + v*Y + (u^2/a^2 - v^2/b^2)*Z
    /// - Parameters:
    ///   - a: first semi-axis length (> 0)
    ///   - b: second semi-axis length (> 0)
    public static func hyperbolicParaboloid(a: Double, b: Double) -> Surface? {
        guard let ref = OCCTGeomEvalHypParaboloidCreate(a, b) else { return nil }
        return Surface(handle: ref)
    }

    /// Build a Gordon surface from a network of profile and guide curves.
    /// Requires at least 2 profiles and 2 guides that form a complete grid.
    /// - Parameters:
    ///   - profiles: array of profile curves (V-direction)
    ///   - guides: array of guide curves (U-direction)
    ///   - tolerance: geometric tolerance for intersection detection
    /// - Returns: the Gordon B-spline surface, or nil on failure
    public static func gordon(profiles: [Curve3D], guides: [Curve3D], tolerance: Double = 1e-3) -> Surface? {
        guard profiles.count >= 2, guides.count >= 2 else { return nil }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        return profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else { return nil as Surface? }
                guard let ref = OCCTGeomFillGordon(pPtr, Int32(profiles.count),
                                                    gPtr, Int32(guides.count),
                                                    tolerance) else { return nil }
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
    public static func gordonReport(profiles: [Curve3D], guides: [Curve3D],
                                    tolerance: Double = 1e-3,
                                    allowApproximateFallback: Bool = false) -> GordonResult {
        guard profiles.count >= 2, guides.count >= 2 else {
            return GordonResult(surface: nil, status: .invalidInput, isApproximate: false)
        }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        var statusRaw: Int32 = 0
        var isApprox: Bool = false
        let surfaceRef: OCCTSurfaceRef? = profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else { return nil as OCCTSurfaceRef? }
                return OCCTGeomFillGordonReport(pPtr, Int32(profiles.count),
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
    /// profile/guide curve network. The curves are converted to non-periodic B-splines,
    /// an intersection grid is sampled along each profile, and locator parameters are
    /// uniformly spaced. Returns the surface (nil on failure) and the result status.
    /// - Parameters:
    ///   - profiles: profile curves evaluated in U, at least 2.
    ///   - guides: guide curves evaluated in V, at least 2.
    ///   - tolerance: geometric tolerance for closed-seam checks.
    public static func networkSurface(profiles: [Curve3D], guides: [Curve3D],
                                      tolerance: Double = 1e-3)
        -> (surface: Surface?, status: NetworkSurfaceStatus) {
        guard profiles.count >= 2, guides.count >= 2 else { return (nil, .invalidInput) }
        let profileRefs = profiles.map { $0.handle }
        let guideRefs = guides.map { $0.handle }
        var statusRaw: Int32 = 0
        let surfaceRef: OCCTSurfaceRef? = profileRefs.withUnsafeBufferPointer { pBuf in
            guideRefs.withUnsafeBufferPointer { gBuf in
                guard let pPtr = pBuf.baseAddress, let gPtr = gBuf.baseAddress else { return nil as OCCTSurfaceRef? }
                return OCCTGeomFillNetworkSurface(pPtr, Int32(profiles.count),
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
    public static func tBezier(poles: [SIMD3<Double>], uCount: Int, vCount: Int,
                                alphaU: Double, alphaV: Double) -> Surface? {
        guard poles.count == uCount * vCount,
              uCount >= 3, vCount >= 3,
              uCount % 2 == 1, vCount % 2 == 1 else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        guard let ref = OCCTGeomEvalTBezierSurfaceCreate(&flat, Int32(uCount), Int32(vCount),
                                                           alphaU, alphaV) else { return nil }
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
    public static func ahtBezier(poles: [SIMD3<Double>], uCount: Int, vCount: Int,
                                  algDegreeU: Int, algDegreeV: Int,
                                  alphaU: Double, alphaV: Double,
                                  betaU: Double, betaV: Double) -> Surface? {
        guard poles.count == uCount * vCount, uCount >= 1, vCount >= 1 else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        guard let ref = OCCTGeomEvalAHTBezierSurfaceCreate(&flat, Int32(uCount), Int32(vCount),
                                                             Int32(algDegreeU), Int32(algDegreeV),
                                                             alphaU, alphaV, betaU, betaV) else { return nil }
        return Surface(handle: ref)
    }
}

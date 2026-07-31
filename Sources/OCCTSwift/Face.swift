import Foundation
import simd
import OCCTBridge

/// A face from a 3D solid shape - represents a bounded surface
public final class Face: @unchecked Sendable {
    internal let handle: OCCTFaceRef

    /// This face's 0-based position in its parent shape's face enumeration, or -1 when the face
    /// was not produced from a parent.
    ///
    /// The same token ``Shape/face(at:)`` takes, and the one every face-index-taking method on
    /// `Shape` expects. It is only meaningful against the shape it came from.
    public let index: Int

    internal init(handle: OCCTFaceRef, index: Int = -1) {
        self.handle = handle
        self.index = index
    }

    /// Construct a Face from a Shape that wraps a TopoDS_Face. Returns nil
    /// if `shape` is null or wraps a non-face topology type.
    public convenience init?(_ shape: Shape) {
        guard let h = OCCTFaceFromShape(shape.handle) else { return nil }
        self.init(handle: h)
    }

    deinit {
        OCCTFaceRelease(handle)
    }

    // MARK: - Properties

    /// Get the normal vector at the center of the face
    public var normal: SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTFaceGetNormal(handle, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get the outer wire (boundary) of the face
    public var outerWire: Wire? {
        guard let wireHandle = OCCTFaceGetOuterWire(handle) else {
            return nil
        }
        return Wire(handle: wireHandle)
    }

    /// Get the bounding box of the face
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTFaceGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }

    /// Check if the face is planar (flat)
    public var isPlanar: Bool {
        OCCTFaceIsPlanar(handle)
    }

    /// Check if the face is horizontal (normal points up or down)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isHorizontal(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return abs(n.z) > cos(tolerance)
    }

    /// Check if the face is upward-facing (normal points up)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isUpwardFacing(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return n.z > cos(tolerance)
    }

    /// Check if the face is downward-facing (normal points down)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isDownwardFacing(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return n.z < -cos(tolerance)
    }

    /// Check if the face is vertical (normal is horizontal)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isVertical(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return abs(n.z) < sin(tolerance)
    }

    /// Get the Z level of a horizontal planar face
    /// Returns nil if face is not horizontal or not planar
    public var zLevel: Double? {
        var z: Double = 0
        guard OCCTFaceGetZLevel(handle, &z) else {
            return nil
        }
        return z
    }

    // MARK: - Surface Properties (v0.18.0)

    /// Surface type classification
    public enum SurfaceType: Int32, Sendable {
        case plane = 0, cylinder = 1, cone = 2, sphere = 3, torus = 4
        case bezierSurface = 5, bsplineSurface = 6
        case surfaceOfRevolution = 7, surfaceOfExtrusion = 8
        case offsetSurface = 9, other = 10
    }

    /// Principal curvature result
    public struct PrincipalCurvatures: Sendable {
        public let kMin: Double
        public let kMax: Double
        public let dirMin: SIMD3<Double>
        public let dirMax: SIMD3<Double>
    }

    /// Projection result for a point onto this face's surface
    public struct SurfaceProjection: Sendable {
        public let point: SIMD3<Double>
        public let u: Double
        public let v: Double
        public let distance: Double
    }

    /// Get UV parameter bounds of the face
    public var uvBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? {
        var uMin: Double = 0, uMax: Double = 0, vMin: Double = 0, vMax: Double = 0
        guard OCCTFaceGetUVBounds(handle, &uMin, &uMax, &vMin, &vMax) else {
            return nil
        }
        return (uMin: uMin, uMax: uMax, vMin: vMin, vMax: vMax)
    }

    /// Get the surface type of this face
    public var surfaceType: SurfaceType {
        SurfaceType(rawValue: OCCTFaceGetSurfaceType(handle)) ?? .other
    }

    /// Get the surface area of this face
    public func area(tolerance: Double = 1e-6) -> Double {
        OCCTFaceGetArea(handle, tolerance)
    }

    /// Evaluate a point on the surface at UV parameters
    public func point(atU u: Double, v: Double) -> SIMD3<Double>? {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        guard OCCTFaceEvaluateAtUV(handle, u, v, &px, &py, &pz) else {
            return nil
        }
        return SIMD3(px, py, pz)
    }

    /// Get the surface normal at UV parameters
    public func normal(atU u: Double, v: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTFaceGetNormalAtUV(handle, u, v, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get Gaussian curvature at UV parameters
    public func gaussianCurvature(atU u: Double, v: Double) -> Double? {
        var curvature: Double = 0
        guard OCCTFaceGetGaussianCurvature(handle, u, v, &curvature) else {
            return nil
        }
        return curvature
    }

    /// Get mean curvature at UV parameters
    public func meanCurvature(atU u: Double, v: Double) -> Double? {
        var curvature: Double = 0
        guard OCCTFaceGetMeanCurvature(handle, u, v, &curvature) else {
            return nil
        }
        return curvature
    }

    /// Get principal curvatures and their directions at UV parameters
    public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures? {
        var k1: Double = 0, k2: Double = 0
        var d1x: Double = 0, d1y: Double = 0, d1z: Double = 0
        var d2x: Double = 0, d2y: Double = 0, d2z: Double = 0
        guard OCCTFaceGetPrincipalCurvatures(handle, u, v,
                                              &k1, &k2,
                                              &d1x, &d1y, &d1z,
                                              &d2x, &d2y, &d2z) else {
            return nil
        }
        return PrincipalCurvatures(
            kMin: k1, kMax: k2,
            dirMin: SIMD3(d1x, d1y, d1z),
            dirMax: SIMD3(d2x, d2y, d2z)
        )
    }

    /// Project a 3D point onto this face's surface (closest point)
    public func project(point: SIMD3<Double>) -> SurfaceProjection? {
        let result = OCCTFaceProjectPoint(handle, point.x, point.y, point.z)
        guard result.isValid else { return nil }
        return SurfaceProjection(
            point: SIMD3(result.px, result.py, result.pz),
            u: result.u, v: result.v,
            distance: result.distance
        )
    }

    /// Get all projection results for a point onto this face's surface
    public func allProjections(of point: SIMD3<Double>) -> [SurfaceProjection] {
        var buffer = [OCCTSurfaceProjectionResult](repeating: OCCTSurfaceProjectionResult(), count: 32)
        let count = OCCTFaceProjectPointAll(handle, point.x, point.y, point.z,
                                             &buffer, 32)
        var projections = [SurfaceProjection]()
        for i in 0..<Int(count) {
            let r = buffer[i]
            if r.isValid {
                projections.append(SurfaceProjection(
                    point: SIMD3(r.px, r.py, r.pz),
                    u: r.u, v: r.v,
                    distance: r.distance
                ))
            }
        }
        return projections
    }

    /// Get intersection curves between this face and another
    public func intersection(with other: Face, tolerance: Double = 1e-6) -> Shape? {
        guard let resultHandle = OCCTFaceIntersect(handle, other.handle, tolerance) else {
            return nil
        }
        return Shape(handle: resultHandle)
    }
}

// MARK: - Shape Extension for Face Analysis

extension Shape {
    /// Every distinct face of this shape, in enumeration order.
    ///
    /// Each returned ``Face`` carries its own ``Face/index``, which is its position here and the
    /// token ``Shape/face(at:)``, ``Shape/drafted(faces:direction:angle:neutralPlane:)``,
    /// ``Shape/shelled(thickness:openFaces:)`` and ``Shape/withoutFeatures(faces:)`` all address.
    ///
    /// This is the enumeration ``Shape/faceCount`` counts. Before #541 it was a separate walk that
    /// yielded one entry per *occurrence* in the topology tree, so a face reachable from two
    /// parents appeared twice and the surplus indices named faces nothing else could address.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let top = box.faces().filter { $0.isUpwardFacing() }
    /// if let hollow = box.shelled(thickness: 1.0, openFaces: top) {
    ///     print(hollow.faceCount)   // the open box
    /// }
    /// ```
    public func faces() -> [Face] {
        var count: Int32 = 0
        guard let faceArray = OCCTShapeGetFaces(handle, &count) else {
            return []
        }
        // Use OCCTFreeFaceArrayOnly - Swift Face objects now own the face handles
        // and will release them in their deinit. We only need to free the array container.
        defer { OCCTFreeFaceArrayOnly(faceArray) }

        var faces: [Face] = []
        for i in 0..<Int(count) {
            if let faceHandle = faceArray[i] {
                faces.append(Face(handle: faceHandle, index: i))
            }
        }

        return faces
    }

    /// Get horizontal faces (normals pointing up or down)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func horizontalFaces(tolerance: Double = 0.01) -> [Face] {
        faces().filter { $0.isHorizontal(tolerance: tolerance) }
    }

    /// Get upward-facing horizontal faces (potential pocket floors)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func upwardFaces(tolerance: Double = 0.01) -> [Face] {
        faces().filter { $0.isUpwardFacing(tolerance: tolerance) }
    }

    /// Get faces grouped by Z level (for CAM pocket detection)
    /// - Parameter tolerance: Z tolerance for grouping faces
    /// - Returns: Dictionary mapping Z levels to arrays of faces at that level
    public func facesByZLevel(tolerance: Double = 0.01) -> [Double: [Face]] {
        let horizontal = horizontalFaces()
        var result: [Double: [Face]] = [:]

        for face in horizontal {
            guard let z = face.zLevel else { continue }

            // Find existing group within tolerance
            var foundGroup = false
            for (existingZ, _) in result {
                if abs(existingZ - z) < tolerance {
                    result[existingZ]?.append(face)
                    foundGroup = true
                    break
                }
            }

            if !foundGroup {
                result[z] = [face]
            }
        }

        return result
    }
}

// MARK: - BRepGProp_Face Evaluation (v0.45.0)

extension Face {
    /// Result of evaluating a face at a UV parameter using BRepGProp_Face.
    public struct GPropEvaluation: Sendable {
        /// 3D point on the surface at (u, v)
        public let point: SIMD3<Double>
        /// Unnormalized surface normal (dS/du x dS/dv).
        /// The magnitude equals the local area element (Jacobian determinant).
        public let normal: SIMD3<Double>
    }

    /// Get the natural parametric bounds of this face using BRepGProp_Face.
    ///
    /// Unlike `uvBounds` (which uses BRepTools::UVBounds), this uses BRepGProp_Face::Bounds
    /// which accounts for face orientation and provides integration-ready parametric bounds.
    ///
    /// - Returns: UV bounds as (uMin, uMax, vMin, vMax), or nil on error
    public var naturalBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double)? {
        var uMin: Double = 0, uMax: Double = 0, vMin: Double = 0, vMax: Double = 0
        guard OCCTFaceGetNaturalBounds(handle, &uMin, &uMax, &vMin, &vMax) else {
            return nil
        }
        return (uMin: uMin, uMax: uMax, vMin: vMin, vMax: vMax)
    }

    /// Evaluate the face surface at UV parameters using BRepGProp_Face.
    ///
    /// Returns both the 3D point and the unnormalized surface normal at (u, v).
    /// The normal is the cross product of partial derivatives (dS/du x dS/dv),
    /// whose magnitude equals the local surface area element. This is useful for
    /// surface integration (e.g., computing surface area, flux integrals).
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    /// - Returns: Evaluation result with point and unnormalized normal, or nil on error
    public func evaluateGProp(u: Double, v: Double) -> GPropEvaluation? {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTFaceEvaluateNormalAtUV(handle, u, v, &px, &py, &pz, &nx, &ny, &nz) else {
            return nil
        }
        return GPropEvaluation(
            point: SIMD3(px, py, pz),
            normal: SIMD3(nx, ny, nz)
        )
    }
}

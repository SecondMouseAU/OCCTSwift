import Foundation
import OCCTBridge

/// An axis extracted from a shape or face: an origin+direction pair carrying the
/// geometric meaning of the underlying surface.
///
/// Produced by `Face.primaryAxis`, `Shape.revolutionAxes`, and `Shape.symmetryAxes`.
public struct ShapeAxis: Sendable, Hashable {
    public let origin: SIMD3<Double>

    /// The axis's orientation — its meaning depends on `kind`.
    ///
    /// For `.cylinder`/`.cone`/`.torus`/`.revolution`, this is a genuine rotation axis —
    /// never a surface normal: on a cylinder, for instance, `direction` runs along the
    /// cylinder's length, perpendicular to the local surface normal, not aligned with
    /// it. For `.extrusion`, it is instead the *sweep* direction of the underlying
    /// `Geom_SurfaceOfLinearExtrusion` — also tangent to the surface, not
    /// perpendicular to it. `.sphere` has no intrinsic axis at all — see below. A
    /// caller expecting an actual surface *normal* (e.g. "erect a feature
    /// perpendicular to this face") should not use `direction` at all for any of
    /// these kinds; see `ConstructionEntity.resolveFaceAxisDirection`, which falls
    /// back to the real local surface normal (`Face.normal(atU:v:)`) instead of
    /// `direction` for exactly the kinds that don't have a genuine axis (`.extrusion`
    /// and `.sphere`) or no `primaryAxis` at all (planes, free-form faces) (PR #897
    /// review, 2nd + second xhigh pass finding 6).
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 5, height: 10)!
    /// if let axis = cylinder.faces()[0].primaryAxis, axis.kind == .cylinder {
    ///     let rotationAxis = axis.direction  // safe: .cylinder has a genuine axis
    /// }
    /// ```
    public let direction: SIMD3<Double>
    public let extent: ClosedRange<Double>?
    public let kind: Kind

    public enum Kind: Int32, Sendable, Hashable {
        case cylinder = 1
        case cone = 2
        /// A sphere has no intrinsic rotation axis (it's symmetric about every axis
        /// through its center) — `direction` here is just the arbitrary
        /// construction-frame pole, not a property of the surface.
        case sphere = 3
        case torus = 4
        case revolution = 5
        /// `direction` is the sweep direction, not a surface normal — see `direction`'s doc above.
        case extrusion = 6
        case symmetry = 7
    }

    public init(
        origin: SIMD3<Double>, direction: SIMD3<Double>,
        extent: ClosedRange<Double>? = nil, kind: Kind
    ) {
        self.origin = origin
        self.direction = direction
        self.extent = extent
        self.kind = kind
    }

    fileprivate init(_ a: OCCTShapeAxis) {
        self.origin = SIMD3(a.originX, a.originY, a.originZ)
        self.direction = SIMD3(a.directionX, a.directionY, a.directionZ)
        self.extent = a.hasExtent ? (a.extentMin...a.extentMax) : nil
        self.kind = Kind(rawValue: a.kind) ?? .symmetry
    }
}

extension Face {
    /// The primary axis of the face's underlying surface, if it has one.
    ///
    /// Cylindrical, conical, spherical, toroidal, surface-of-revolution, and
    /// surface-of-extrusion faces all have a canonical axis; planes and free-form
    /// Bezier/BSpline faces return nil.
    public var primaryAxis: ShapeAxis? {
        var ox: Double = 0
        var oy: Double = 0
        var oz: Double = 0
        var dx: Double = 0
        var dy: Double = 0
        var dz: Double = 0
        var kind: Int32 = 0
        guard OCCTFaceGetPrimaryAxis(handle, &ox, &oy, &oz, &dx, &dy, &dz, &kind),
            let k = ShapeAxis.Kind(rawValue: kind)
        else {
            return nil
        }
        return ShapeAxis(
            origin: SIMD3(ox, oy, oz),
            direction: SIMD3(dx, dy, dz),
            kind: k)
    }
}

extension Shape {
    /// All distinct axes of revolution present in the shape, collected from
    /// cylindrical, conical, spherical, toroidal, and surface-of-revolution faces.
    ///
    /// Axes that coincide within `tolerance` are deduplicated.
    public func revolutionAxes(tolerance: Double = 1e-6) -> [ShapeAxis] {
        var buffer = [OCCTShapeAxis](repeating: OCCTShapeAxis(), count: 256)
        let count = OCCTShapeRevolutionAxes(handle, tolerance, &buffer, 256)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map { ShapeAxis(buffer[$0]) }
    }

    /// Symmetry axes derived from the principal moments of inertia.
    ///
    /// The moments are the volume-based ones, so this is empty for any shape with no closed
    /// volume: a face, wire, edge, vertex or open shell. Those used to report **spherical**
    /// symmetry, because a zero-mass framework has three equal (zero) moments and OCCT's
    /// `HasSymmetryPoint()` says yes to that, yielding three orthonormal axes through the
    /// shape's location origin that describe nothing (#609).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// Shape.sphere(radius: 5)!.symmetryAxes().count              // 3
    /// Shape.cylinder(radius: 2, height: 9)!.symmetryAxes().count // 1, the cylinder's own axis
    /// Shape.fromFace(box.faces()[0])!.symmetryAxes()             // [], was 3
    /// ```
    ///
    /// - Parameter fractionalTolerance: Two principal moments are considered equal
    ///   when their absolute difference is below this fraction of the largest moment.
    /// - Returns: One axis for rotational symmetry, three for spherical symmetry, empty otherwise.
    public func symmetryAxes(fractionalTolerance: Double = 1e-4) -> [ShapeAxis] {
        var buffer = [OCCTShapeAxis](repeating: OCCTShapeAxis(), count: 8)
        let count = OCCTShapeSymmetryAxes(handle, fractionalTolerance, &buffer, 8)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map { ShapeAxis(buffer[$0]) }
    }
}

/// Reads an origin/direction pair from a six-`Double`-out-param `OCCT*Axis`-shaped bridge call,
/// given as a closure already bound to the caller's own handle.
/// - Returns: element 0 is origin, element 1 is direction, by position; the caller's own
///   declared return type supplies whatever labels it wants.
func unwrapAxisComponents(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Void
) -> (SIMD3<Double>, SIMD3<Double>) {
    var px: Double = 0
    var py: Double = 0
    var pz: Double = 0
    var dx: Double = 0
    var dy: Double = 0
    var dz: Double = 0
    bridgeCall(&px, &py, &pz, &dx, &dy, &dz)
    return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
}

/// Reads a point or direction from a three-`Double`-out-param bridge call, given as a closure
/// already bound to the caller's own handle and any other arguments.
func unwrapVectorComponents(
    _ bridgeCall: (
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Void
) -> SIMD3<Double> {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    bridgeCall(&x, &y, &z)
    return SIMD3(x, y, z)
}

extension Surface {
    /// A six-out-param `OCCT*Axis`-shaped bridge function taking a `Surface` handle first:
    /// origin then direction, one double each.
    private typealias AxisBridgeFn = (
        OCCTSurfaceRef, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>,
        UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>
    ) -> Void

    /// Shared unwrap for the six-out-param `OCCT*Axis` bridge functions: guards `surfaceKind`,
    /// then reads origin/direction via `unwrapAxisComponents`.
    private func axis(
        ifKind kind: SurfaceType,
        _ bridgeFn: AxisBridgeFn
    ) -> (SIMD3<Double>, SIMD3<Double>)? {
        guard surfaceKind == kind else { return nil }
        return unwrapAxisComponents { bridgeFn(handle, $0, $1, $2, $3, $4, $5) }
    }

    /// Axis of a toroidal surface (origin + direction of the rotation axis).
    /// - Returns: nil if the surface is not a torus.
    public var torusAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        axis(ifKind: .torus, OCCTSurfaceTorusAxis)
    }

    /// Axis of a surface of revolution (origin + direction).
    /// - Returns: nil if the surface is not a surface-of-revolution.
    public var revolutionAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        axis(ifKind: .surfaceOfRevolution, OCCTSurfaceRevolutionAxis)
    }
}

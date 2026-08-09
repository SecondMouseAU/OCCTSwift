import Foundation
import OCCTBridge

/// An axis extracted from a shape or face — an origin+direction pair carrying the
/// geometric meaning of the underlying surface. Produced by `Face.primaryAxis`,
/// `Shape.revolutionAxes`, and `Shape.symmetryAxes`.
public struct ShapeAxis: Sendable, Hashable {
    public let origin: SIMD3<Double>
    public let direction: SIMD3<Double>
    public let extent: ClosedRange<Double>?
    public let kind: Kind

    public enum Kind: Int32, Sendable, Hashable {
        case cylinder   = 1
        case cone       = 2
        case sphere     = 3
        case torus      = 4
        case revolution = 5
        case extrusion  = 6
        case symmetry   = 7
    }

    public init(origin: SIMD3<Double>, direction: SIMD3<Double>,
                extent: ClosedRange<Double>? = nil, kind: Kind) {
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
    /// Cylindrical, conical, spherical, toroidal, surface-of-revolution, and
    /// surface-of-extrusion faces all have a canonical axis; planes and free-form
    /// Bezier/BSpline faces return nil.
    public var primaryAxis: ShapeAxis? {
        var ox: Double = 0, oy: Double = 0, oz: Double = 0
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        var kind: Int32 = 0
        guard OCCTFaceGetPrimaryAxis(handle, &ox, &oy, &oz, &dx, &dy, &dz, &kind),
              let k = ShapeAxis.Kind(rawValue: kind) else {
            return nil
        }
        return ShapeAxis(origin: SIMD3(ox, oy, oz),
                         direction: SIMD3(dx, dy, dz),
                         kind: k)
    }
}

extension Shape {
    /// All distinct axes of revolution present in the shape, collected from
    /// cylindrical, conical, spherical, toroidal, and surface-of-revolution faces.
    /// Axes that coincide within `tolerance` are deduplicated.
    public func revolutionAxes(tolerance: Double = 1e-6) -> [ShapeAxis] {
        var buffer = [OCCTShapeAxis](repeating: OCCTShapeAxis(), count: 256)
        let count = OCCTShapeRevolutionAxes(handle, tolerance, &buffer, 256)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map { ShapeAxis(buffer[$0]) }
    }

    /// Symmetry axes derived from the principal moments of inertia. Returns one axis
    /// for rotational symmetry, three for spherical symmetry, empty otherwise.
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
    public func symmetryAxes(fractionalTolerance: Double = 1e-4) -> [ShapeAxis] {
        var buffer = [OCCTShapeAxis](repeating: OCCTShapeAxis(), count: 8)
        let count = OCCTShapeSymmetryAxes(handle, fractionalTolerance, &buffer, 8)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map { ShapeAxis(buffer[$0]) }
    }
}

extension Surface {
    /// Axis of a toroidal surface (origin + direction of the rotation axis).
    /// Returns nil if the surface is not a torus.
    public var torusAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard surfaceKind == .torus else { return nil }
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        OCCTSurfaceTorusAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
        return (origin: SIMD3(px, py, pz), direction: SIMD3(dx, dy, dz))
    }

    /// Axis of a surface of revolution (origin + direction).
    /// Returns nil if the surface is not a surface-of-revolution.
    public var revolutionAxis: (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard surfaceKind == .surfaceOfRevolution else { return nil }
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        OCCTSurfaceRevolutionAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
        return (origin: SIMD3(px, py, pz), direction: SIMD3(dx, dy, dz))
    }
}

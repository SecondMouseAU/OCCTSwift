import Foundation
import OCCTBridge
import simd

/// Global properties of a patch of an analytic surface, or of the solid it sweeps: mass, centre of
/// mass, matrix of inertia and the other interrogations of `GProp_GProps`.
///
/// This wraps `GProp_SelGProps` (``Kind/surface``: the patch itself, with its area as the mass) and
/// `GProp_VelGProps` (``Kind/volume``: the solid swept between the axis, or the centre, and the
/// patch). Both take a bounded part of a `gp_Cylinder`, `gp_Cone`, `gp_Sphere` or `gp_Torus`, so a
/// partial turn or a partial range is measured as such, which the whole-shape `Shape` accessors
/// cannot do.
///
/// ```swift
/// // A quarter of a cylinder of radius 5 and height 10, as a surface and as a solid.
/// if let wall = GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10),
///     let wedge = GProps.cylinder(.volume, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10)
/// {
///     wall.mass            // 78.54, the area R * H * (alpha2 - alpha1)
///     wedge.mass           // 196.35, the volume R^2 * H * (alpha2 - alpha1) / 2
///     wall.centreOfMass    // (3.18, 3.18, 5)
///     wedge.matrixOfInertia  // about the centre of mass, axes parallel to the global ones
/// }
/// ```
///
/// - Important: **the reference point of the system is the origin and cannot be changed.**
///   OCCT's `Perform` overloads store the centre of mass in global coordinates, where
///   `GProp_GProps::CentreOfMass` and `MatrixOfInertia` read it relative to the reference point
///   (`SLocation`), so both are right only when that point is the origin. Wrapping `SLocation`
///   would hand back a wrong centre of mass for any other value. Place the patch with `frame`.
///
/// - Note: the matrix of inertia and the centre of mass of the cylinder, sphere and torus overloads
///   and of the cone's are right only on a kernel carrying patches `0050`, `0051`, `0055` and
///   `0057` (#2992, #3010, #3091). The pinned release asset predates them, so against it a
///   measurement that depends on them is wrong; see `docs/reference/GProps.md`.
///
/// Not `Sendable`: ``add(_:density:)`` mutates the handle.
public final class GProps {

    /// Which `GProp` class computes the patch.
    public enum Kind: Sendable {
        /// `GProp_SelGProps`: the surface patch itself, with its area as the mass.
        case surface
        /// `GProp_VelGProps`: the solid swept between the axis (the centre, for a sphere; the
        /// circle through the centres of the tube, for a torus) and the patch.
        case volume
    }

    /// The placement of the surface, as `gp_Ax3`.
    public struct Frame: Sendable, Equatable {
        /// The location of the surface: a point on its axis.
        public var origin: SIMD3<Double>
        /// The main direction, the axis of the surface.
        ///
        /// Need not be a unit vector, and must not be zero: the factories return nil for a zero axis.
        public var axis: SIMD3<Double>
        /// The X direction the angle is measured from.
        ///
        /// Nil lets OCCT choose one. OCCT makes it orthogonal to `axis`, so it must not be parallel to
        /// it: the factories return nil then.
        public var xDirection: SIMD3<Double>?

        /// A frame at `origin` with the main direction `axis`.
        public init(
            origin: SIMD3<Double> = .zero,
            axis: SIMD3<Double> = SIMD3(0, 0, 1),
            xDirection: SIMD3<Double>? = nil
        ) {
            self.origin = origin
            self.axis = axis
            self.xDirection = xDirection
        }

        fileprivate var bridged: OCCTGPropsFrame {
            let x = xDirection ?? .zero
            return OCCTGPropsFrame(
                ox: origin.x, oy: origin.y, oz: origin.z,
                zx: axis.x, zy: axis.y, zz: axis.z,
                xx: x.x, xy: x.y, xz: x.z,
                hasXDirection: xDirection != nil)
        }
    }

    /// The principal properties of the system, from `GProp_GProps::PrincipalProperties`.
    public struct PrincipalProperties: Sendable, Equatable {
        /// The principal moments of inertia, Ixx, Iyy and Izz.
        public var moments: SIMD3<Double>
        /// The principal radii of gyration, Rxx, Ryy and Rzz.
        public var radiiOfGyration: SIMD3<Double>
        /// The first axis of inertia: the eigenvector for the first moment.
        public var firstAxis: SIMD3<Double>
        /// The second axis of inertia.
        public var secondAxis: SIMD3<Double>
        /// The third axis of inertia.
        public var thirdAxis: SIMD3<Double>
        /// Whether two of the moments are equal, to OCCT's relative tolerance of 1e-10.
        ///
        /// With a symmetry axis the two matching axes of inertia are any pair in their plane.
        public var hasSymmetryAxis: Bool
        /// Whether all three moments are equal, to the same tolerance.
        public var hasSymmetryPoint: Bool
    }

    private let handle: OCCTGPropsRef

    private init?(_ handle: OCCTGPropsRef?) {
        guard let handle else { return nil }
        self.handle = handle
    }

    deinit {
        OCCTGPropsRelease(handle)
    }

    // MARK: - Construction

    /// A patch of a cylinder: `GProp_SelGProps` or `GProp_VelGProps` `Perform(gp_Cylinder, ...)`.
    ///
    /// - Parameters:
    ///   - kind: The surface patch or the solid swept between the axis and it.
    ///   - frame: The placement of the cylinder.
    ///   - radius: The radius, not negative.
    ///   - alpha1: The angle about the axis where the patch starts, in radians from the X direction.
    ///   - alpha2: The angle where it ends, above `alpha1`.
    ///   - z1: The height along the axis where the patch starts.
    ///   - z2: The height where it ends, above `z1`.
    /// - Returns: nil when OCCT rejects the input (a negative radius, a zero axis, an X direction
    ///   along the axis), when a range is empty, reversed or not finite, or when the result is not a
    ///   measurement (not finite).
    ///
    /// ```swift
    /// let full = GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 10)
    /// full?.mass                          // 314.16, 2 pi R H
    /// full?.momentOfInertia(about: .zero, direction: SIMD3(0, 0, 1))   // 7853.98, 2 pi R^3 H
    /// ```
    public static func cylinder(
        _ kind: Kind,
        frame: Frame = Frame(),
        radius: Double,
        alpha1: Double,
        alpha2: Double,
        z1: Double,
        z2: Double
    ) -> GProps? {
        GProps(
            OCCTGPropsCylinder(kind == .volume, frame.bridged, radius, alpha1, alpha2, z1, z2))
    }

    /// A patch of a cone: `GProp_SelGProps` or `GProp_VelGProps` `Perform(gp_Cone, ...)`.
    ///
    /// - Parameters:
    ///   - kind: The surface patch or the solid swept between the axis and it.
    ///   - frame: The placement of the cone.
    ///   - semiAngle: The half angle at the apex, in radians. OCCT requires it strictly between
    ///     zero and a right angle in magnitude, and a negative one runs `z` toward the apex.
    ///   - refRadius: The radius of the reference circle at the location, not negative.
    ///   - alpha1: The angle about the axis where the patch starts.
    ///   - alpha2: The angle where it ends, above `alpha1`.
    ///   - z1: The distance along the generatrix, from the reference circle, where it starts.
    ///   - z2: The distance where it ends, above `z1`.
    /// - Returns: nil on the same grounds as ``cylinder(_:frame:radius:alpha1:alpha2:z1:z2:)``.
    ///
    /// ```swift
    /// let frustum = GProps.cone(
    ///     .volume, semiAngle: .pi / 6, refRadius: 5, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 10)
    /// frustum?.mass   // 1/3 pi h (R1^2 + R1 R2 + R2^2), h = 10 cos(pi / 6)
    /// ```
    public static func cone(
        _ kind: Kind,
        frame: Frame = Frame(),
        semiAngle: Double,
        refRadius: Double,
        alpha1: Double,
        alpha2: Double,
        z1: Double,
        z2: Double
    ) -> GProps? {
        GProps(
            OCCTGPropsCone(
                kind == .volume, frame.bridged, semiAngle, refRadius, alpha1, alpha2, z1, z2))
    }

    /// A patch of a sphere: `GProp_SelGProps` or `GProp_VelGProps` `Perform(gp_Sphere, ...)`.
    ///
    /// The ranges are used as given. Latitude outside `-pi/2 ... pi/2` is not a patch of the
    /// sphere, and OCCT's closed form integrates a signed element there.
    ///
    /// - Parameters:
    ///   - kind: The surface patch or the solid swept between the centre and it.
    ///   - frame: The placement of the sphere: `origin` is its centre.
    ///   - radius: The radius, not negative.
    ///   - teta1: The longitude where the patch starts, from the X direction about the axis.
    ///   - teta2: The longitude where it ends, above `teta1`.
    ///   - alpha1: The latitude where it starts, from the equatorial plane.
    ///   - alpha2: The latitude where it ends, above `alpha1`.
    /// - Returns: nil on the same grounds as ``cylinder(_:frame:radius:alpha1:alpha2:z1:z2:)``.
    ///
    /// ```swift
    /// let cap = GProps.sphere(
    ///     .volume, radius: 5, teta1: 0, teta2: 2 * .pi, alpha1: 0, alpha2: .pi / 2)
    /// cap?.mass            // 261.80, half of 4/3 pi R^3
    /// cap?.centreOfMass    // (0, 0, 1.875), that is 3 R / 8 up the axis
    /// ```
    public static func sphere(
        _ kind: Kind,
        frame: Frame = Frame(),
        radius: Double,
        teta1: Double,
        teta2: Double,
        alpha1: Double,
        alpha2: Double
    ) -> GProps? {
        GProps(
            OCCTGPropsSphere(kind == .volume, frame.bridged, radius, teta1, teta2, alpha1, alpha2))
    }

    /// A patch of a torus: `GProp_SelGProps` or `GProp_VelGProps` `Perform(gp_Torus, ...)`.
    ///
    /// For ``Kind/volume`` the solid is the one swept by the segment from the circle through the
    /// centres of the tube to the patch, so a full turn about the tube is the whole solid torus.
    ///
    /// - Parameters:
    ///   - kind: The surface patch or the solid swept between the tube's centre circle and it.
    ///   - frame: The placement of the torus.
    ///   - majorRadius: The radius of the circle through the centres of the tube, not negative.
    ///   - minorRadius: The radius of the tube, not negative.
    ///   - teta1: The angle about the axis where the patch starts.
    ///   - teta2: The angle where it ends, above `teta1`.
    ///   - alpha1: The angle about the tube where it starts, from the outer equator.
    ///   - alpha2: The angle where it ends, above `alpha1`.
    /// - Returns: nil on the same grounds as ``cylinder(_:frame:radius:alpha1:alpha2:z1:z2:)``.
    ///
    /// ```swift
    /// let ring = GProps.torus(
    ///     .volume, majorRadius: 8, minorRadius: 2,
    ///     teta1: 0, teta2: 2 * .pi, alpha1: 0, alpha2: 2 * .pi)
    /// ring?.mass   // 2 pi^2 R r^2, 631.65
    /// ```
    public static func torus(
        _ kind: Kind,
        frame: Frame = Frame(),
        majorRadius: Double,
        minorRadius: Double,
        teta1: Double,
        teta2: Double,
        alpha1: Double,
        alpha2: Double
    ) -> GProps? {
        GProps(
            OCCTGPropsTorus(
                kind == .volume, frame.bridged, majorRadius, minorRadius, teta1, teta2, alpha1,
                alpha2))
    }

    // MARK: - Interrogation

    /// The mass: the area of a ``Kind/surface`` patch, the volume of a ``Kind/volume`` one, times
    /// any density composed in with ``add(_:density:)``. `GProp_GProps::Mass`.
    public var mass: Double {
        var m = 0.0
        _ = OCCTGPropsMass(handle, &m)
        return m
    }

    /// The centre of mass, in global coordinates. `GProp_GProps::CentreOfMass`.
    public var centreOfMass: SIMD3<Double> {
        var v = [Double](repeating: 0, count: 3)
        _ = OCCTGPropsCentreOfMass(handle, &v)
        return SIMD3(v[0], v[1], v[2])
    }

    /// The matrix of inertia about the centre of mass, in axes parallel to the global ones.
    /// `GProp_GProps::MatrixOfInertia`.
    public var matrixOfInertia: simd_double3x3 {
        var v = [Double](repeating: 0, count: 9)
        _ = OCCTGPropsMatrixOfInertia(handle, &v)
        // Column initialiser, not `rows:`: the WASI simd stand-in has no `init(rows:)`. `v` is
        // row-major, so column j is (v[j], v[3 + j], v[6 + j]) and the matrix is unchanged.
        return simd_double3x3(
            SIMD3(v[0], v[3], v[6]),
            SIMD3(v[1], v[4], v[7]),
            SIMD3(v[2], v[5], v[8]))
    }

    /// The static moments, the centre of mass times the mass. `GProp_GProps::StaticMoments`.
    public var staticMoments: SIMD3<Double> {
        var v = [Double](repeating: 0, count: 3)
        _ = OCCTGPropsStaticMoments(handle, &v)
        return SIMD3(v[0], v[1], v[2])
    }

    /// The moment of inertia about the axis through `origin` along `direction`.
    /// `GProp_GProps::MomentOfInertia`.
    ///
    /// ```swift
    /// let plate = GProps.cylinder(.volume, radius: 5, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 2)
    /// plate?.momentOfInertia(about: .zero, direction: SIMD3(0, 0, 1))   // pi R^4 H / 2
    /// ```
    ///
    /// - Returns: nil for a zero or non-finite direction, which OCCT rejects.
    public func momentOfInertia(about origin: SIMD3<Double>, direction: SIMD3<Double>) -> Double? {
        var out = 0.0
        guard
            OCCTGPropsMomentOfInertia(
                handle, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, &out)
        else { return nil }
        return out
    }

    /// The radius of gyration about the axis through `origin` along `direction`, the square root of
    /// the moment of inertia over the mass. `GProp_GProps::RadiusOfGyration`.
    ///
    /// - Returns: nil for a zero or non-finite direction, and where OCCT's answer is not a number
    ///   (a system with no mass, or a negative moment).
    public func radiusOfGyration(about origin: SIMD3<Double>, direction: SIMD3<Double>) -> Double? {
        var out = 0.0
        guard
            OCCTGPropsRadiusOfGyration(
                handle, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, &out)
        else { return nil }
        return out
    }

    /// The principal moments, radii of gyration and axes of inertia.
    /// `GProp_GProps::PrincipalProperties`.
    ///
    /// ```swift
    /// let tube = GProps.cylinder(.surface, radius: 2, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 10)
    /// tube?.principalProperties?.hasSymmetryAxis   // true: Ixx == Iyy
    /// ```
    public var principalProperties: PrincipalProperties? {
        var p = OCCTGPropsPrincipal()
        guard OCCTGPropsPrincipalProperties(handle, &p) else { return nil }
        return PrincipalProperties(
            moments: SIMD3(p.moments.0, p.moments.1, p.moments.2),
            radiiOfGyration: SIMD3(p.radii.0, p.radii.1, p.radii.2),
            firstAxis: SIMD3(p.axes.0, p.axes.1, p.axes.2),
            secondAxis: SIMD3(p.axes.3, p.axes.4, p.axes.5),
            thirdAxis: SIMD3(p.axes.6, p.axes.7, p.axes.8),
            hasSymmetryAxis: p.hasSymmetryAxis,
            hasSymmetryPoint: p.hasSymmetryPoint)
    }

    /// Whether the system has a symmetry axis and a symmetry point at a relative `tolerance`:
    /// `GProp_PrincipalProps::HasSymmetryAxis(tolerance)` and `HasSymmetryPoint(tolerance)`.
    ///
    /// - Returns: nil for a negative or non-finite tolerance.
    public func symmetry(tolerance: Double) -> (hasAxis: Bool, hasPoint: Bool)? {
        var axis = false
        var point = false
        guard OCCTGPropsPrincipalSymmetry(handle, tolerance, &axis, &point) else { return nil }
        return (axis, point)
    }

    // MARK: - Composition

    /// Composes another system into this one with a density.
    ///
    /// This is `GProp_GProps::Add`. Both keep the origin as their reference point, so Huygens'
    /// theorem is not needed to bring them together.
    ///
    /// The mass becomes this mass plus `item.mass * density`, and the centre of mass and the matrix
    /// of inertia follow.
    ///
    /// ```swift
    /// let a = GProps.sphere(.volume, radius: 2, teta1: 0, teta2: 2 * .pi, alpha1: -.pi / 2, alpha2: .pi / 2)
    /// let b = GProps.cylinder(.volume, radius: 1, alpha1: 0, alpha2: 2 * .pi, z1: 2, z2: 6)
    /// if let a, let b { a.add(b, density: 2) }
    /// ```
    ///
    /// - Returns: false, and leaves this system as it was, when `density` is not above
    ///   `gp::Resolution()` (OCCT throws then) or the composition is not a measurement.
    @discardableResult
    public func add(_ item: GProps, density: Double = 1) -> Bool {
        OCCTGPropsAdd(handle, item.handle, density)
    }
}

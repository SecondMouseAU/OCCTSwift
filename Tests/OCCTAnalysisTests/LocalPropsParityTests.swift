import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #494: the Local* local-properties family agrees with its canonical siblings

/// `Surface.localCurvatures`/`localCurvatureDirections` and `Curve3D.localCurvature`/`localTangent`/
/// `localNormal`/`localCentreOfCurvature` read the same `GeomLProp_SLProps`/`GeomLProp_CLProps`
/// quantities as `Surface.curvatures`/`gaussianCurvature`/`meanCurvature`/`principalCurvatures` and
/// `Curve3D.curvature`/`tangentDirection`/`normal`/`centerOfCurvature`, differing only in shape:
/// several scalars per call, and an optional rather than a zero fallback.
///
/// They used to construct their props with a hardcoded `1e-10` resolution where the canonical family
/// passes `Precision::Confusion()` (`1e-7`), three decades apart, and *more* permissive, since the
/// null-derivative test is `SquareMagnitude() > resolution * resolution`. #405/PR #425 converged
/// three Surface entry points onto the shared value but never inventoried this family, nor the
/// Curve3D side at all. So for any point whose derivative magnitude landed between the two values
/// the two halves disagreed about whether curvature exists: on the apex cone below, `localCurvatures`
/// reported a defined mean curvature of about -8.7e7 at `v = 1e-8` where every canonical entry point
/// reported the same point undefined.
@Suite("Local* local-properties parity (#494)")
struct LocalPropsParityTests {

    /// A cone with `radius: 0`: the apex sits at `v = 0` and the tangent magnitude falls off
    /// linearly with `v`, so sampling `v` sweeps smoothly through both resolutions' thresholds.
    private static func apexCone() -> Surface {
        Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    }

    /// A cubic Bezier whose first two poles sit `spacing` apart, so `|D1(0)| = 3 * spacing`.
    /// At `spacing == 0` the point is a cusp: the first significant derivative has order 2.
    private static func cuspBezier(spacing: Double) -> Curve3D {
        Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(spacing, 0, 0),
            SIMD3(1, 1, 0), SIMD3(2, 0, 0),
        ])!
    }

    // MARK: Surface

    private func expectSurfaceAgreement(
        _ surface: Surface, u: Double, v: Double,
        _ label: Comment
    ) {
        let local = surface.localCurvatures(u: u, v: v)
        let principal = surface.principalCurvatures(atU: u, v: v)

        // Definedness first: this is the disagreement the issue is about.
        #expect((local != nil) == (principal != nil), label)

        if let local, let principal {
            #expect(local.maxCurvature == principal.kMax, label)
            #expect(local.minCurvature == principal.kMin, label)
            // ...and against the pair-returning and single-scalar entry points.
            // #595: all three are optional now, so agreement covers definedness as well as value.
            let pair = surface.curvatures(u: u, v: v)
            #expect(local.gaussian == pair?.gaussian, label)
            #expect(local.mean == pair?.mean, label)
            #expect(local.gaussian == surface.gaussianCurvature(atU: u, v: v), label)
            #expect(local.mean == surface.meanCurvature(atU: u, v: v), label)
        }

        // Directions carry an extra umbilic rejection, so only the implication holds.
        if surface.localCurvatureDirections(u: u, v: v) != nil {
            #expect(principal != nil, label)
        }
    }

    @Test("Well-conditioned surface points agree")
    func wellConditionedSurfacesAgree() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3)!
        let cone = Self.apexCone()

        for (u, v) in [(0.0, 0.3), (Double.pi / 3, 0.4), (1.2, -0.8)] {
            expectSurfaceAgreement(sphere, u: u, v: v, "sphere u=\(u) v=\(v)")
            expectSurfaceAgreement(cylinder, u: u, v: v, "cylinder u=\(u) v=\(v)")
        }
        for v in [10.0, 1.0, 0.01] {
            expectSurfaceAgreement(cone, u: 0, v: v, "cone v=\(v)")
        }

        // Umbilic is not degenerate: curvature is well defined, there is just no distinguished pair
        // of principal directions, so only the directions call returns nil. The one asymmetry
        // between the two families that is by design rather than drift.
        //
        // Asserted on a plane, not a sphere. OCCT's IsUmbilic() is
        // `|maxCurv - minCurv| < Epsilon(maxCurv)`, a one-ULP test, not a geometric tolerance. A
        // plane's two principal curvatures are both exactly 0, so it always passes; an
        // analytically-umbilic sphere passes only where the two values happen to round to the same
        // double, which depends on the radius and the (u, v). Measured on a sphere of radius 3:
        // umbilic at v = 0, 0.3, 0.5 and -0.7, but not at v = 1, where they differ by exactly one
        // ULP (5.55e-17). Nothing in #494 changed this, IsUmbilic() takes no resolution, but it
        // is why no test here asserts a sphere is detected as umbilic.
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        #expect(plane.localCurvatures(u: 1, v: 2) != nil)
        #expect(plane.localCurvatureDirections(u: 1, v: 2) == nil)
        #expect(cylinder.localCurvatureDirections(u: 0, v: 0.3) != nil)
    }

    /// The Surface regression proper. Every `v` here lands between `1e-10` and
    /// `Precision::Confusion()`, so pre-fix `localCurvatures` returned a value and every canonical
    /// entry point returned nil/zero for the identical point.
    @Test("Inside the old 1e-10 window the two Surface families agree")
    func surfaceToleranceWindowAgrees() {
        let cone = Self.apexCone()
        for v in [1e-9, 1e-8, 1e-7, 3e-7, 1e-6] {
            expectSurfaceAgreement(cone, u: 0, v: v, "cone v=\(v)")
        }

        // The sphere pole approached from just inside: same window, different degeneracy.
        let sphere = Surface.sphere(center: .zero, radius: 3)!
        for delta in [1e-9, 1e-8, 1e-7] {
            expectSurfaceAgreement(sphere, u: 0, v: .pi / 2 - delta, "sphere pole -\(delta)")
        }
    }

    @Test("Genuinely degenerate surface points are undefined for both families")
    func degenerateSurfacePointsAgree() {
        let cone = Self.apexCone()
        #expect(cone.localCurvatures(u: 0, v: 0) == nil)
        #expect(cone.principalCurvatures(atU: 0, v: 0) == nil)
        #expect(cone.localCurvatureDirections(u: 0, v: 0) == nil)

        let sphere = Surface.sphere(center: .zero, radius: 3)!
        for v in [Double.pi / 2, -.pi / 2] {
            expectSurfaceAgreement(sphere, u: 0, v: v, "sphere pole v=\(v)")
        }
    }

    // MARK: Curve3D

    private func expectCurveAgreement(_ curve: Curve3D, at u: Double, _ label: Comment) {
        // The curvature pair this suite used to compare is deliberately absent. #595 found the two
        // spellings had become one call once #494 gave them the same resolution, so it deprecated
        // localCurvature(at:) onto curvature(at:) and deleted OCCTCurve3DLocalCurvature -- which
        // makes `localCurvature == curvature` true by construction and an assertion about nothing.
        // The forwarding itself is covered by Issue595DeprecatedLocalCurvatureTests; the three pairs
        // below are still two bridge functions each, so they still say something.

        let localTangent = curve.localTangent(at: u)
        let tangent = curve.tangentDirection(at: u)
        #expect((localTangent != nil) == (tangent != nil), label)
        if let localTangent, let tangent { #expect(localTangent == tangent, label) }

        let localNormal = curve.localNormal(at: u)
        let normal = curve.normal(at: u)
        #expect((localNormal != nil) == (normal != nil), label)
        if let localNormal, let normal { #expect(localNormal == normal, label) }

        let localCentre = curve.localCentreOfCurvature(at: u)
        let centre = curve.centerOfCurvature(at: u)
        #expect((localCentre != nil) == (centre != nil), label)
        if let localCentre, let centre { #expect(localCentre == centre, label) }
    }

    @Test("Well-conditioned curve parameters agree")
    func wellConditionedCurvesAgree() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        for u in [0.0, 0.7, Double.pi, 2.0] {
            expectCurveAgreement(circle, at: u, "circle u=\(u)")
        }

        let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!
        for u in [0.0, 1.0, -3.0] {
            expectCurveAgreement(line, at: u, "line u=\(u)")
        }

        let bezier = Self.cuspBezier(spacing: 1.0)
        for u in [0.0, 0.25, 0.5, 1.0] {
            expectCurveAgreement(bezier, at: u, "bezier u=\(u)")
        }
    }

    /// The Curve3D regression proper, the half #405 never looked at. Measured pre-fix at
    /// `spacing = 1e-8`, all four pairs disagreed on the same curve at the same parameter:
    ///
    ///   - `localCurvature(at: 0)` returned about 6.7e15, `curvature(at: 0)` returned `RealLast()`
    ///     (`Double.greatestFiniteMagnitude`), 293 orders of magnitude apart.
    ///   - `localTangent(at: 0)` returned `(1, 0, 0)`, `tangentDirection(at: 0)` returned
    ///     `(0.707, 0.707, 0)`. Not a precision difference: the two resolutions disagree about
    ///     which derivative is the first significant one, and OCCT derives the tangent from that
    ///     one, so the reported direction is genuinely different.
    ///   - `localNormal(at: 0)` returned a vector where `normal(at: 0)` returned nil.
    ///   - `localCentreOfCurvature(at: 0)` returned `(0, 1.5e-16, 0)` where
    ///     `centerOfCurvature(at: 0)` returned `(nan, inf, nan)`.
    @Test("Inside the old 1e-10 window the two Curve3D families agree")
    func curveToleranceWindowAgrees() {
        for spacing in [1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-3] {
            expectCurveAgreement(
                Self.cuspBezier(spacing: spacing), at: 0,
                "cusp bezier spacing=\(spacing)")
        }
    }

    // MARK: The 1e-6 pair

    /// `Shape.curveLocalProps(at:)` and `surfaceLocalProps(u:v:)` were the third tolerance in play,
    /// on `1e-6`, the same value #405 removed from `OCCTSurfaceCurvatures`. They report the same
    /// quantities as `Edge`'s and `Face`'s per-scalar entry points, so they have to agree with them.
    ///
    /// `curveLocalProps` also carried a Swift-side copy of the old bridge threshold
    /// (`r.curvature > 1e-10`) to decide whether the normal and centre had been filled in. The
    /// bridge now reports that directly, so the two sides cannot disagree about it.
    @Test("Shape.curveLocalProps agrees with Edge's per-scalar entry points")
    func curveLocalPropsAgreesWithEdge() throws {
        let cylinder = try #require(Shape.cylinder(radius: 10, height: 5))
        let edgeShapes = cylinder.subShapes(ofType: .edge)
        try #require(!edgeShapes.isEmpty)

        for (i, edgeShape) in edgeShapes.enumerated() {
            let edge = try #require(Edge(edgeShape))
            for param in [0.0, 0.5, 1.0, 2.0] {
                let props = edgeShape.curveLocalProps(at: param)
                let label: Comment = "edge \(i) param=\(param)"

                // Edge.curvature returns nil exactly where the tangent is undefined.
                if let curvature = edge.curvature(at: param) {
                    #expect(props.tangent != nil, label)
                    #expect(props.curvature == curvature, label)
                } else {
                    #expect(props.tangent == nil, label)
                }

                if let tangent = props.tangent {
                    #expect(edge.tangent(at: param) == tangent, label)
                }
                // The aggregate and per-scalar entry points must agree on definedness, which is
                // what the 1e-6/1e-7 split used to break.
                #expect((props.normal != nil) == (edge.normal(at: param) != nil), label)
                #expect(
                    (props.centerOfCurvature != nil)
                        == (edge.centerOfCurvature(at: param) != nil), label)
                if let n = props.normal { #expect(edge.normal(at: param) == n, label) }
                if let c = props.centerOfCurvature {
                    #expect(edge.centerOfCurvature(at: param) == c, label)
                    #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite, label)
                }
            }
        }
    }

    /// The discriminating half of the previous test: a cusped edge, where `curveLocalProps`'
    /// `1e-6` resolution put it three decades away from `Edge`'s `Precision::Confusion()`, and
    /// where the `RealLast()` sentinel reached `CentreOfCurvature()` through both.
    @Test("Shape.curveLocalProps agrees with Edge on a cusped edge")
    func curveLocalPropsAgreesOnCusp() throws {
        for spacing in [0.0, 1e-12, 1e-9, 1e-8, 1e-7] {
            let curve = Self.cuspBezier(spacing: spacing)
            let edgeShape = try #require(Shape.edgeFromCurve(curve))
            let edge = try #require(Edge(edgeShape))
            let props = edgeShape.curveLocalProps(at: 0)
            let label: Comment = "cusp edge spacing=\(spacing)"

            #expect(props.curvature == (edge.curvature(at: 0) ?? 0), label)
            #expect((props.normal != nil) == (edge.normal(at: 0) != nil), label)
            #expect(
                (props.centerOfCurvature != nil)
                    == (edge.centerOfCurvature(at: 0) != nil), label)

            // Where the curvature is OCCT's infinite sentinel there is no centre to report. Not
            // every spacing here reaches that: from 1e-7 up the first derivative clears
            // Precision:Confusion(), so the curvature is finite and a centre does exist, which
            // is why this is keyed off the reported curvature rather than asserted for all.
            if props.curvature == .greatestFiniteMagnitude {
                #expect(props.centerOfCurvature == nil, label)
                #expect(edge.centerOfCurvature(at: 0) == nil, label)
                #expect(props.normal == nil, label)
            }
            for p in [props.centerOfCurvature, props.normal, props.tangent] {
                if let p { #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, label) }
            }
        }
    }

    @Test("Shape.surfaceLocalProps agrees with Face's per-scalar entry points")
    func surfaceLocalPropsAgreesWithFace() throws {
        let cylinder = try #require(Shape.cylinder(radius: 10, height: 5))
        let faceShapes = cylinder.subShapes(ofType: .face)
        try #require(!faceShapes.isEmpty)

        for (i, faceShape) in faceShapes.enumerated() {
            let face = try #require(Face(faceShape))
            for (u, v) in [(0.0, 0.0), (0.5, 1.0), (1.2, 2.0)] {
                let props = faceShape.surfaceLocalProps(u: u, v: v)
                let label: Comment = "face \(i) u=\(u) v=\(v)"

                #expect((props.normal != nil) == (face.normal(atU: u, v: v) != nil), label)
                #expect(
                    props.gaussianCurvature == (face.gaussianCurvature(atU: u, v: v) ?? 0),
                    label)
                #expect(props.meanCurvature == (face.meanCurvature(atU: u, v: v) ?? 0), label)
                if let principal = face.principalCurvatures(atU: u, v: v) {
                    #expect(props.minCurvature == principal.kMin, label)
                    #expect(props.maxCurvature == principal.kMax, label)
                }
            }
        }
    }

    /// The discriminating half: a cone's lateral face sampled approaching its apex. `v` values in
    /// the `(1e-7, 1e-6)` band are exactly where `surfaceLocalProps`' old `1e-6` called curvature
    /// undefined and `Face`'s `Precision::Confusion()` entry points called it defined.
    @Test("Shape.surfaceLocalProps agrees with Face approaching a cone apex")
    func surfaceLocalPropsAgreesNearConeApex() throws {
        let cone = try #require(Shape.cone(bottomRadius: 5, topRadius: 0, height: 10))
        // The lateral face is the one whose curvature varies with v; a planar cap's does not.
        for faceShape in cone.subShapes(ofType: .face) {
            let face = try #require(Face(faceShape))
            for v in [1e-8, 1e-7, 5e-7, 1e-6, 1e-5, 1e-3, 1.0] {
                let props = faceShape.surfaceLocalProps(u: 0, v: v)
                let label: Comment = "cone face v=\(v)"
                #expect(
                    props.gaussianCurvature == (face.gaussianCurvature(atU: 0, v: v) ?? 0),
                    label)
                #expect(props.meanCurvature == (face.meanCurvature(atU: 0, v: v) ?? 0), label)
                #expect(
                    (face.principalCurvatures(atU: 0, v: v) != nil) == props.curvatureDefined,
                    label)
            }
        }
    }

    // MARK: The RealLast() sentinel

    /// A cusp makes OCCT's `Curvature()` return `RealLast()`, meaning infinite curvature. Every
    /// bridge gate that inverted a curvature only asked whether it was *big enough*, which the
    /// sentinel trivially passes, and `LProp_CurveUtils::Curvature()` returns it without assigning
    /// the curvature field `CentreOfCurvature()` then divides by, so the caller got
    /// `(nan, inf, nan)` reported as a successfully computed point. Both halves of the pair did it.
    @Test("A cusp's infinite curvature yields no centre of curvature, not a NaN one")
    func cuspCentreOfCurvatureIsUndefined() {
        for spacing in [0.0, 1e-14, 1e-12, 1e-11] {
            let curve = Self.cuspBezier(spacing: spacing)
            let label: Comment = "cusp bezier spacing=\(spacing)"

            // The sentinel really is what OCCT reports here, otherwise this test proves nothing.
            #expect(curve.curvature(at: 0) == .greatestFiniteMagnitude, label)

            #expect(curve.centerOfCurvature(at: 0) == nil, label)
            #expect(curve.localCentreOfCurvature(at: 0) == nil, label)
        }
    }

    /// The invariant behind the previous test, stated once for every local-properties entry point:
    /// a returned value is a real number. `nil`/zero means "undefined"; NaN and infinity are never
    /// answers.
    @Test("No local-properties entry point returns a non-finite number")
    func localPropsNeverReturnNonFinite() {
        let curves: [(String, Curve3D)] = [
            ("cusp d=0", Self.cuspBezier(spacing: 0)),
            ("cusp d=1e-12", Self.cuspBezier(spacing: 1e-12)),
            ("cusp d=1e-8", Self.cuspBezier(spacing: 1e-8)),
            ("circle", Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!),
            ("line", Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!),
        ]
        for (name, curve) in curves {
            for u in [0.0, 1e-9, 0.5, 1.0] {
                let label: Comment = "\(name) u=\(u)"
                // #595: nil is "undefined", which this invariant allows; what it forbids is a
                // reported NaN or infinity. localCurvature is gone from the list because it is now
                // the same call as curvature(at:).
                if let k = curve.curvature(at: u) { #expect(k.isFinite, label) }
                for p in [
                    curve.centerOfCurvature(at: u), curve.localCentreOfCurvature(at: u),
                    curve.normal(at: u), curve.localNormal(at: u),
                    curve.tangentDirection(at: u), curve.localTangent(at: u),
                ] {
                    if let p { #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, label) }
                }
            }
        }

        let surfaces: [(String, Surface)] = [
            ("apex cone", Self.apexCone()),
            ("sphere", Surface.sphere(center: .zero, radius: 3)!),
        ]
        for (name, surface) in surfaces {
            for v in [0.0, 1e-9, 1e-8, 1e-7, .pi / 2, 1.0] {
                let label: Comment = "\(name) v=\(v)"
                if let c = surface.localCurvatures(u: 0, v: v) {
                    #expect(c.gaussian.isFinite && c.mean.isFinite, label)
                    #expect(c.maxCurvature.isFinite && c.minCurvature.isFinite, label)
                }
                if let d = surface.localCurvatureDirections(u: 0, v: v) {
                    #expect(d.maxDirection.x.isFinite && d.minDirection.x.isFinite, label)
                }
            }
        }
    }
}

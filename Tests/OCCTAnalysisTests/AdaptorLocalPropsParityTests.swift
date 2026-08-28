import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #529: the adaptor-backed local-properties family agrees with the Geom_-backed one

/// `Shape.faceLProp*` / `Shape.edge*LP` read a face or an edge through a `BRepAdaptor_Surface` /
/// `BRepAdaptor_Curve`; `Face.meanCurvature(atU:v:)` / `Edge.curvature(at:)` and their siblings read
/// the surface or curve underneath directly. In OCCT 8.0 both go through the *same* header-only
/// templates, `BRepLProp_SLProps` is a nine-line `using` alias for the template
/// `GeomLProp_SLProps` also aliases, so the `Resolution` they pass means the same thing, and two
/// entry points passing different values disagree about whether a quantity exists at all.
///
/// #494 converged all 28 `GeomLProp_*` constructions onto `Precision::Confusion()` and left the 18
/// `BRepLProp_*` ones on a literal `1e-6`, a decade looser. Measured on the pinned kernel, that
/// decade is exactly where they disagreed: on a cone face approaching its apex,
/// `faceLPropMeanCurvature` returned 0 (undefined) at `v = 1e-6` where `Face.meanCurvature` returned
/// -8.66e5 for the same point of the same face, and the disagreement ran down to `v = 3e-7`.
///
/// Probes: `Scripts/repro/529-breplprop-resolution/`.
@Suite("BRepLProp/GeomLProp local-properties parity (#529)")
struct AdaptorLocalPropsParityTests {

    /// A cone with `radius: 0`, the apex sits at `v = 0`, and |dS/du| falls off linearly with `v`,
    /// so sweeping `v` walks smoothly through both resolutions' thresholds. The face keeps the apex
    /// out of its own `v` range so the sampled points are all interior.
    private static func apexConeFace() -> (Shape, Face)? {
        guard
            let cone = Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1),
                radius: 0, semiAngle: .pi / 6),
            let shape = Shape.face(from: cone, uRange: 0...(2 * .pi), vRange: (-1.0)...10.0),
            let face = Face(shape)
        else { return nil }
        return (shape, face)
    }

    /// A cubic Bezier edge whose first two poles sit `spacing` apart, so `|D1(0)| = 3 * spacing`.
    private static func cuspBezierEdge(spacing: Double) -> (Shape, Edge)? {
        guard
            let bez = Curve3D.bezier(poles: [
                SIMD3(0, 0, 0), SIMD3(spacing, 0, 0),
                SIMD3(1, 1, 0), SIMD3(2, 0, 0),
            ]),
            let shape = Shape.edgeFromCurve(bez),
            let edge = Edge(shape)
        else { return nil }
        return (shape, edge)
    }

    /// Relative comparison. The two families are not required to agree bit for bit: a
    /// `BRepAdaptor_Curve` evaluates a Bezier or BSpline through an evaluation cache the raw
    /// `Geom_Curve` handle does not use, which moves the last ULP (measured: 0.67461923686773151 vs
    /// 0.6746192368677314 for the same curvature). Definedness, the thing #529 is about, is asserted
    /// exactly.
    private func expectClose(_ lhs: Double, _ rhs: Double, _ label: Comment) {
        let scale = max(abs(lhs), abs(rhs), 1.0)
        #expect(abs(lhs - rhs) <= 1e-9 * scale, label)
    }

    /// Definedness first, then the value. Since #583 both families can say "no value here", so the
    /// two halves of the parity claim are separable: the suite used to be able to assert only the
    /// second, and only where the `Geom_` side happened to report one.
    private func expectAgree(_ adaptor: Double?, _ geom: Double?, _ label: Comment) {
        #expect((adaptor != nil) == (geom != nil), label)
        if let adaptor, let geom { expectClose(adaptor, geom, label) }
    }

    // MARK: Face

    /// The regression proper, on the surface side. Every `v` from 3e-7 up to 1e-6 lands between
    /// `Precision::Confusion()` and the old `1e-6`, so pre-fix `faceLPropMeanCurvature` returned 0
    /// for a point where `Face.meanCurvature` returned a large negative number.
    @Test("Inside the old 1e-6 window the two face families agree")
    func faceToleranceWindowAgrees() {
        guard let (shape, face) = Self.apexConeFace() else {
            Issue.record("could not build the apex cone face")
            return
        }

        for v in [3e-7, 5e-7, 1e-6, 1.5e-6, 3e-6, 1e-5, 1e-2, 1.0] {
            let label: Comment = "cone v=\(v)"
            guard let mean = face.meanCurvature(atU: 0, v: v),
                let gaussian = face.gaussianCurvature(atU: 0, v: v)
            else {
                Issue.record(
                    "Face.meanCurvature undefined at v=\(v), which the probe reports as defined")
                continue
            }
            #expect(mean != 0, label)
            expectAgree(shape.faceLPropMeanCurvature(u: 0, v: v), mean, label)
            expectAgree(shape.faceLPropGaussianCurvature(u: 0, v: v), gaussian, label)
        }
    }

    /// Both directions now, at every `v`, including the ones past the gate, where the claim is
    /// that *neither* family reports a value. The `continue` this used to take when the `Geom_`
    /// side returned nil was the workaround: it skipped exactly the rows the fix is about.
    @Test("Principal curvatures agree, including about where they stop existing")
    func facePrincipalCurvaturesAgree() {
        guard let (shape, face) = Self.apexConeFace() else {
            Issue.record("could not build the apex cone face")
            return
        }
        for v in [-1e-9, 0.0, 1e-9, 5e-7, 1e-6, 1e-3, 2.0] {
            let label: Comment = "cone v=\(v)"
            let principal = face.principalCurvatures(atU: 0.4, v: v)
            expectAgree(shape.faceLPropMaxCurvature(u: 0.4, v: v), principal?.kMax, label)
            expectAgree(shape.faceLPropMinCurvature(u: 0.4, v: v), principal?.kMin, label)
        }
    }

    /// A well-conditioned control, so the suite is not only about degenerate points.
    @Test("Ordinary points on a sphere and a cylinder agree")
    func ordinaryFacePointsAgree() {
        let shapes: [(String, Shape?)] = [
            ("sphere", Shape.sphere(radius: 5)),
            ("cylinder", Shape.cylinder(radius: 3, height: 12)),
        ]
        for (name, solid) in shapes {
            guard let solid else {
                Issue.record("\(name) returned nil")
                continue
            }
            for faceShape in solid.subShapes(ofType: .face) {
                guard let face = Face(faceShape) else { continue }
                for (u, v) in [(0.3, 0.2), (1.1, -0.4), (2.0, 0.9)] {
                    let label: Comment = "\(name) u=\(u) v=\(v)"
                    expectAgree(
                        faceShape.faceLPropMeanCurvature(u: u, v: v),
                        face.meanCurvature(atU: u, v: v), label)
                    expectAgree(
                        faceShape.faceLPropGaussianCurvature(u: u, v: v),
                        face.gaussianCurvature(atU: u, v: v), label)
                    // The normal is reported by both, but only the Geom_ spelling applies the
                    // face's orientation, so they agree up to sign, a contract difference, not
                    // drift, and worth pinning so it is not mistaken for one later.
                    let adaptorNormal = faceShape.faceLPropNormal(u: u, v: v)
                    let orientedNormal = face.normal(atU: u, v: v)
                    #expect((adaptorNormal != nil) == (orientedNormal != nil), label)
                    if let adaptorNormal, let orientedNormal {
                        let dot = simd_dot(adaptorNormal, orientedNormal)
                        #expect(abs(abs(dot) - 1.0) < 1e-9, label)
                    }
                }
            }
        }
    }

    // MARK: Edge

    /// The curve-side regression. At a pole spacing of 3e-7 the first derivative at `u = 0` is
    /// 9e-7: significant at `Precision::Confusion()`, null at `1e-6`. Pre-fix the adaptor family
    /// answered `RealLast()` (infinite curvature, the cusp sentinel) where the Geom_ family answered
    /// 7.4e12.
    @Test("Inside the old 1e-6 window the two edge families agree")
    func edgeToleranceWindowAgrees() {
        for spacing in [3e-7, 5e-7, 1e-6, 1e-5, 1e-3] {
            guard let (shape, edge) = Self.cuspBezierEdge(spacing: spacing) else {
                Issue.record("could not build the Bezier edge at spacing \(spacing)")
                continue
            }
            let label: Comment = "spacing=\(spacing)"
            guard let curvature = edge.curvature(at: 0) else {
                Issue.record("Edge.curvature undefined at spacing \(spacing)")
                continue
            }
            #expect(curvature != .greatestFiniteMagnitude, label)
            guard let adaptorCurvature = shape.edgeCurvatureLP(at: 0) else {
                Issue.record("edgeCurvatureLP undefined at spacing \(spacing)")
                continue
            }
            expectClose(adaptorCurvature, curvature, label)

            let adaptorCentre = shape.edgeCentreOfCurvature(at: 0)
            let geomCentre = edge.centerOfCurvature(at: 0)
            #expect((adaptorCentre != nil) == (geomCentre != nil), label)
            if let adaptorCentre, let geomCentre {
                expectClose(adaptorCentre.x, geomCentre.x, label)
                expectClose(adaptorCentre.y, geomCentre.y, label)
                expectClose(adaptorCentre.z, geomCentre.z, label)
            }
        }
    }

    /// The `RealLast()` defect, on the adaptor side this time. `CentreOfCurvature()` tests only
    /// `|Curvature()| <= resolution`, which the infinite-curvature sentinel passes, and then divides
    /// by the `myCurvature` field the sentinel path never assigned, so a near-cusp came back as a
    /// point of `(nan, inf, nan)`, reported as a success.
    @Test("A cusp has no centre of curvature and no normal, and does not fake one")
    func cuspHasNoCentreOfCurvature() {
        for spacing in [0.0, 1e-12, 1e-9, 1e-8] {
            guard let (shape, edge) = Self.cuspBezierEdge(spacing: spacing) else {
                Issue.record("could not build the Bezier edge at spacing \(spacing)")
                continue
            }
            let label: Comment = "spacing=\(spacing)"
            #expect(shape.edgeCentreOfCurvature(at: 0) == nil, label)
            #expect(shape.edgeNormalLP(at: 0) == nil, label)
            // Both families agree it is a cusp rather than an ordinary point.
            #expect(edge.centerOfCurvature(at: 0) == nil, label)
            // #595: a cusp is an answer, not an absence -- the sentinel still comes through.
            #expect(shape.edgeCurvatureLP(at: 0) == .greatestFiniteMagnitude, label)
        }
    }

    @Test("A straight edge has no centre of curvature and no normal")
    func straightEdgeHasNoCentreOfCurvature() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let edges = box.subShapes(ofType: .edge)
        #expect(!edges.isEmpty)
        for edgeShape in edges {
            #expect(edgeShape.edgeCentreOfCurvature(at: 5.0) == nil)
            #expect(edgeShape.edgeNormalLP(at: 5.0) == nil)
            // #595: a straight edge reports 0, and reports it as a value rather than as an absence.
            #expect(edgeShape.edgeCurvatureLP(at: 5.0) == 0.0)
            // The point and the derivative are still perfectly well defined there.
            #expect(edgeShape.edgeLPropValue(at: 5.0) != nil)
            #expect(edgeShape.edgeLPropD1(at: 5.0) != nil)
        }
    }

    /// A circle is the case where the centre of curvature has one obvious right answer.
    @Test("A circular edge's centre of curvature is its centre")
    func circleCentreOfCurvature() {
        guard
            let circle = Curve3D.circle(center: SIMD3(1, 2, 0), normal: SIMD3(0, 0, 1), radius: 4),
            let edge = Shape.edgeFromCurve(circle)
        else {
            Issue.record("could not build the circular edge")
            return
        }
        for u in [0.0, 1.0, 2.5, 4.0] {
            guard let centre = edge.edgeCentreOfCurvature(at: u) else {
                Issue.record("no centre of curvature at u=\(u)")
                continue
            }
            #expect(abs(centre.x - 1) < 1e-9, "u=\(u)")
            #expect(abs(centre.y - 2) < 1e-9, "u=\(u)")
            #expect(abs(centre.z) < 1e-9, "u=\(u)")
            #expect(abs((edge.edgeCurvatureLP(at: u) ?? .nan) - 0.25) < 1e-9, "u=\(u)")
        }
    }
}

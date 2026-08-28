import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #595: the curvature getters that spelled "undefined" as zero

/// #583 gave the `Shape.faceLProp*` block a way to say "there is no curvature here" instead of
/// answering `0`. Six more entry points, on `Curve3D`, `Curve2D`, `Surface` and `Shape`, kept the
/// bare double, and a census found three more that decide the same question with a hand-rolled gate:
/// `Curve3D.torsion(at:)`, `Wire.curvature(at:)` and `Surface.curvatures(u:v:)`.
///
/// Every one of them collides, and on ordinary geometry rather than a constructed pathology: a
/// straight curve's curvature, a planar curve's torsion, and the Gaussian curvature of every point
/// of every plane, cylinder and cone are all exactly `0` with the quantity perfectly well defined.
/// Measured in `Scripts/repro/595-curvature-zero-sentinel/`.
///
/// A **cusp** is deliberately not an absence. OCCT reports `RealLast()` there, meaning infinite
/// curvature, and that is a distinct answer a `Double?` has no room for, so it still comes through
/// as `Double.greatestFiniteMagnitude`.
@Suite("Curvature getters report definedness (#595)")
struct Issue595CurvatureDefinednessTests {

    /// Four coincident poles: no derivative of any order is significant, so `IsTangentDefined()` is
    /// false and there is no curvature at all. Two coincident poles is *not* enough, the tangent
    /// search falls through to D2 and OCCT answers with the cusp sentinel instead.
    private static func deadCurve() -> Curve3D? {
        Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(0, 0, 0), SIMD3(0, 0, 0), SIMD3(0, 0, 0)])
    }

    private static func cuspCurve() -> Curve3D? {
        Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)])
    }

    private static func deadCurve2D() -> Curve2D? {
        Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0, 0), SIMD2(0, 0), SIMD2(0, 0)])
    }

    private static func cuspCurve2D() -> Curve2D? {
        Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)])
    }

    // MARK: Curve3D.curvature(at:)

    @Test("A straight curve reports 0; a curve with no tangent reports nothing")
    func curve3DCurvatureSeparatesZeroFromAbsent() throws {
        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))
        // The collision: this used to be the same double the row below returned.
        #expect(line.curvature(at: 3) == 0)

        let dead = try #require(Self.deadCurve())
        #expect(dead.curvature(at: 0.5) == nil)

        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4))
        let k = try #require(circle.curvature(at: 1))
        #expect(abs(k - 0.25) < 1e-12)
    }

    @Test("A cusp's infinite curvature is still an answer, not an absence")
    func curve3DCuspKeepsTheSentinel() throws {
        let cusp = try #require(Self.cuspCurve())
        #expect(cusp.curvature(at: 0) == .greatestFiniteMagnitude)
    }

    // MARK: Curve2D.curvature(at:)

    @Test("Curve2D separates a straight segment's 0 from a degenerate curve's absence")
    func curve2DCurvatureSeparatesZeroFromAbsent() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        #expect(seg.curvature(at: 5) == 0)

        let dead = try #require(Self.deadCurve2D())
        #expect(dead.curvature(at: 0.5) == nil)

        let circle = try #require(Curve2D.circle(center: .zero, radius: 4))
        let k = try #require(circle.curvature(at: 1))
        #expect(abs(k - 0.25) < 1e-12)

        let cusp = try #require(Self.cuspCurve2D())
        #expect(cusp.curvature(at: 0) == .greatestFiniteMagnitude)
    }

    // MARK: Shape.edgeCurvatureLP(at:)

    /// The degeneracy that makes this one more than a theoretical concern: a sphere carries a
    /// degenerate edge at each pole, with no 3D curve at all, and edge traversal does not skip them.
    @Test("A sphere's degenerate pole edge has no curvature, where a box edge has 0")
    func edgeCurvatureLPSeparatesZeroFromAbsent() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxEdges = box.subShapes(ofType: .edge)
        #expect(!boxEdges.isEmpty)
        for edge in boxEdges {
            #expect(edge.edgeCurvatureLP(at: 5.0) == 0.0)
        }

        let sphere = try #require(Shape.sphere(center: .zero, radius: 5))
        let degenerate = sphere.subShapes(ofType: .edge).filter { $0.isEdgeDegenerated }
        #expect(!degenerate.isEmpty, "a sphere carries a degenerate edge at each pole")
        for edge in degenerate {
            #expect(edge.edgeCurvatureLP(at: 0.5) == nil)
        }

        // The other absence this entry point has to express, and the only one that reaches its
        // catch: it takes a Shape, and a Shape need not be an edge at all. TopoDS::Edge throws.
        #expect(box.edgeCurvatureLP(at: 0.5) == nil, "a solid is not an edge")
    }

    // MARK: Surface.gaussianCurvature / meanCurvature / curvatures

    /// The widest collision of the set. A developable surface's Gaussian curvature is exactly `0`
    /// at *every* point, so this used to return the "undefined" value for whole surfaces at a time.
    @Test("A plane, cylinder and cone report a real 0 where a cone apex reports nothing")
    func surfaceCurvatureSeparatesZeroFromAbsent() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(plane.gaussianCurvature(atU: 3, v: 4) == 0)
        #expect(plane.meanCurvature(atU: 3, v: 4) == 0)

        let cylinder = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3))
        let cylK = try #require(cylinder.gaussianCurvature(atU: 1.1, v: 6))
        #expect(cylK == 0)
        let cylH = try #require(cylinder.meanCurvature(atU: 1.1, v: 6))
        #expect(abs(cylH + 1.0 / 6) < 1e-12)

        let cone = try #require(
            Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1),
                radius: 0, semiAngle: .pi / 6))
        let coneK = try #require(cone.gaussianCurvature(atU: 0, v: 1.0))
        #expect(coneK == 0, "a cone is developable away from its apex")
        #expect(cone.gaussianCurvature(atU: 0, v: 0) == nil, "and has no curvature at the apex")
        #expect(cone.meanCurvature(atU: 0, v: 0) == nil)

        let sphere = try #require(Surface.sphere(center: .zero, radius: 5))
        #expect(sphere.gaussianCurvature(atU: 0, v: .pi / 2) == nil, "sphere pole")
        #expect(sphere.meanCurvature(atU: 0, v: .pi / 2) == nil)
    }

    /// The pair-returning form shares one `GeomLProp_SLProps` with the two single-scalar ones and
    /// its doc has always claimed they agree "including on whether curvature is defined at all",
    /// which it could not express while it returned a bare `(0, 0)`.
    @Test("The pair form agrees with the singles on definedness, not just on value")
    func surfaceCurvaturesPairAgreesOnDefinedness() throws {
        let cone = try #require(
            Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1),
                radius: 0, semiAngle: .pi / 6))
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        for (surface, u, v) in [(cone, 0.0, 0.0), (cone, 0.0, 1.0), (plane, 3.0, 4.0)] {
            let pair = surface.curvatures(u: u, v: v)
            #expect(pair?.gaussian == surface.gaussianCurvature(atU: u, v: v), "u=\(u) v=\(v)")
            #expect(pair?.mean == surface.meanCurvature(atU: u, v: v), "u=\(u) v=\(v)")
        }
        #expect(cone.curvatures(u: 0, v: 0) == nil)
        #expect(plane.curvatures(u: 3, v: 4) != nil, "a plane's (0, 0) is an answer")
    }

    // MARK: Curve3D.torsion(at:)

    /// The census entry the issue did not list, and the one whose collision runs the other way: a
    /// **planar** curve's torsion is genuinely `0`, a straight one has no osculating plane at all.
    @Test("A circle reports torsion 0; a straight line reports nothing")
    func torsionSeparatesZeroFromAbsent() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4))
        #expect(circle.torsion(at: 1) == 0)

        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))
        #expect(line.torsion(at: 5) == nil)

        // A non-planar curve, so the test cannot pass by always answering 0.
        let helix = try #require(
            Curve3D.bezier(
                poles: (0..<5).map { i -> SIMD3<Double> in
                    let t = Double(i) * 0.6
                    return SIMD3(cos(t), sin(t), 0.4 * t)
                }))
        let tau = try #require(helix.torsion(at: 0.5))
        #expect(abs(tau) > 0.1)
    }

    // MARK: Wire.curvature(at:)

    /// This one was already `Double?`, but only its error path reached the optional: the
    /// null-derivative branch answered `0`, a straight wire's real curvature.
    @Test("A wire with a null derivative reports nothing, where a straight wire reports 0")
    func wireCurvatureSeparatesZeroFromAbsent() throws {
        let straight = try #require(Wire.line(from: .zero, to: SIMD3(10, 0, 0)))
        let straightK = try #require(straight.curvature(at: 0.5))
        #expect(abs(straightK) < 1e-10)

        let circle = try #require(Wire.circle(radius: 10))
        let circleK = try #require(circle.curvature(at: 0.5))
        #expect(abs(circleK - 0.1) < 1e-6)

        let cusp = try #require(Self.cuspCurve())
        let cuspShape = try #require(Shape.edgeFromCurve(cusp))
        let cuspEdge = try #require(Edge(cuspShape))
        let cuspWire = try #require(Wire.wireFromEdges([cuspEdge]))
        #expect(
            cuspWire.curvature(at: 0) == nil,
            "the first derivative is null at the cusp, and the formula divides by it")
    }
}

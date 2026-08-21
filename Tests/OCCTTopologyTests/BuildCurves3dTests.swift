import Testing
import Foundation
import simd
@testable import OCCTSwift

/// `BRepLib::BuildCurves3d` contract tests (#498).
///
/// The two pre-existing tests for this operation both call it on a box, where every edge already
/// carries a 3D curve, so `BRepLib::BuildCurve3d` returns `true` at its first line and computes
/// nothing. A tolerance of 42 is indistinguishable from 1e-7 there. These tests use an edge that
/// has *only* a pcurve, on a curved support surface, which is the one configuration where the
/// operation does work and the tolerance is observable.
///
/// Ground truth: `Scripts/repro/498-buildcurves3d-triplication/`.
@Suite("BuildCurves3d (#498)")
struct BuildCurves3dTests {

    /// A pcurve-only edge whose 3D geometry is a helix on a cylinder: no 3D curve yet, and a
    /// curved support surface, so the approximation branch runs rather than the planar shortcut.
    private func helicalPCurveOnlyEdge() -> Shape? {
        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 10),
              let pcurve = Curve2D.line(through: SIMD2(0.2, -3.0), direction: SIMD2(0.6, 0.8))
        else { return nil }
        return Shape.edgeOnSurface(pcurve: pcurve, surface: surface, u1: 0, u2: 2)
    }

    @Test("A pcurve-only edge starts with no 3D curve, and buildCurves3d gives it one")
    func buildsTheMissingCurve() {
        guard let edge = helicalPCurveOnlyEdge() else {
            Issue.record("could not build a pcurve-only edge on a cylinder")
            return
        }
        #expect(edge.extractEdgeCurve3D() == nil)

        #expect(edge.buildCurves3d())
        #expect(edge.extractEdgeCurve3D() != nil)
    }

    /// The tolerance is not just an approximation knob: `BRepLib::BuildCurve3d` also makes it the
    /// rebuilt edge's tolerance floor (`max_deviation = max(tolerance, Tolerance)`), so the value
    /// the wrapper defaults to is directly readable off the result.
    @Test("The default tolerance is OCCT's own 1e-5, and it lands on the rebuilt edge")
    func defaultToleranceIsOCCTs() {
        guard let edge = helicalPCurveOnlyEdge() else {
            Issue.record("could not build a pcurve-only edge on a cylinder")
            return
        }
        #expect(edge.buildCurves3d())
        #expect(abs(edge.edgeTolerance - 1e-5) < 1e-12)
    }

    @Test("An explicit tolerance overrides the default in both directions")
    func explicitToleranceIsHonoured() {
        for tolerance in [1e-3, 1e-5, 1e-7] {
            guard let edge = helicalPCurveOnlyEdge() else {
                Issue.record("could not build a pcurve-only edge on a cylinder")
                return
            }
            #expect(edge.buildCurves3d(tolerance: tolerance))
            #expect(abs(edge.edgeTolerance - tolerance) < tolerance * 1e-6)
        }
    }

    /// A tighter tolerance buys a closer curve, which is the whole reason the parameter exists.
    /// Measured in the repro: 1e-5 deviates by 2.6e-6 from the exact helix, 1e-7 by 9.0e-8.
    @Test("A tighter tolerance produces a curve closer to the exact helix")
    func tighterToleranceIsMoreAccurate() {
        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 10),
              let pcurve = Curve2D.line(through: SIMD2(0.2, -3.0), direction: SIMD2(0.6, 0.8))
        else {
            Issue.record("could not build the cylinder and pcurve")
            return
        }

        func maxDeviation(tolerance: Double) -> Double? {
            guard let edge = Shape.edgeOnSurface(pcurve: pcurve, surface: surface, u1: 0, u2: 2),
                  edge.buildCurves3d(tolerance: tolerance),
                  let built = edge.extractEdgeCurve3D()
            else { return nil }

            var worst = 0.0
            for i in 0...100 {
                let t = built.first + (built.last - built.first) * Double(i) / 100.0
                let uv = pcurve.point(at: t)
                let exact = surface.point(atU: uv.x, v: uv.y)
                worst = max(worst, simd_distance(exact, built.curve.point(at: t)))
            }
            return worst
        }

        guard let coarse = maxDeviation(tolerance: 1e-5), let fine = maxDeviation(tolerance: 1e-7) else {
            Issue.record("could not measure the deviation")
            return
        }
        #expect(coarse <= 1e-5)
        #expect(fine <= 1e-7)
        #expect(fine < coarse)
    }

    /// The oldest of the three C entry points returned `void`, discarding this signal. It backed
    /// `allEdgePolylinesIndexed`, which now goes through the bool-returning one.
    @Test("An edge stripped of every representation cannot get a 3D curve, and says so")
    func unbuildableEdgeReportsFailure() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("could not build a box")
            return
        }
        let faces = box.subShapes(ofType: .face)
        guard let edge = box.subShapes(ofType: .edge).first else {
            Issue.record("could not reach a box edge")
            return
        }

        edge.removeEdgeCurve3d()
        for face in faces { edge.removeEdgePCurve(onFace: face) }
        #expect(edge.extractEdgeCurve3D() == nil)

        #expect(edge.buildCurves3d() == false)
        #expect(edge.extractEdgeCurve3D() == nil)
    }

    /// The path the old `void` entry point still has to survive: `allEdgePolylinesIndexed` calls
    /// this on arbitrary shapes, including ones where some edge cannot be rebuilt.
    @Test("allEdgePolylinesIndexed still discretises a shape whose edges all have 3D curves")
    func edgePolylinesUnaffected() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("could not build a box")
            return
        }
        let polylines = box.allEdgePolylinesIndexed(deflection: 0.1)
        #expect(polylines.count == 12)
        #expect(polylines.allSatisfy { $0.points.count >= 2 })
    }
}

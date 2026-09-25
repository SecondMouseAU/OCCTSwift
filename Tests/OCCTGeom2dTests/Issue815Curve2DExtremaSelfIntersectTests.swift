import Foundation
import Testing
import simd

@testable import OCCTSwift

// #815 (Pass 5a of #807, refman coverage audit for tests: geometry primitives): `allExtrema(with:)`
// and `selfIntersections(tolerance:)` were both documented, wrapped `Curve2D` capabilities with no
// test anywhere in the tree (`Scripts/repro/815-refman-coverage-tests-geometry/`). See that
// directory's README for the full census.
@Suite("Curve2D Extrema and Self-Intersection (#815)")
struct Issue815Curve2DExtremaSelfIntersectTests {

    @Test("allExtrema between two separated circles: exactly a nearest and a farthest point pair")
    func allExtremaBetweenSeparatedCircles() throws {
        // Two circles of radius 5, centers 20 apart on the X axis: nearest points (5,0)/(15,0),
        // distance 10; farthest points (-5,0)/(25,0), distance 30. Both are genuine local extrema
        // of the distance function between the two curves, which is exactly what the refman's
        // `Geom2dAPI_ExtremaCurveCurve` (the class this bridges to, see the derivation script)
        // documents itself as computing.
        let c1 = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let c2 = try #require(Curve2D.circle(center: SIMD2(20, 0), radius: 5))
        let results = c1.allExtrema(with: c2)
        #expect(!results.isEmpty)
        let distances = results.map(\.distance).sorted()
        // #1979: the min/max checks were inside `if let` with 0.1 of slack. Geom2dAPI_ExtremaCurveCurve
        // gives four extrema, not the "exactly a nearest and a farthest pair" the title says: the
        // two mixed pairs at distance 20 are extrema too (Scripts/repro/766-geom2d-issue-regressions-b/).
        try #require(distances.count == 4)
        #expect(abs(distances[0] - 10) < 1e-9)
        #expect(abs(distances[1] - 20) < 1e-9)
        #expect(abs(distances[2] - 20) < 1e-9)
        #expect(abs(distances[3] - 30) < 1e-9)
    }

    @Test("Self-intersections of a looped cubic Bezier curve")
    func selfIntersectionsOfLoopedCurve() throws {
        // A cubic Bezier control polygon that crosses itself does not necessarily make the CURVE
        // cross itself (a symmetric "bowtie" polygon like (0,0)-(10,10)-(0,10)-(10,0) is a
        // counterexample: measured directly against this bridge, it produces zero
        // self-intersections, because the curve's own symmetry pairs each point with a distinct
        // mirror point at the same height rather than looping back through it). These control
        // points were chosen by direct measurement against the real bridge (not derived
        // analytically) to produce a genuine, single, interior loop, confirmed at (2.5, 3.0).
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 10), SIMD2(-5, 10), SIMD2(5, 0),
        ]
        let curve = try #require(Curve2D.bezier(poles: poles))
        let hits = curve.selfIntersections()
        // #1979: `if let` with 0.1 of slack; Geom2dAPI_InterCurveCurve gives exactly one, at (2.5, 3).
        try #require(hits.count == 1)
        #expect(abs(hits[0].point.x - 2.5) < 1e-9)
        #expect(abs(hits[0].point.y - 3.0) < 1e-9)
    }

    @Test("A circle (convex, simple) reports no self-intersections")
    func noSelfIntersectionsOnASimpleClosedCurve() throws {
        let circle = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let hits = circle.selfIntersections()
        #expect(hits.isEmpty)
    }
}

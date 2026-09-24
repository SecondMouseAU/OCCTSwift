import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: before #766 each test asserted `segments.count >= 1` inside `if let`, which a bridge that
// returned the input unsplit also satisfies, and the single-span cubic fixture has no interior
// knot to split at. Each test now also runs a two-span cubic whose interior knot at 0.5 has
// multiplicity 2 (C1 there), so a C2 criterion must split it. Values are the kernel's own
// (ShapeUpgrade_SplitCurve3dContinuity / SplitCurve2dContinuity / ConvertCurve2dToBezier, driven
// as the bridge drives them; Scripts/repro/766-healing-shapeupgrade/transcript.txt):
//   single span: 1 piece, (0,0) to (4,0);
//   C1 at 0.5:   2 pieces, (0,0) to (2.5,1.5) and (2.5,1.5) to (5,1).

private let singleSpan3D: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0)]
private let twoSpan3D: [SIMD3<Double>] = [
    SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0), SIMD3(5, 1, 0),
]
private let singleSpan2D: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)]
private let twoSpan2D: [SIMD2<Double>] = [
    SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 2), SIMD2(3, 1), SIMD2(4, 0), SIMD2(5, 1),
]

private func ends(_ c: Curve3D) -> (SIMD3<Double>, SIMD3<Double>) {
    (c.point(at: c.domain.lowerBound), c.point(at: c.domain.upperBound))
}

private func ends(_ c: Curve2D) -> (SIMD2<Double>, SIMD2<Double>) {
    (c.point(at: c.domain.lowerBound), c.point(at: c.domain.upperBound))
}

private func twoSpanCurve2D() throws -> Curve2D {
    try #require(
        Curve2D.bspline(poles: twoSpan2D, knots: [0.0, 0.5, 1.0], multiplicities: [4, 2, 4], degree: 3))
}

/// Checks the two pieces of the C1-at-0.5 fixture.
private func expectTwoPieces2D(_ pieces: [Curve2D]) {
    #expect(pieces.count == 2)
    guard pieces.count == 2 else { return }
    let (a0, a1) = ends(pieces[0])
    let (b0, b1) = ends(pieces[1])
    #expect(simd_distance(a0, SIMD2(0, 0)) < 1e-9)
    #expect(simd_distance(a1, SIMD2(2.5, 1.5)) < 1e-9)
    #expect(simd_distance(b0, SIMD2(2.5, 1.5)) < 1e-9)
    #expect(simd_distance(b1, SIMD2(5, 1)) < 1e-9)
}

@Suite("ShapeUpgrade SplitCurve Tests")
struct ShapeUpgradeSplitCurveTests {

    @Test("split smooth 3D curve")
    func splitSmooth3D() throws {
        let smooth = try #require(
            Curve3D.bspline(poles: singleSpan3D, knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let one = smooth.splitByContinuity(criterion: 2)
        #expect(one.count == 1)
        if let p = one.first {
            let (s, e) = ends(p)
            #expect(simd_distance(s, SIMD3(0, 0, 0)) < 1e-9)
            #expect(simd_distance(e, SIMD3(4, 0, 0)) < 1e-9)
        }

        let kinked = try #require(
            Curve3D.bspline(poles: twoSpan3D, knots: [0.0, 0.5, 1.0], multiplicities: [4, 2, 4], degree: 3))
        let two = kinked.splitByContinuity(criterion: 2)
        #expect(two.count == 2)
        if two.count == 2 {
            let (a0, a1) = ends(two[0])
            let (b0, b1) = ends(two[1])
            #expect(simd_distance(a0, SIMD3(0, 0, 0)) < 1e-9)
            #expect(simd_distance(a1, SIMD3(2.5, 1.5, 0)) < 1e-9)
            #expect(simd_distance(b0, SIMD3(2.5, 1.5, 0)) < 1e-9)
            #expect(simd_distance(b1, SIMD3(5, 1, 0)) < 1e-9)
        }
    }

    @Test("split smooth 2D curve")
    func splitSmooth2D() throws {
        let smooth = try #require(
            Curve2D.bspline(poles: singleSpan2D, knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let one = smooth.splitByContinuity(criterion: 2)
        #expect(one.count == 1)
        if let p = one.first {
            let (s, e) = ends(p)
            #expect(simd_distance(s, SIMD2(0, 0)) < 1e-9)
            #expect(simd_distance(e, SIMD2(4, 0)) < 1e-9)
        }

        expectTwoPieces2D(try twoSpanCurve2D().splitByContinuity(criterion: 2))
    }

    @Test("convert 2D curve to Bezier")
    func convertToBezier() throws {
        // Kernel: every piece ConvertCurve2dToBezier returns is a Geom2d_BezierCurve
        // (GeomAbs_BezierCurve = 5).
        let smooth = try #require(
            Curve2D.bspline(poles: singleSpan2D, knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let one = smooth.convertToBezierSegments()
        #expect(one.count == 1)
        #expect(one.allSatisfy { $0.curveType == 5 })
        if let p = one.first {
            let (s, e) = ends(p)
            #expect(simd_distance(s, SIMD2(0, 0)) < 1e-9)
            #expect(simd_distance(e, SIMD2(4, 0)) < 1e-9)
        }

        let two = try twoSpanCurve2D().convertToBezierSegments()
        #expect(two.allSatisfy { $0.curveType == 5 })
        expectTwoPieces2D(two)
    }
}

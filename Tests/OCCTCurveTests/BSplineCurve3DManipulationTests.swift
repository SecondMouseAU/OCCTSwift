import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.107.0 Tests

// Every expected value is what Geom_BSplineCurve reports for the same GeomAPI_Interpolate curve,
// before or after the same edit (Scripts/repro/766-curve-bspline-manip/transcript.txt). The
// earlier versions wrapped each body in `if let` and asserted bounds such as `knotCount > 0`,
// `degree >= 1` or `knotCount >= nkBefore`, and two asserted nothing at all (isRational,
// removeKnot), so a bridge that skipped the edit or misreported the count passed (#766).
@Suite("BSpline Curve 3D Manipulation Tests")
struct BSplineCurve3DManipulationTests {
    private static let knots: [Double] = [
        0, 3.6055512754639891, 7.2111025509279782, 10.816653826391967, 14.422205101855956,
    ]

    private static func make() -> Curve3D? {
        let c = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ])
        if c == nil { Issue.record("interpolated BSpline not built") }
        return c
    }

    private static func near(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-12 }
    }

    private static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        simd_distance(a, b) < 1e-12
    }

    @Test func knotCount() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.knotCount == 5)
    }

    @Test func poleCount() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.poleCount == 7)
    }

    @Test func degree() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.degree == 3)
    }

    @Test func isRational() {
        guard let bsp = Self.make() else { return }
        // Interpolated BSplines are non-rational
        #expect(!bsp.bspline.isRational)
    }

    @Test func knotsArray() {
        guard let bsp = Self.make() else { return }
        #expect(Self.near(bsp.bspline.knots, Self.knots))
    }

    @Test func multiplicities() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.multiplicities == [4, 1, 1, 1, 4])
    }

    @Test func getPole() {
        guard let bsp = Self.make() else { return }
        #expect(Self.near(bsp.bspline.pole(at: 1), SIMD3(0, 0, 0)))
        #expect(
            Self.near(bsp.bspline.pole(at: 2), SIMD3(0.38888888888888895, 0.83333333333333337, 0)))
        #expect(Self.near(bsp.bspline.pole(at: 7), SIMD3(10, 0, 0)))
    }

    @Test func setPole() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.setPole(at: 3, to: SIMD3(5, 7, 0)))
        #expect(Self.near(bsp.bspline.pole(at: 3), SIMD3(5, 7, 0)))
    }

    @Test func getAndSetWeight() {
        guard let bsp = Self.make() else { return }
        #expect(bsp.bspline.weight(at: 1) == 1.0)
    }

    @Test func insertKnot() {
        guard let bsp = Self.make() else { return }
        // The midpoint of the range is already the third knot, so inserting it there raises that
        // knot's multiplicity to 2 and adds a pole; the knot count does not change.
        let mid = (Self.knots.first! + Self.knots.last!) / 2.0
        #expect(bsp.bspline.insertKnot(u: mid))
        #expect(bsp.bspline.knotCount == 5)
        #expect(bsp.bspline.multiplicities == [4, 1, 2, 1, 4])
        #expect(bsp.bspline.poleCount == 8)
    }

    @Test func segment() {
        guard let bsp = Self.make() else { return }
        let d = bsp.domain
        let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
        let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
        #expect(bsp.bspline.segment(u1: u1, u2: u2))
        #expect(abs(bsp.domain.lowerBound - 3.6055512754639891) < 1e-12)
        #expect(abs(bsp.domain.upperBound - 10.816653826391967) < 1e-12)
        #expect(bsp.bspline.poleCount == 5)
        #expect(simd_distance(bsp.startPoint, SIMD3(2, 3, 0)) < 1e-9)
        #expect(simd_distance(bsp.endPoint, SIMD3(8, 3, 0)) < 1e-9)
    }

    @Test func increaseDegree() {
        guard let bsp = Self.make() else { return }
        let oldDeg = bsp.bspline.degree
        #expect(bsp.bspline.increaseDegree(to: oldDeg + 1))
        #expect(bsp.bspline.degree == 4)
        #expect(bsp.bspline.poleCount == 11)
        #expect(bsp.bspline.multiplicities == [5, 2, 2, 2, 5])
    }

    @Test func resolution() {
        guard let bsp = Self.make() else { return }
        let res = bsp.bspline.resolution(tolerance3d: 0.001)
        #expect(abs(res - 0.00059678090076645284) < 1e-15)
    }

    @Test func setPeriodic() {
        guard let bsp = Self.make() else { return }
        // Setting non-periodic on an already non-periodic curve succeeds and changes nothing.
        #expect(bsp.bspline.setPeriodic(false))
        #expect(!bsp.isPeriodic)
        #expect(bsp.bspline.poleCount == 7)
        #expect(Self.near(bsp.bspline.knots, Self.knots))
    }

    @Test func removeKnot() {
        guard let bsp = Self.make() else { return }
        // Insert a knot first (the third knot goes to multiplicity 2), then remove knot 2 fully:
        // the curve is not changed by more than the 1.0 tolerance, so the kernel accepts it.
        let mid = (Self.knots.first! + Self.knots.last!) / 2.0
        #expect(bsp.bspline.insertKnot(u: mid))
        #expect(bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0))
        #expect(bsp.bspline.knotCount == 4)
        #expect(bsp.bspline.multiplicities == [4, 2, 1, 4])
        #expect(bsp.bspline.poleCount == 7)
    }
}

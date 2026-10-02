import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.107.0 Tests

// Lifted from #2503 on `v5.0.0-766-execution`, re-measured against `main`'s kernel.
//
// Every expected value is what `Geom_BSplineCurve` reports for the same `GeomAPI_Interpolate`
// curve, before or after the same edit (`Scripts/repro/766-curve-bspline-manip/`). The earlier
// version wrapped each body in `if let` and asserted bounds such as `knotCount > 0`,
// `degree >= 1` or `knotCount >= nkBefore`, and two asserted nothing at all (`isRational`,
// `removeKnot`), so a bridge that skipped the edit or misreported the count passed (#766).
//
// The knots are the chord lengths of the input polyline: |(2,3)-(0,0)| = sqrt(13) and each
// following segment is the same length, so the five knots are multiples of sqrt(13).
@Suite("BSpline Curve 3D Manipulation Tests")
struct BSplineCurve3DManipulationTests {
    private static let knots: [Double] = [
        0, 3.6055512754639891, 7.2111025509279782, 10.816653826391967, 14.422205101855956,
    ]

    private func make() throws -> Curve3D {
        try #require(
            Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
            ]), "interpolated BSpline fixture")
    }

    private static func near(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-12 }
    }

    private static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        simd_distance(a, b) < 1e-12
    }

    @Test func knotCount() throws {
        let bsp = try make()
        #expect(bsp.bspline.knotCount == 5)
    }

    @Test func poleCount() throws {
        let bsp = try make()
        // Multiplicities [4, 1, 1, 1, 4] sum to 11, minus degree + 1.
        #expect(bsp.bspline.poleCount == 7)
    }

    @Test func degree() throws {
        let bsp = try make()
        #expect(bsp.bspline.degree == 3)
    }

    @Test func isRational() throws {
        let bsp = try make()
        // Interpolated BSplines are non-rational. Was a discarded read.
        #expect(!bsp.bspline.isRational)
    }

    @Test func knotsArray() throws {
        let bsp = try make()
        #expect(Self.near(bsp.bspline.knots, Self.knots))
    }

    @Test func multiplicities() throws {
        let bsp = try make()
        #expect(bsp.bspline.multiplicities == [4, 1, 1, 1, 4])
    }

    @Test func getPole() throws {
        let bsp = try make()
        // The end poles are the interpolated end points; pole 2 is the kernel's own.
        #expect(Self.near(bsp.bspline.pole(at: 1), SIMD3(0, 0, 0)))
        #expect(
            Self.near(bsp.bspline.pole(at: 2), SIMD3(0.38888888888888895, 0.83333333333333337, 0)))
        #expect(Self.near(bsp.bspline.pole(at: 7), SIMD3(10, 0, 0)))
    }

    @Test func setPole() throws {
        let bsp = try make()
        #expect(bsp.bspline.setPole(at: 3, to: SIMD3(5, 7, 0)))
        // Was `abs(p.y - 7.0) < 1e-6`, which said nothing about x or z.
        #expect(Self.near(bsp.bspline.pole(at: 3), SIMD3(5, 7, 0)))
    }

    @Test func getAndSetWeight() throws {
        let bsp = try make()
        #expect(bsp.bspline.weight(at: 1) == 1.0)
    }

    @Test func insertKnot() throws {
        let bsp = try make()
        // The midpoint of the range IS the third knot, so inserting it there raises that knot's
        // multiplicity to 2 and adds a pole; the knot count does not change. The old
        // `knotCount >= nkBefore` was true for every outcome including "did nothing".
        let mid = (Self.knots.first! + Self.knots.last!) / 2.0
        #expect(bsp.bspline.insertKnot(u: mid))
        #expect(bsp.bspline.knotCount == 5)
        #expect(bsp.bspline.multiplicities == [4, 1, 2, 1, 4])
        #expect(bsp.bspline.poleCount == 8)
    }

    @Test func segment() throws {
        let bsp = try make()
        let d = bsp.domain
        let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
        let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
        #expect(bsp.bspline.segment(u1: u1, u2: u2))
        // 25% and 75% of the chord-length range are exactly knots 2 and 4, which are the second
        // and fourth interpolation points, so the trimmed curve runs (2,3,0) to (8,3,0).
        #expect(abs(bsp.domain.lowerBound - 3.6055512754639891) < 1e-12)
        #expect(abs(bsp.domain.upperBound - 10.816653826391967) < 1e-12)
        #expect(bsp.bspline.poleCount == 5)
        #expect(simd_distance(bsp.startPoint, SIMD3(2, 3, 0)) < 1e-9)
        #expect(simd_distance(bsp.endPoint, SIMD3(8, 3, 0)) < 1e-9)
    }

    @Test func increaseDegree() throws {
        let bsp = try make()
        #expect(bsp.bspline.increaseDegree(to: 4))
        #expect(bsp.bspline.degree == 4)
        #expect(bsp.bspline.poleCount == 11)
        #expect(bsp.bspline.multiplicities == [5, 2, 2, 2, 5])
        // Degree elevation keeps the geometry.
        #expect(simd_distance(bsp.startPoint, SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(bsp.endPoint, SIMD3(10, 0, 0)) < 1e-12)
    }

    @Test func resolution() throws {
        let bsp = try make()
        let res = bsp.bspline.resolution(tolerance3d: 0.001)
        #expect(abs(res - 0.00059678090076645284) < 1e-15)
    }

    @Test func setPeriodic() throws {
        let bsp = try make()
        // Setting non-periodic on an already non-periodic curve succeeds and changes nothing;
        // the old test checked only the returned flag.
        #expect(bsp.bspline.setPeriodic(false))
        #expect(!bsp.isPeriodic)
        #expect(bsp.bspline.poleCount == 7)
        #expect(Self.near(bsp.bspline.knots, Self.knots))
    }

    @Test func removeKnot() throws {
        let bsp = try make()
        // Insert a knot first (the third knot goes to multiplicity 2), then remove knot 2
        // entirely: the curve does not move by more than the 1.0 tolerance, so the kernel
        // accepts it. The old test discarded the result.
        let mid = (Self.knots.first! + Self.knots.last!) / 2.0
        #expect(bsp.bspline.insertKnot(u: mid))
        #expect(bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0))
        #expect(bsp.bspline.knotCount == 4)
        #expect(bsp.bspline.multiplicities == [4, 2, 1, 4])
        #expect(bsp.bspline.poleCount == 7)
    }
}

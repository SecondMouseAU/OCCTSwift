import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every test requires its curve and pins the poles `Geom2d_BezierCurve` holds after the edit, so
// neither a nil curve nor an edit that reports success and changes nothing passes. The kernel's own
// answers for the same calls are in `Scripts/repro/766-geom2d-bezier/transcript.txt` and
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
//
// Every insertion here goes from 2 poles to 3, far from the pole ceiling that
// `Issue2875BezierPoleCeilingTests` owns, so none of it depends on which side of that bound the
// pinned kernel and the bridge guard stand.
@Suite("v0.126.0: Curve2D Bezier completions")
struct Curve2DBezierCompletionsTests {
    private func close(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { simd_distance($0, $1) < 1e-12 }
    }

    @Test("InsertPoleAfter increases pole count")
    func insertPoleAfter() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        let origCount = try #require(c.poleCount)
        // The inserted pole is off the diagonal, so an x/y swap of it is visible.
        let ok = c.bezierInsertPoleAfter(1, point: SIMD2(0.25, 0.75))
        #expect(ok)
        #expect(c.poleCount == origCount + 1)
        let poles = c.bezierPoles
        #expect(close(poles, [SIMD2(0, 0), SIMD2(0.25, 0.75), SIMD2(1, 1)]), "poles \(poles)")
    }

    @Test("InsertPoleAfter takes a 1-based index and 0 means before the first pole")
    func insertPoleAfterIndexSemantics() throws {
        let front = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        #expect(front.bezierInsertPoleAfter(0, point: SIMD2(0.25, 0.75)))
        let frontPoles = front.bezierPoles
        #expect(
            close(frontPoles, [SIMD2(0.25, 0.75), SIMD2(0, 0), SIMD2(1, 1)]),
            "poles \(frontPoles)")

        let back = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        #expect(back.bezierInsertPoleAfter(2, point: SIMD2(0.25, 0.75)))
        let backPoles = back.bezierPoles
        #expect(
            close(backPoles, [SIMD2(0, 0), SIMD2(1, 1), SIMD2(0.25, 0.75)]),
            "poles \(backPoles)")
    }

    @Test("RemovePole decreases pole count")
    func removePole() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)]))
        let origCount = try #require(c.poleCount)
        let ok = c.bezierRemovePole(2)
        #expect(ok)
        #expect(c.poleCount == origCount - 1)
        let poles = c.bezierPoles
        #expect(close(poles, [SIMD2(0, 0), SIMD2(1, 1)]), "poles \(poles)")
    }

    @Test("Segment restricts domain")
    func segment() throws {
        // x(t) = t and y(t) = 2t(1 - t) on this curve, so [0.2, 0.8] runs (0.2, 0.32) to
        // (0.8, 0.32). The middle pole is the blossom value, 0.68 * (0.5, 1) + 0.16 * (1, 0).
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 1), SIMD2(1, 0)]))
        let ok = c.bezierSegment(u1: 0.2, u2: 0.8)
        #expect(ok)
        let poles = c.bezierPoles
        #expect(
            close(poles, [SIMD2(0.2, 0.32), SIMD2(0.5, 0.68), SIMD2(0.8, 0.32)]),
            "poles \(poles)")
    }

    @Test("IncreaseDegree succeeds")
    func increaseDegree() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        let origDeg = try #require(c.degree)
        let ok = c.bezierIncreaseDegree(origDeg + 1)
        #expect(ok)
        #expect(c.degree == origDeg + 1)
        let poles = c.bezierPoles
        #expect(close(poles, [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)]), "poles \(poles)")
    }

    @Test("IncreaseDegree keeps the curve and moves the poles by the elevation formula")
    func increaseDegreePreservesShape() throws {
        // A quadratic P0, P1, P2 elevates to the cubic P0, (P0 + 2 P1) / 3, (2 P1 + P2) / 3, P2.
        let p0 = SIMD2<Double>(0, 0)
        let p1 = SIMD2<Double>(5, 10)
        let p2 = SIMD2<Double>(10, 0)
        let c = try #require(Curve2D.bezier(poles: [p0, p1, p2]))
        let samples: [Double] = [0, 0.1, 0.25, 0.5, 0.8, 1]
        let before = samples.map { c.point(at: $0) }

        #expect(c.bezierIncreaseDegree(3))
        #expect(c.degree == 3)
        let q1: SIMD2<Double> = (p0 + 2 * p1) / 3
        let q2: SIMD2<Double> = (2 * p1 + p2) / 3
        let poles = c.bezierPoles
        #expect(close(poles, [p0, q1, q2, p2]), "poles \(poles)")

        // Elevating changes the representation and never the curve.
        for (u, was) in zip(samples, before) {
            #expect(simd_distance(c.point(at: u), was) < 1e-12, "u = \(u)")
        }
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10)]))
        let sp = c.bezierStartPoint
        let ep = c.bezierEndPoint
        #expect(abs(sp.x) < 1e-10)
        #expect(abs(sp.y) < 1e-10)
        #expect(abs(ep.x - 5) < 1e-10)
        #expect(abs(ep.y - 10) < 1e-10)

        // With an interior pole the ends are still the first and last poles, not a neighbour.
        let arch = try #require(Curve2D.bezier(poles: [SIMD2(1, 2), SIMD2(5, 10), SIMD2(9, 3)]))
        #expect(simd_distance(arch.bezierStartPoint, SIMD2(1, 2)) < 1e-10)
        #expect(simd_distance(arch.bezierEndPoint, SIMD2(9, 3)) < 1e-10)
    }

    @Test("GetPoles returns correct poles")
    func getPoles() throws {
        let poles = [SIMD2<Double>(0, 0), SIMD2(3, 4), SIMD2(6, 0)]
        let c = try #require(Curve2D.bezier(poles: poles))
        let got = c.bezierPoles
        #expect(close(got, poles), "poles \(got)")
    }

    @Test("Reverse swaps start and end")
    func reverse() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(10, 20)]))
        let ok = c.bezierReverse()
        #expect(ok)
        let sp = c.bezierStartPoint
        #expect(abs(sp.x - 10) < 1e-10)
        #expect(abs(sp.y - 20) < 1e-10)
        let ep = c.bezierEndPoint
        #expect(abs(ep.x) < 1e-10)
        #expect(abs(ep.y) < 1e-10)

        // The whole pole list runs backwards, the interior pole included.
        let three = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(10, 20), SIMD2(30, 5)]))
        #expect(three.bezierReverse())
        let poles = three.bezierPoles
        #expect(close(poles, [SIMD2(30, 5), SIMD2(10, 20), SIMD2(0, 0)]), "poles \(poles)")
    }
}

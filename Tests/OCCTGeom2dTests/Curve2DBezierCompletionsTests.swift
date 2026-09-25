import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here nested its assertions in `if let c` (and `if let origCount`), so a nil
// curve or a nil count passed with nothing checked, and Segment asserted only the Bool it
// returned. Each now requires the curve and pins the poles Geom2d_BezierCurve holds after the
// edit (Scripts/repro/766-geom2d-bezier/).
@Suite("v0.126.0 — Curve2D Bezier completions")
struct Curve2DBezierCompletionsTests {
    private func close(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { simd_distance($0, $1) < 1e-12 }
    }

    @Test("InsertPoleAfter increases pole count")
    func insertPoleAfter() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        let origCount = try #require(c.poleCount)
        let ok = c.bezierInsertPoleAfter(1, point: SIMD2(0.5, 0.5))
        #expect(ok)
        #expect(c.poleCount == origCount + 1)
        #expect(close(c.bezierPoles, [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)]))
    }

    @Test("RemovePole decreases pole count")
    func removePole() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)]))
        let origCount = try #require(c.poleCount)
        let ok = c.bezierRemovePole(2)
        #expect(ok)
        #expect(c.poleCount == origCount - 1)
        #expect(close(c.bezierPoles, [SIMD2(0, 0), SIMD2(1, 1)]))
    }

    @Test("Segment restricts domain")
    func segment() throws {
        // x(t) = t and y(t) = 2t(1 - t) on this curve, so [0.2, 0.8] runs (0.2, 0.32) to (0.8, 0.32).
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 1), SIMD2(1, 0)]))
        let ok = c.bezierSegment(u1: 0.2, u2: 0.8)
        #expect(ok)
        #expect(close(c.bezierPoles, [SIMD2(0.2, 0.32), SIMD2(0.5, 0.68), SIMD2(0.8, 0.32)]))
    }

    @Test("IncreaseDegree succeeds")
    func increaseDegree() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)]))
        let origDeg = try #require(c.degree)
        let ok = c.bezierIncreaseDegree(origDeg + 1)
        #expect(ok)
        #expect(c.degree == origDeg + 1)
        #expect(close(c.bezierPoles, [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)]))
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
    }

    @Test("GetPoles returns correct poles")
    func getPoles() throws {
        let poles = [SIMD2<Double>(0, 0), SIMD2(3, 4), SIMD2(6, 0)]
        let c = try #require(Curve2D.bezier(poles: poles))
        #expect(close(c.bezierPoles, poles))
    }

    @Test("Reverse swaps start and end")
    func reverse() throws {
        let c = try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(10, 20)]))
        let ok = c.bezierReverse()
        #expect(ok)
        let sp = c.bezierStartPoint
        #expect(abs(sp.x - 10) < 1e-10)
        #expect(abs(sp.y - 20) < 1e-10)
    }
}

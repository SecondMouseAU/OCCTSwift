import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0 — Curve2D Bezier completions")
struct Curve2DBezierCompletionsTests {
    @Test("InsertPoleAfter increases pole count")
    func insertPoleAfter() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierInsertPoleAfter(1, point: SIMD2(0.5, 0.5))
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount + 1)
                }
            }
        }
    }

    @Test("RemovePole decreases pole count")
    func removePole() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 0.5), SIMD2(1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierRemovePole(2)
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount - 1)
                }
            }
        }
    }

    @Test("Segment restricts domain")
    func segment() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(0.5, 1), SIMD2(1, 0)])
        if let c = c {
            let ok = c.bezierSegment(u1: 0.2, u2: 0.8)
            #expect(ok)
        }
    }

    @Test("IncreaseDegree succeeds")
    func increaseDegree() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 1)])
        if let c = c {
            if let origDeg = c.degree {
                let ok = c.bezierIncreaseDegree(origDeg + 1)
                #expect(ok)
                if let newDeg = c.degree {
                    #expect(newDeg == origDeg + 1)
                }
            }
        }
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10)])
        if let c = c {
            let sp = c.bezierStartPoint
            let ep = c.bezierEndPoint
            #expect(abs(sp.x) < 1e-10)
            #expect(abs(sp.y) < 1e-10)
            #expect(abs(ep.x - 5) < 1e-10)
            #expect(abs(ep.y - 10) < 1e-10)
        }
    }

    @Test("GetPoles returns correct poles")
    func getPoles() {
        let poles = [SIMD2<Double>(0, 0), SIMD2(3, 4), SIMD2(6, 0)]
        let c = Curve2D.bezier(poles: poles)
        if let c = c {
            let got = c.bezierPoles
            #expect(got.count == 3)
            if got.count == 3 {
                #expect(abs(got[0].x - 0) < 1e-10)
                #expect(abs(got[1].x - 3) < 1e-10)
                #expect(abs(got[2].x - 6) < 1e-10)
            }
        }
    }

    @Test("Reverse swaps start and end")
    func reverse() {
        let c = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(10, 20)])
        if let c = c {
            let ok = c.bezierReverse()
            #expect(ok)
            let sp = c.bezierStartPoint
            #expect(abs(sp.x - 10) < 1e-10)
            #expect(abs(sp.y - 20) < 1e-10)
        }
    }
}

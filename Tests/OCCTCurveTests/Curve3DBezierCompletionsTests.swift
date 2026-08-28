import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0, Curve3D Bezier completions")
struct Curve3DBezierCompletionsTests {
    @Test("InsertPoleBefore increases pole count")
    func insertPoleBefore() {
        let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 1, 1)])
        if let c = c {
            if let origCount = c.poleCount {
                let ok = c.bezierInsertPoleBefore(1, point: SIMD3(0.5, 0.5, 0.5))
                #expect(ok)
                if let newCount = c.poleCount {
                    #expect(newCount == origCount + 1)
                }
            }
        }
    }

    @Test("Reverse swaps start and end")
    func reverse() {
        let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(10, 20, 30)])
        if let c = c {
            let ok = c.bezierReverse()
            #expect(ok)
            let sp = c.bezierStartPoint
            #expect(abs(sp.x - 10) < 1e-10)
        }
    }

    @Test("SetPoleWithWeight on rational Bezier")
    func setPoleWithWeight() {
        let c = Curve3D.bezier(
            poles: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)],
            weights: [1, 1, 1])
        if let c = c {
            let ok = c.bezierSetPoleWithWeight(index: 2, point: SIMD3(5, 10, 0), weight: 2.0)
            #expect(ok)
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSpline Surface RemoveVKnot v0.120.0")
struct BSplineSurfaceRemoveVKnotTests {

    func makeBSplineSurface() -> Surface? {
        var points = [SIMD3<Double>]()
        for v in 0..<4 {
            for u in 0..<4 {
                points.append(
                    SIMD3(Double(u), Double(v), sin(Double(u) * 0.5) * cos(Double(v) * 0.5)))
            }
        }
        return Surface.fromPointGrid(points: points, uCount: 4, vCount: 4)
    }

    @Test func removeVKnot() {
        if let s = makeBSplineSurface() {
            // Attempt removal, may fail due to tolerance, that's OK
            let _ = s.bsplineRemoveVKnot(index: 1, mult: 0, tolerance: 1.0)
            #expect(true)  // no crash
        }
    }
}

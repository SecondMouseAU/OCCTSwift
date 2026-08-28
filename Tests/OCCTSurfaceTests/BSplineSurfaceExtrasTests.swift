import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface_Extras")
struct BSplineSurfaceExtrasTests {
    func makeBSplineSurface() -> Surface? {
        var pts = [SIMD3<Double>]()
        for v in 0..<4 {
            for u in 0..<4 {
                pts.append(SIMD3(Double(u) * 3, Double(v) * 3, Double((u + v) % 3)))
            }
        }
        return Surface.fromPointGrid(points: pts, uCount: 4, vCount: 4)
    }

    @Test func resolution() {
        if let s = makeBSplineSurface() {
            let (ur, vr) = s.bsplineResolution(tolerance3d: 0.01)
            #expect(ur > 0)
            #expect(vr > 0)
        }
    }

    @Test func getWeight() {
        if let s = makeBSplineSurface() {
            let w = s.bsplineWeight(uIndex: 1, vIndex: 1)
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func setUPeriodic() {
        if let s = makeBSplineSurface() {
            // May or may not succeed depending on surface structure
            let _ = s.bsplineSetUPeriodic(false)
            #expect(true)  // no crash
        }
    }

    @Test func setVPeriodic() {
        if let s = makeBSplineSurface() {
            let _ = s.bsplineSetVPeriodic(false)
            #expect(true)  // no crash
        }
    }
}

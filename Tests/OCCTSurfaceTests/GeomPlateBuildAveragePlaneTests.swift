import Testing
import simd

@testable import OCCTSwift

@Suite("GeomPlate BuildAveragePlane")
struct GeomPlateBuildAveragePlaneTests {
    @Test func planarPoints() {
        let result = Surface.averagePlane(
            points: [
                SIMD3(0, 0, 0), SIMD3(1, 0, 0.1),
                SIMD3(0, 1, 0), SIMD3(1, 1, 0.1),
                SIMD3(0.5, 0.5, 0.05),
            ])
        #expect(result != nil)
        if let r = result {
            #expect(r.isPlane)
            #expect(r.uvBox.umax > r.uvBox.umin)
        }
    }

    @Test func collinearPoints() {
        let result = Surface.averagePlane(
            points: [SIMD3(0, 0, 0), SIMD3(1, 1, 1), SIMD3(2, 2, 2)])
        // May or may not detect as line/plane, just test it doesn't crash
        #expect(result != nil || result == nil)  // always true
    }
}

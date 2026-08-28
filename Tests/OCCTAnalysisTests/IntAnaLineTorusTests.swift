import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna LineTorus Tests")
struct IntAnaLineTorusTests {

    @Test func lineThroughTorus() {
        let pts = IntAna.lineTorus(
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0),
            torusCenter: SIMD3(0, 0, 0), torusAxis: SIMD3(0, 0, 1),
            majorRadius: 20, minorRadius: 5)
        #expect(pts.count >= 2)
    }
}

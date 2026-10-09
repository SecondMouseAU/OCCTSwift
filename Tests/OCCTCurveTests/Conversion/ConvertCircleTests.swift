import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Convert Circle Tests")
struct ConvertCircleTests {

    @Test func circleArcToBSpline() {
        let curve = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 10, u1: 0, u2: .pi)
        #expect(curve != nil)
    }
}

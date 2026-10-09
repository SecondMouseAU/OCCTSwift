import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.95.0 Tests

@Suite("Convert Conic Curves Tests")
struct ConvertConicCurvesTests {

    @Test func ellipseArc() {
        let curve = Curve2D.fromEllipseArc(
            centerX: 0, centerY: 0, majorRadius: 20, minorRadius: 10, u1: 0, u2: .pi)
        #expect(curve != nil)
    }

    @Test func hyperbolaArc() {
        let curve = Curve2D.fromHyperbolaArc(
            centerX: 0, centerY: 0, majorRadius: 10, minorRadius: 5, u1: -1, u2: 1)
        #expect(curve != nil)
    }

    @Test func parabolaArc() {
        let curve = Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 5, u1: -2, u2: 2)
        #expect(curve != nil)
    }
}

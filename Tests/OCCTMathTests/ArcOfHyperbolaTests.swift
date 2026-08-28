import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.50.0 Tests

@Suite("GC_MakeArcOfHyperbola")
struct ArcOfHyperbolaTests {
    @Test("Arc of hyperbola between parameters")
    func arcOfHyperbola() throws {
        let arc = try #require(
            Curve3D.arcOfHyperbola(
                majorRadius: 5.0, minorRadius: 3.0,
                alpha1: -1.0, alpha2: 1.0))
        let dom = arc.domain
        let start = arc.point(at: dom.lowerBound)
        let end = arc.point(at: dom.upperBound)
        // Hyperbola: x = a*cosh(t), y = b*sinh(t)
        let expectedX = 5.0 * cosh(1.0)
        #expect(abs(start.x - expectedX) < 0.1)
        #expect(abs(end.x - expectedX) < 0.1)
        #expect(start.y < 0)
        #expect(end.y > 0)
    }
}


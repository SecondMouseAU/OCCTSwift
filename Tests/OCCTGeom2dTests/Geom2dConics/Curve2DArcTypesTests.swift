import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Arc Types Tests

@Suite("Curve2D Arc Types Tests")
struct Curve2DArcTypesTests {

    @Test("Arc of hyperbola creation")
    func arcOfHyperbola() {
        let arc = Curve2D.arcOfHyperbola(
            center: .zero, majorRadius: 5, minorRadius: 3,
            rotation: 0, startAngle: -0.5, endAngle: 0.5
        )
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let pts = arc.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }

    @Test("Arc of parabola creation")
    func arcOfParabola() {
        let arc = Curve2D.arcOfParabola(
            focus: .zero, direction: SIMD2(1, 0),
            focalLength: 2, startParam: -5, endParam: 5
        )
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let pts = arc.drawAdaptive()
            #expect(pts.count >= 2)
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Arc Types Tests

@Suite("Curve2D Arc Types Tests")
struct Curve2DArcTypesTests {

    @Test("Arc of hyperbola creation")
    func arcOfHyperbola() throws {
        let arc = Curve2D.arcOfHyperbola(
            center: .zero, majorRadius: 5, minorRadius: 3,
            rotation: 0, startAngle: -0.5, endAngle: 0.5
        )
        // #1979: non-nil, open and two sample points passed an arc on the wrong hyperbola. The arc
        // runs (5 cosh 0.5, -3 sinh 0.5) to (5 cosh 0.5, 3 sinh 0.5)
        // (Scripts/repro/766-geom2d-approx-arclength-arctypes/).
        let a = try #require(arc)
        #expect(!a.isClosed)
        let pts = a.drawAdaptive()
        #expect(pts.count >= 2)
        #expect(simd_distance(a.startPoint, SIMD2(5.63812982603, -1.56328591648)) < 1e-9)
        #expect(simd_distance(a.endPoint, SIMD2(5.63812982603, 1.56328591648)) < 1e-9)
    }

    @Test("Arc of parabola creation")
    func arcOfParabola() throws {
        let arc = Curve2D.arcOfParabola(
            focus: .zero, direction: SIMD2(1, 0),
            focalLength: 2, startParam: -5, endParam: 5
        )
        // #1979: the same gap. With the focus at the origin and focal length 2 the apex is
        // (-2, 0), so parameters -5 and 5 land at (-2 + 25/8, -5) and (-2 + 25/8, 5).
        let a = try #require(arc)
        #expect(!a.isClosed)
        let pts = a.drawAdaptive()
        #expect(pts.count >= 2)
        #expect(simd_distance(a.startPoint, SIMD2(1.125, -5)) < 1e-9)
        #expect(simd_distance(a.endPoint, SIMD2(1.125, 5)) < 1e-9)
    }
}

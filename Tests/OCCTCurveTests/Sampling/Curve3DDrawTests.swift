import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Draw Tests")
struct Curve3DDrawTests {

    @Test("Adaptive draw on circle produces points")
    func adaptiveDrawCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawAdaptive()
        #expect(points.count >= 10)
        // Points should be on the circle (radius ≈ 5)
        for p in points {
            let r = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(r - 5) < 0.1)
        }
    }

    @Test("Uniform draw produces exact count")
    func uniformDraw() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawUniform(pointCount: 32)
        #expect(points.count == 32)
    }

    @Test("Deflection draw produces points")
    func deflectionDraw() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let points = circle.drawDeflection(deflection: 0.1)
        #expect(points.count >= 4)
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let points = seg.drawAdaptive()
        #expect(points.count >= 2)
    }
}

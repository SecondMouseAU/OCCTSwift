import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema extras v0.112")
struct ExtremaExtrasV112Tests {

    @Test func locateOnCurve() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let result = circle.locateNearestPoint(SIMD3(6, 0, 0), initParam: 0)
            #expect(result != nil)
            if let r = result {
                #expect(r.distance < 1.5)
            }
        }
    }

    @Test func projectPointOnCurve() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let results = line.projectPointAll(SIMD3(5, 3, 0))
            #expect(results.count >= 1)
            if results.count > 0 {
                #expect(abs(results[0].parameter - 5.0) < 0.1)
                #expect(abs(results[0].distance - 3.0) < 0.1)
            }
        }
    }

    @Test func locateOnSurface() {
        if let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = surf.locateNearestPoint(SIMD3(5, 3, 10), initU: 0, initV: 0)
            if let r = result {
                #expect(abs(r.distance - 10.0) < 0.1)
            }
        }
    }

    @Test func projectPointOnSurface() {
        if let surf = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            let results = surf.projectPointAll(SIMD3(10, 0, 0))
            #expect(results.count >= 1)
            if results.count > 0 {
                #expect(abs(results[0].distance - 5.0) < 0.1)
            }
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.91.0 Tests

@Suite("ElCLib Tests")
struct ElCLibTests {

    @Test func valueOnLine() {
        let p = ElCLib.valueOnLine(u: 5.0, origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func valueOnCircle() {
        let p = ElCLib.valueOnCircle(
            u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x - 10.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func valueOnCircleAtPiOver2() {
        let p = ElCLib.valueOnCircle(
            u: .pi / 2, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 10.0) < 1e-10)
    }

    @Test func valueOnEllipse() {
        let p = ElCLib.valueOnEllipse(
            u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 20.0, minorRadius: 10.0)
        #expect(abs(p.x - 20.0) < 1e-10)
    }

    @Test func d1OnCircle() {
        let result = ElCLib.d1OnCircle(
            u: 0.0, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(result.point.x - 10.0) < 1e-10)
        #expect(abs(result.tangent.y - 10.0) < 1e-10)
    }

    @Test func parameterOnLine() {
        let u = ElCLib.parameterOnLine(
            origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0), point: SIMD3(7, 0, 0))
        #expect(abs(u - 7.0) < 1e-10)
    }

    @Test func inPeriod() {
        let u = ElCLib.inPeriod(u: 7.0, uFirst: 0.0, uLast: 2 * .pi)
        #expect(u >= 0.0 && u < 2 * .pi)
    }
}


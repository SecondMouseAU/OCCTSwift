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

    // #1249: valueOnCircle() and valueOnCircleAtPiOver2() were a clean @Test(arguments:)
    // collapse candidate, identical center/normal/radius, differing only in u and the
    // correspondingly swapped expected x/y.
    @Test(
        "valueOnCircle",
        arguments: [
            (0.0, 10.0, 0.0),
            (Double.pi / 2, 0.0, 10.0),
        ] as [(Double, Double, Double)])
    func valueOnCircle(u: Double, expectedX: Double, expectedY: Double) {
        let p = ElCLib.valueOnCircle(
            u: u, center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x - expectedX) < 1e-10)
        #expect(abs(p.y - expectedY) < 1e-10)
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


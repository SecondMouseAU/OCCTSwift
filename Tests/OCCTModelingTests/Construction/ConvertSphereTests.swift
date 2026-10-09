import Testing
import simd

@testable import OCCTSwift

@Suite("Convert Sphere Tests")
struct ConvertSphereTests {

    @Test func sphereToBSpline() {
        let surface = Surface.fromSphere(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10)
        #expect(surface != nil)
    }
}

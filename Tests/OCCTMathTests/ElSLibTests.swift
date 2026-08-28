import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ElSLib Tests")
struct ElSLibTests {

    @Test func valueOnPlane() {
        let p = ElSLib.valueOnPlane(u: 3.0, v: 4.0, origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(abs(p.x - 3.0) < 1e-10)
        #expect(abs(p.y - 4.0) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func valueOnSphere() {
        let p = ElSLib.valueOnSphere(
            u: 0, v: 0, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10.0)
        #expect(abs(p.x - 10.0) < 1e-10)
    }

    @Test func valueOnCylinder() {
        let p = ElSLib.valueOnCylinder(
            u: 0, v: 10, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        #expect(abs(p.x - 5.0) < 1e-10)
        #expect(abs(p.z - 10.0) < 1e-10)
    }

    @Test func valueOnTorus() {
        let p = ElSLib.valueOnTorus(
            u: 0, v: 0, origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 20.0, minorRadius: 5.0)
        #expect(abs(p.x - 25.0) < 1e-10)
    }

    @Test func parametersOnSphere() {
        let uv = ElSLib.parametersOnSphere(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10.0,
            point: SIMD3(10, 0, 0))
        #expect(abs(uv.u) < 1e-10)
        #expect(abs(uv.v) < 1e-10)
    }
}


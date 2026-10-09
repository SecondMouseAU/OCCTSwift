import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_Plane Properties")
struct GeomPlane3DTests {
    @Test func planeCoefficients() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let c = p.planeProperties.coefficients
            #expect(abs(c.c - 1.0) < 1e-6)
            #expect(abs(c.d) < 1e-6)
        }
    }

    @Test func planeUIso() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let iso = p.planeProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func planeVIso() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let iso = p.planeProperties.vIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func planePln() {
        if let p = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let pln = p.planeProperties.pln
            #expect(abs(pln.normal.z - 1) < 1e-6)
        }
    }
}

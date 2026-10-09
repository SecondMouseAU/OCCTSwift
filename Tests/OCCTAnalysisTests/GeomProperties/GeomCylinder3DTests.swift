import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_CylindricalSurface Properties")
struct GeomCylinder3DTests {
    @Test func cylinderRadius() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(abs(c.cylinderProperties.radius - 5) < 1e-6)
        }
    }

    @Test func cylinderSetRadius() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(c.cylinderProperties.setRadius(10))
            #expect(abs(c.cylinderProperties.radius - 10) < 1e-6)
        }
    }

    @Test func cylinderAxis() {
        if let c = Surface.cylinder(origin: SIMD3(1, 2, 3), axis: SIMD3(0, 0, 1), radius: 5) {
            let ax = c.cylinderProperties.axis
            #expect(abs(ax.position.x - 1) < 1e-6)
            #expect(abs(ax.position.y - 2) < 1e-6)
            #expect(abs(ax.position.z - 3) < 1e-6)
            #expect(abs(ax.direction.x) < 1e-6)
            #expect(abs(ax.direction.y) < 1e-6)
            #expect(abs(ax.direction.z - 1) < 1e-6)
        }
    }

    @Test func cylinderUIso() {
        if let c = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            if let iso = c.cylinderProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_SphericalSurface Properties")
struct GeomSphere3DTests {
    @Test func sphereRadius() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            #expect(abs(s.sphereProperties.radius - 5) < 1e-6)
        }
    }

    @Test func sphereSetRadius() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            #expect(s.sphereProperties.setRadius(10))
            #expect(abs(s.sphereProperties.radius - 10) < 1e-6)
        }
    }

    @Test func sphereArea() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let area = s.sphereProperties.area
            #expect(abs(area - 4 * Double.pi * 25) < 0.1)
        }
    }

    @Test func sphereVolume() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let vol = s.sphereProperties.volume
            #expect(abs(vol - 4.0 / 3.0 * Double.pi * 125) < 1.0)
        }
    }

    @Test func sphereCenter() {
        if let s = Surface.sphere(center: SIMD3(1, 2, 3), radius: 5) {
            let c = s.sphereProperties.center
            #expect(abs(c.x - 1) < 1e-6)
            #expect(abs(c.y - 2) < 1e-6)
            #expect(abs(c.z - 3) < 1e-6)
        }
    }

    @Test func sphereUIso() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            if let iso = s.sphereProperties.uIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func sphereVIso() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            if let iso = s.sphereProperties.vIso(0) {
                let _ = iso.domain
            }
        }
    }

    @Test func sphereSphere() {
        if let s = Surface.sphere(center: .zero, radius: 5) {
            let sph = s.sphereProperties.sphere
            #expect(abs(sph.radius - 5) < 1e-6)
        }
    }
}

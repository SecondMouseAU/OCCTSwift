import Testing
import simd

@testable import OCCTSwift

// MARK: - Oriented Cylinder (fixes #60)

@Suite("Oriented Cylinder")
struct OrientedCylinderTests {
    @Test func cylinderAlongZ() {
        let cyl = Shape.cylinder(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(abs(vol - Double.pi * 25 * 10) < 1.0) }
        }
    }

    @Test func cylinderAlongX() {
        let cyl = Shape.cylinder(
            at: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0), radius: 3, height: 20)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(vol > 0) }
        }
    }

    @Test func cylinderAlongDiagonal() {
        let cyl = Shape.cylinder(
            at: SIMD3(5, 5, 5), direction: SIMD3(1, 1, 1), radius: 2, height: 15)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(abs(vol - Double.pi * 4 * 15) < 1.0) }
        }
    }

    @Test func cylinderOffOrigin() {
        let cyl = Shape.cylinder(
            at: SIMD3(100, 200, 300), direction: SIMD3(0, 1, 0), radius: 1, height: 5)
        #expect(cyl != nil)
    }

    @Test func cylinderIsValid() {
        let cyl = Shape.cylinder(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, height: 10)
        if let cyl { #expect(cyl.isValid) }
    }
}

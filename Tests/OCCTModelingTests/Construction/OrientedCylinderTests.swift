import Testing

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

    @Test func cylinderAlongX() throws {
        let cyl = try #require(
            Shape.cylinder(
                at: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0), radius: 3, height: 20))
        #expect(abs((cyl.volume ?? -1) - Double.pi * 9 * 20) < 1e-6)
        // The axis is x: it runs 0 to 20 along x and the radius 3 is in y and z.
        let bounds = try #require(cyl.boundingBox)
        #expect(abs(bounds.min.x) < 1e-6 && abs(bounds.max.x - 20) < 1e-6)
        #expect(abs(bounds.min.y + 3) < 1e-6 && abs(bounds.max.y - 3) < 1e-6)
        #expect(abs(bounds.min.z + 3) < 1e-6 && abs(bounds.max.z - 3) < 1e-6)
    }

    @Test func cylinderAlongDiagonal() {
        let cyl = Shape.cylinder(
            at: SIMD3(5, 5, 5), direction: SIMD3(1, 1, 1), radius: 2, height: 15)
        #expect(cyl != nil)
        if let cyl {
            if let vol = cyl.volume { #expect(abs(vol - Double.pi * 4 * 15) < 1.0) }
        }
    }

    @Test func cylinderOffOrigin() throws {
        let cyl = try #require(
            Shape.cylinder(
                at: SIMD3(100, 200, 300), direction: SIMD3(0, 1, 0), radius: 1, height: 5))
        #expect(abs((cyl.volume ?? -1) - Double.pi * 5) < 1e-6)
        // Base centre at (100, 200, 300), axis +y, so y runs 200 to 205 and x, z are 100, 300 +- 1.
        let bounds = try #require(cyl.boundingBox)
        #expect(abs(bounds.min.x - 99) < 1e-6 && abs(bounds.max.x - 101) < 1e-6)
        #expect(abs(bounds.min.y - 200) < 1e-6 && abs(bounds.max.y - 205) < 1e-6)
        #expect(abs(bounds.min.z - 299) < 1e-6 && abs(bounds.max.z - 301) < 1e-6)
    }

    @Test func cylinderIsValid() throws {
        let cyl = try #require(
            Shape.cylinder(
                at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 5, height: 10))
        #expect(cyl.isValid)
        #expect(cyl.shapeType == .solid)
        // Lateral face, two caps.
        #expect(cyl.faces().count == 3)
        #expect(abs((cyl.volume ?? -1) - Double.pi * 25 * 10) < 1e-6)
    }
}

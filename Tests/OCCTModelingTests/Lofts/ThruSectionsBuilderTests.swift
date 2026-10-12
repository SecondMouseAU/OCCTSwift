import Foundation
import Testing

@testable import OCCTSwift

// #3332: the three tests ran under `if let` on every fixture and asserted `ok` (and `isValid`),
// so a builder that answered true and produced any valid solid passed. Pinned (kernel.6):
//   basic: circles r = 5 at z = 0 and r = 3 at z = 10 loft to the cone frustum,
//     V = pi h / 3 (R^2 + R r + r^2) = pi 10 / 3 (25 + 15 + 9) = 513.127, 3 faces
//   ruled: a 10 mm square to a r = 5 circle 15 up, ruled; a measurement (1342.857, 7 faces),
//     there is no short closed form for a ruled square-to-circle volume
//   settings: three circles r = 5, 7, 3 at z = 0, 5, 10 through a smoothed, degree-8, C2 surface;
//     a measurement (1172.330), between the frustum's 513 at the same height and the
//     bulge the middle r = 7 section makes
@Suite("v0.115.0 - ThruSections Builder")
struct ThruSectionsBuilderTests {

    private func circle(z: Double, radius: Double) throws -> Shape {
        let wire = try #require(
            Wire.circle(origin: SIMD3(0, 0, z), normal: SIMD3(0, 0, 1), radius: radius))
        return try #require(Shape.fromWire(wire))
    }

    @Test func basicThruSections() throws {
        let s1 = try circle(z: 0, radius: 5)
        let s2 = try circle(z: 10, radius: 3)
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: false)
        ts.addWire(s1)
        ts.addWire(s2)
        #expect(ts.build())
        let shape = try #require(ts.shape)
        #expect(shape.isValid)
        #expect(shape.shapeType == .solid)
        #expect(shape.faceCount == 3)
        let volume = try #require(shape.volume)
        #expect(abs(volume - Double.pi * 10 / 3 * (25 + 15 + 9)) < 1e-3)
        let bounds = try #require(shape.bounds)
        #expect(abs(bounds.min.z) < 1e-3 && abs(bounds.max.z - 10) < 1e-3)

        // Not a solid: the lateral surface alone, frustum lateral area pi (5 + 3) sqrt(100 + 4).
        let open = ThruSectionsBuilder(isSolid: false, isRuled: false)
        open.addWire(s1)
        open.addWire(s2)
        #expect(open.build())
        let shell = try #require(open.shape)
        #expect(shell.shapeType == .shell)
        let area = try #require(shell.surfaceArea)
        #expect(abs(area - Double.pi * 8 * 104.0.squareRoot()) < 1e-3)
    }

    @Test func ruledThruSections() throws {
        let square = try #require(Wire.rectangle(width: 10, height: 10))
        let s1 = try #require(Shape.fromWire(square))
        let s2 = try circle(z: 15, radius: 5)
        let ts = ThruSectionsBuilder(isSolid: true, isRuled: true)
        ts.addWire(s1)
        ts.addWire(s2)
        #expect(ts.build())
        let shape = try #require(ts.shape)
        #expect(shape.isValid)
        #expect(shape.shapeType == .solid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - 1342.857) < 1e-2)
        let bounds = try #require(shape.bounds)
        #expect(abs(bounds.min.z) < 1e-3 && abs(bounds.max.z - 15) < 1e-3)
        // The ruled loft's volume lies between the two prisms around it: the circle's cylinder
        // (pi 25 * 15 = 1178) and the square's (100 * 15 = 1500).
        #expect(volume > Double.pi * 25 * 15)
        #expect(volume < 100 * 15)
    }

    @Test func thruSectionsWithSettings() throws {
        let s1 = try circle(z: 0, radius: 5)
        let s2 = try circle(z: 5, radius: 7)
        let s3 = try circle(z: 10, radius: 3)
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.setSmoothing(true)
        ts.setMaxDegree(8)
        ts.setContinuity(2)
        ts.addWire(s1)
        ts.addWire(s2)
        ts.addWire(s3)
        #expect(ts.build())
        let shape = try #require(ts.shape)
        #expect(shape.isValid)
        #expect(shape.shapeType == .solid)
        #expect(shape.faceCount == 3)
        let volume = try #require(shape.volume)
        #expect(abs(volume - 1172.33) < 0.05)
        // More than the straight 5 -> 3 frustum over the same 10 mm (513), because the middle
        // section is wider than both ends.
        #expect(volume > Double.pi * 10 / 3 * (25 + 15 + 9))
    }
}

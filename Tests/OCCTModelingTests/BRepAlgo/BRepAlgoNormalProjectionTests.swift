import Foundation
import Testing

@testable import OCCTSwift

// #3332: all three tests ended in `if let`/`let _ =` and asserted at most that a constructor was
// non-nil. BRepAlgo_NormalProjection projects a wire onto a target ALONG THE TARGET'S NORMAL, so
// every answer here has a closed form. Measured on the pinned kernel: a straight edge projects
// to edges that each carry its full length (the kernel returns two coincident edges per straight
// input, so the edge COUNT is not pinned; their lengths, positions and the total extent are),
// a circle onto a coaxial cylinder is a circle of the cylinder's radius.
@Suite("BRepAlgo_NormalProjection")
struct BRepAlgoNormalProjectionTests {
    private func lengths(of shape: Shape?) -> [Double] {
        shape?.edges().map { $0.length } ?? []
    }

    @Test func createProjection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let proj = try #require(NormalProjection(target: box))
        // Nothing added: building succeeds and the result is an empty compound.
        #expect(proj.build())
        let result = try #require(proj.result)
        #expect(result.shapeType == .compound)
        #expect(result.edges().isEmpty)
        #expect(result.bounds == nil)
    }

    @Test func projectWire() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 20))
        let proj = try #require(NormalProjection(target: cylinder))

        // A vertical line 10 mm out from the axis at y = 10 projects radially onto (0, 5, z).
        let line = try #require(Wire.polygon3D([SIMD3(0, 10, 5), SIMD3(0, 10, 15)]))
        let lineShape = try #require(Shape.fromWire(line))
        proj.add(lineShape)
        #expect(proj.build())
        let result = try #require(proj.result)
        let edgeLengths = lengths(of: result)
        #expect(!edgeLengths.isEmpty)
        for length in edgeLengths { #expect(abs(length - 10) < 1e-4) }
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.x) < 1e-4 && abs(bounds.max.x) < 1e-4)
        #expect(abs(bounds.min.y - 5) < 1e-4 && abs(bounds.max.y - 5) < 1e-4)
        #expect(abs(bounds.min.z - 5) < 1e-4)
        #expect(abs(bounds.max.z - 15) < 1e-4)

        // A coaxial circle of radius 10 at z = 10 projects onto the radius-5 circle at z = 10.
        let ring = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 10))
        let projRing = try #require(NormalProjection(target: cylinder))
        let ringShape = try #require(Shape.fromWire(ring))
        projRing.add(ringShape)
        #expect(projRing.build())
        let ringLengths = lengths(of: projRing.result)
        #expect(ringLengths.count == 1)
        if let length = ringLengths.first { #expect(abs(length - 2 * Double.pi * 5) < 1e-3) }
    }

    @Test func projectionResult() throws {
        // Onto a plane the projection drops the wire straight down: a 10 mm segment at height 7 over
        // the plane z = 0 lands at z = 0 with its length unchanged.
        let outline = try #require(Wire.rectangle(width: 40, height: 40))
        let plane = try #require(Shape.face(from: outline))
        let proj = try #require(NormalProjection(target: plane))
        let segment = try #require(Wire.polygon3D([SIMD3(-5, 3, 7), SIMD3(5, 3, 7)]))
        let segmentShape = try #require(Shape.fromWire(segment))
        proj.add(segmentShape)
        #expect(proj.build())
        let result = try #require(proj.result)
        let edgeLengths = lengths(of: result)
        #expect(!edgeLengths.isEmpty)
        for length in edgeLengths { #expect(abs(length - 10) < 1e-4) }
        let bounds = try #require(result.bounds)
        #expect(abs(bounds.min.x + 5) < 1e-4 && abs(bounds.max.x - 5) < 1e-4)
        #expect(abs(bounds.min.y - 3) < 1e-4 && abs(bounds.max.y - 3) < 1e-4)
        #expect(abs(bounds.min.z) < 1e-4 && abs(bounds.max.z) < 1e-4)

        // A second wire adds its own projection to the same result.
        let second = try #require(Wire.polygon3D([SIMD3(0, -5, 2), SIMD3(0, 5, 2)]))
        let secondShape = try #require(Shape.fromWire(second))
        proj.add(secondShape)
        #expect(proj.build())
        let both = lengths(of: proj.result)
        #expect(both.count > edgeLengths.count)
        for length in both { #expect(abs(length - 10) < 1e-4) }
    }
}

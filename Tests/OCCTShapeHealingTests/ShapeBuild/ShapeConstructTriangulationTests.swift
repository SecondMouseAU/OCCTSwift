import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
// Before #766 both asserted only non-nil. Kernel: one planar face in each case, area 100 for
// the 10x10 square and 50 for the triangle.
@Suite("ShapeConstruct Triangulation Tests")
struct ShapeConstructTriangulationTests {
    @Test("triangulation from points")
    func fromPoints() throws {
        let points: [(Double, Double, Double)] = [
            (0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0),
        ]
        let shape = try #require(Shape.triangulationFromPoints(points))
        #expect(shape.faces().count == 1)
        #expect(abs((shape.surfaceArea ?? 0) - 100) < 1e-9)
    }

    @Test("triangulation from wire")
    func fromWire() throws {
        let w = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(5, 10, 0)], closed: true))
        let shape = try #require(Shape.triangulationFromWire(w))
        #expect(shape.faces().count == 1)
        #expect(abs((shape.surfaceArea ?? 0) - 50) < 1e-9)
    }
}

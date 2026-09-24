import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Geometry Conversion

// #766: expected values are ShapeCustom's own answers on the same cylinder, from
// Scripts/repro/766-healing-freebounds-geomconv/probe.mm. Before #766 these asserted non-nil,
// valid and an unchanged face count, all of which the input cylinder itself satisfies, so a
// bridge that returned its input untouched passed every one.

/// Faces per surface kind.
private func kinds(_ shape: Shape) -> [Surface.SurfaceType: Int] {
    var counts: [Surface.SurfaceType: Int] = [:]
    for face in shape.faces() { counts[face.surfaceType, default: 0] += 1 }
    return counts
}

@Suite("ShapeCustom Geometry Conversion")
struct GeometryConversionTests {
    @Test("Convert cylinder to BSpline surfaces")
    func cylinderToBSpline() throws {
        // With the default plane: false, ShapeCustom::ConvertToBSpline converts extrusion,
        // revolution and offset surfaces only. A cylindrical surface is none of those, so the
        // kernel returns the cylinder's surfaces unchanged: plane=2 cylinder=1.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let result = try #require(cyl.withSurfacesAsBSpline())
        #expect(result.isValid)
        #expect(kinds(result) == [.plane: 2, .cylinder: 1])
    }

    @Test("Convert to revolution surfaces")
    func toRevolution() throws {
        // Kernel: the lateral face becomes a surface of revolution, the caps stay planes.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let result = try #require(cyl.withSurfacesAsRevolution())
        #expect(result.isValid)
        #expect(kinds(result) == [.plane: 2, .surfaceOfRevolution: 1])
        #expect(abs((result.volume ?? 0) - 785.398163397) < 1e-6)
    }

    @Test("BSpline conversion preserves volume")
    func bsplinePreservesVolume() throws {
        // plane: true is the case that changes geometry: both caps become BSplines
        // (kernel: cylinder=1 bspline=2) at the same volume, 785.398163397.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let result = try #require(cyl.withSurfacesAsBSpline(plane: true))
        #expect(kinds(result) == [.cylinder: 1, .bsplineSurface: 2])
        let volAfter = try #require(result.volume)
        #expect(abs(volAfter - 785.398163397) < 1e-6)
    }
}

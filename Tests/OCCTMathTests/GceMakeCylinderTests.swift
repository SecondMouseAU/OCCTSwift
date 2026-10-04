import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeCylinder Tests")
struct GceMakeCylinderTests {
    /// The cylinder the three points define, rather than the handle it came back in.
    ///
    /// This used to end at `#expect(cyl.handle != nil)`, always true for a non-optional
    /// `OCCTSurfaceRef`, so the `try #require` was the whole test (#3018).
    @Test func cylinderFrom3Points() throws {
        let cyl = try #require(
            Surface.cylinderFrom3Points(
                p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10), p3: SIMD3(3, 0, 0)))
        #expect(cyl.isCylinder)
        // The axis runs p1 to p2; the radius is p3's distance from that axis, which is 3.
        #expect(abs(cyl.cylinderProperties.radius - 3.0) < 1e-12)
        let axis = cyl.cylinderProperties.axis
        #expect(simd_length(axis.position - SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_length(axis.direction - SIMD3(0, 0, 1)) < 1e-12)
        #expect(simd_length(cyl.point(atU: 0, v: 0) - SIMD3(3, 0, 0)) < 1e-9)
    }

    // #420: cylinderFrom3Points and cylindricalSurface(point1:point2:point3:) now
    // share one implementation (GC_MakeCylindricalSurface), assert they still
    // produce geometrically equivalent cylinders for the same inputs.
    @Test func parityWithCylindricalSurface() throws {
        let p1 = SIMD3(0.0, 0.0, 0.0)
        let p2 = SIMD3(0.0, 0.0, 10.0)
        let p3 = SIMD3(3.0, 0.0, 0.0)

        let viaGce = try #require(Surface.cylinderFrom3Points(p1: p1, p2: p2, p3: p3))
        let viaGC = try #require(Surface.cylindricalSurface(point1: p1, point2: p2, point3: p3))

        #expect(abs(viaGce.cylinderProperties.radius - viaGC.cylinderProperties.radius) < 1e-9)
        #expect(
            simd_length(
                viaGce.cylinderProperties.axis.position - viaGC.cylinderProperties.axis.position)
                < 1e-9)
        #expect(
            simd_length(
                viaGce.cylinderProperties.axis.direction - viaGC.cylinderProperties.axis.direction)
                < 1e-9)
    }
}

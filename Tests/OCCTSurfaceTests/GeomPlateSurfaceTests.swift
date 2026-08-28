import Testing
import simd

@testable import OCCTSwift

@Suite("GeomPlate Surface")
struct GeomPlateSurfaceTests {
    @Test("Plate surface through points")
    func plateSurfaceThroughPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 1),
            SIMD3(0, 10, -1),
            SIMD3(10, 10, 0.5),
        ]
        let face = Shape.plateSurface(points: points)
        if let face = face {
            #expect(face.isValid)
        }
    }

    @Test("Plate surface with more points")
    func plateSurfaceMorePoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 2),
            SIMD3(20, 0, 0),
            SIMD3(0, 10, -1),
            SIMD3(10, 10, 1),
            SIMD3(20, 10, -0.5),
        ]
        let face = Shape.plateSurface(points: points, tolerance: 1e-2)
        if let face = face {
            #expect(face.isValid)
        }
    }
}

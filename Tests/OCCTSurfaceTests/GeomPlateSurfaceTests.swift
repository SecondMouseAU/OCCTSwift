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
        // #766: `if let` let a nil face pass and `isValid` passed a face that ignores a point.
        // The same GeomPlate chain gives area 230.283551308 with every point on the face, see
        // Scripts/repro/766-offset-plate-helix/.
        #expect(face != nil)
        if let face = face {
            #expect(face.isValid)
            #expect(abs((face.surfaceArea ?? 0) - 230.283551308) < 1e-6)
            for p in points {
                if let v = Shape.vertex(at: p) {
                    #expect((face.minDistance(to: v) ?? 1) < 1e-6)
                }
            }
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
        // #766: as above; kernel area 281.864731907, see Scripts/repro/766-offset-plate-helix/.
        #expect(face != nil)
        if let face = face {
            #expect(face.isValid)
            #expect(abs((face.surfaceArea ?? 0) - 281.864731907) < 1e-6)
            for p in points {
                if let v = Shape.vertex(at: p) {
                    #expect((face.minDistance(to: v) ?? 1) < 1e-6)
                }
            }
        }
    }
}

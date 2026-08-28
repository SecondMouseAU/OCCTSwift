import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Contap Contour Analysis")
struct ContapContourTests {
    @Test("Sphere contour with direction")
    func sphereContourDir() {
        let result = Shape.contourSphereDir(
            center: SIMD3(0, 0, 0), radius: 10,
            direction: SIMD3(0, 0, 1))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .circle)
            // Contour circle radius should be ~10 for Z-aligned view
            #expect(abs(result.data[3] - 10.0) < 0.1)
        }
    }

    @Test("Cylinder contour with direction")
    func cylinderContourDir() {
        let result = Shape.contourCylinderDir(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            radius: 5, direction: SIMD3(1, 0, 0))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .line)
        }
    }

    @Test("Sphere contour with eye point")
    func sphereContourEye() {
        let result = Shape.contourSphereEye(
            center: SIMD3(0, 0, 0), radius: 10,
            eye: SIMD3(100, 0, 0))
        if let result = result {
            #expect(result.count > 0)
        }
    }
}

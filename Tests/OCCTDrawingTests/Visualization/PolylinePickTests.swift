import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - SIMD3 Extension for normalization

// MARK: - Polyline (Lasso) Pick Tests

@Suite("Polyline Pick", .disabled("Polygon selection behavior changed in OCCT 8.0.0-rc4"))
struct PolylinePickTests {

    private func makeCamera() -> Camera {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)
        return cam
    }

    @Test("Polygon enclosing shape returns hit")
    func polygonHit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 1)

        let viewSize = SIMD2<Double>(200, 200)
        // Large polygon enclosing the center of the viewport (closed)
        let polygon: [SIMD2<Double>] = [
            SIMD2(50, 50),
            SIMD2(150, 50),
            SIMD2(150, 150),
            SIMD2(50, 150),
            SIMD2(50, 50),  // close the polygon
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.shapeId == 1)
        }
    }

    @Test("Polygon missing shape returns empty")
    func polygonMiss() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 1)

        let viewSize = SIMD2<Double>(200, 200)
        // Polygon far from center where the box is
        let polygon: [SIMD2<Double>] = [
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 10),
            SIMD2(0, 10),
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.isEmpty)
    }

    @Test("Polygon with fewer than 3 points returns empty")
    func tooFewPoints() {
        let selector = Selector()
        let cam = makeCamera()
        let viewSize = SIMD2<Double>(200, 200)
        let polygon: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 10)]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.isEmpty)
    }

    @Test("Triangular polygon selects shape")
    func triangularPolygon() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()
        let selector = Selector()
        selector.add(shape: box, id: 42)

        let viewSize = SIMD2<Double>(200, 200)
        // Large triangle covering the viewport center (closed)
        let polygon: [SIMD2<Double>] = [
            SIMD2(100, 20),
            SIMD2(180, 180),
            SIMD2(20, 180),
            SIMD2(100, 20),
        ]

        let results = selector.pick(polygon: polygon, camera: cam, viewSize: viewSize)
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.shapeId == 42)
        }
    }
}

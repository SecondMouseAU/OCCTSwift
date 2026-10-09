import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeConstruct Triangulation Tests")
struct ShapeConstructTriangulationTests {
    @Test("triangulation from points")
    func fromPoints() {
        let points: [(Double, Double, Double)] = [
            (0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0),
        ]
        let shape = Shape.triangulationFromPoints(points)
        #expect(shape != nil)
    }

    @Test("triangulation from wire")
    func fromWire() {
        if let w = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(5, 10, 0)], closed: true)
        {
            let shape = Shape.triangulationFromWire(w)
            #expect(shape != nil)
        }
    }
}

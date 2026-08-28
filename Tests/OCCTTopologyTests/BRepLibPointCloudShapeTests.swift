import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib PointCloudShape")
struct BRepLibPointCloudShapeTests {
    @Test("Point cloud by triangulation")
    func pointCloudByTriangulation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.5)
        let result = box.pointCloudByTriangulation()
        #expect(result != nil)
        if let result = result {
            #expect(result.points.count > 0)
            #expect(result.normals.count == result.points.count)
        }
    }

    @Test("Point cloud by density")
    func pointCloudByDensity() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.5)
        let result = box.pointCloudByDensity(1.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.points.count > 0)
        }
    }
}

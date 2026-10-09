import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// Before #1981 both tests asserted only `count > 0`, so a cloud missing points passed. Each is
// now pinned to the count BRepLib_PointCloudShape gives for the same mesh in
// Scripts/repro/766-topology-breplib-builders/transcript.txt: one point per triangulation node
// (24, four per planar face), and 600 by density 1.0 (area 600 at one point per unit area).
@Suite("BRepLib PointCloudShape")
struct BRepLibPointCloudShapeTests {
    @Test("Point cloud by triangulation")
    func pointCloudByTriangulation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(box.mesh(linearDeflection: 0.5))
        let result = try #require(box.pointCloudByTriangulation())
        #expect(result.points.count == 24)
        #expect(result.normals.count == result.points.count)
    }

    @Test("Point cloud by density")
    func pointCloudByDensity() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(box.mesh(linearDeflection: 0.5))
        let result = try #require(box.pointCloudByDensity(1.0))
        #expect(result.points.count == 600)
    }
}

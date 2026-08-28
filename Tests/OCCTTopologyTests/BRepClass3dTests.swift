import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepClass3d Tests")
struct BRepClass3dTests {

    @Test func pointInsideBox() {
        // box(width:height:depth:) centers at origin → [-5,5] in each axis
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let state = box.classifyPoint(SIMD3(0, 0, 0))
        #expect(state == .inside)
    }

    @Test func pointOutsideBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let state = box.classifyPoint(SIMD3(20, 20, 20))
        #expect(state == .outside)
    }

    @Test func pointInsideSphere() {
        guard let sphere = Shape.sphere(radius: 5.0) else { return }
        let state = sphere.classifyPoint(SIMD3(0, 0, 0))
        #expect(state == .inside)
    }

    @Test func pointOutsideSphere() {
        guard let sphere = Shape.sphere(radius: 5.0) else { return }
        let state = sphere.classifyPoint(SIMD3(10, 0, 0))
        #expect(state == .outside)
    }

    // #851: the .on boundary case had no coverage on this copy of the classifier, unlike
    // PointClassificationTests.pointOnBoxFace on Shape.classify(point:), mirrors that test
    // exactly, proving the two independent bridge call paths agree at a boundary point after
    // being unified onto the same BRepClass3d_SolidClassifier mechanism.
    @Test func pointOnBoxFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        // Point on the top face at Z=5 (box extends from -5 to 5 on Z)
        let state = box.classifyPoint(SIMD3(0, 0, 5), tolerance: 1e-3)
        #expect(state == .on)
    }
}

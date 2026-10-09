import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Enhanced Selector Tests

@Suite("Selector Sub-Shape Modes")
struct SelectorSubShapeTests {

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

    @Test("Mode 0 (shape) is active by default")
    func defaultMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)
        #expect(selector.isModeActive(.shape, for: 1) == true)
    }

    @Test("Activate face mode")
    func activateFaceMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)

        selector.activateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == true)
    }

    @Test("Deactivate mode")
    func deactivateMode() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)

        selector.activateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == true)

        selector.deactivateMode(.face, for: 1)
        #expect(selector.isModeActive(.face, for: 1) == false)
    }

    @Test("Face mode pick returns face sub-shape type")
    func faceModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)
        // Deactivate shape mode, activate face mode
        selector.deactivateMode(.shape, for: 1)
        selector.activateMode(.face, for: 1)

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            #expect(results[0].shapeId == 1)
            #expect(results[0].subShapeType == .face)
            // #541: 0-based, so the first face is 0 rather than the "whole shape" sentinel.
            #expect(results[0].subShapeIndex >= 0)
            #expect(box.face(at: Int(results[0].subShapeIndex)) != nil)
        }
    }

    @Test("Edge mode pick returns edge sub-shape type")
    func edgeModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)
        selector.deactivateMode(.shape, for: 1)
        selector.activateMode(.edge, for: 1)
        // Increase tolerance for edge picking
        selector.pixelTolerance = 10

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        // Edges are thin, so we might or might not hit one
        // Just verify no crash and correct sub-shape type if hit
        if !results.isEmpty {
            #expect(results[0].subShapeType == .edge)
            // #541: 0-based, addressable against the shape the pick came from.
            #expect(results[0].subShapeIndex >= 0)
            #expect(box.subShape(type: .edge, index: Int(results[0].subShapeIndex)) != nil)
        }
    }

    @Test("Pixel tolerance getter/setter")
    func pixelTolerance() {
        let selector = Selector()
        selector.pixelTolerance = 5
        #expect(selector.pixelTolerance == 5)
    }

    @Test("Shape mode pick returns the whole-shape sentinel, not an index")
    func shapeModePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = makeCamera()

        let selector = Selector()
        selector.add(shape: box, id: 1)

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            // #541: the "whole shape" sentinel is -1, since 0 is now a real sub-shape index.
            #expect(results[0].subShapeIndex == -1)
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Selector Tests")
struct SelectorTests {

    @Test("Add and pick box at center")
    func pickBoxAtCenter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        let added = selector.add(shape: box, id: 42)
        #expect(added)

        // Pick at center of viewport
        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        // The box should be hit
        if !results.isEmpty {
            #expect(results[0].shapeId == 42)
        }
    }

    @Test("Pick miss at far corner")
    func pickMiss() {
        let box = Shape.box(width: 1, height: 1, depth: 1)!
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 1)

        // Pick at far corner, should miss the small box
        let results = selector.pick(
            at: SIMD2(0, 0),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Multiple shapes return correct IDs")
    func multipleShapes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(-20, 0, 0))!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        let added1 = selector.add(shape: box1, id: 1)
        let added2 = selector.add(shape: box2, id: 2)

        #expect(added1, "First shape should be added")
        #expect(added2, "Second shape should be added")
    }

    @Test("Remove shape then pick returns miss")
    func removeShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let selector = Selector()
        selector.add(shape: box, id: 99)
        let removed = selector.remove(id: 99)
        #expect(removed)

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Rectangle pick covers geometry")
    func rectanglePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 7)

        // Select a large rectangle covering the center
        let results = selector.pick(
            rect: (min: SIMD2(100, 100), max: SIMD2(700, 500)),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            #expect(results[0].shapeId == 7)
        }
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        selector.add(shape: box, id: 1)
        selector.add(shape: box, id: 2)
        selector.clearAll()

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }
}

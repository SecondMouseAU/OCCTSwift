import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766 finding: `Selector.pick` returns no hits at all on the pinned kernel, for every scene in
// this file, including a 10-unit box under the centre pixel. A C++ probe that copies the bridge's
// headless selector (Scripts/repro/766-drawing-selector-tolerance/probe.mm) gets NbPicked() == 0 too,
// with and without zero-to-one depth, so this is how the bridge drives SelectMgr, not a Swift
// wrapper slip. Root cause not established; a likely candidate is that the V3d-free
// `OCCTHeadlessSelector` never populates the Z-layer order map `SelectMgr_ViewerSelector::Pick`
// fills from a view before traversing.
//
// Consequences for these tests, which used to hide it: the two hit tests guarded their only
// assertion with `if !results.isEmpty`, so they passed on no hits; the three emptiness tests
// could not fail, since the pick is always empty. The hit expectations now sit in
// `withKnownIssue`, so the suite stays green today and turns red the day picking starts to work
// (the known issue then stops recurring). The emptiness tests are unchanged; they were proven
// against an injected pick that does return hits (see the PR).
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
        withKnownIssue("Selector.pick returns no hits on the pinned kernel (#766 finding, see the note above the suite)") {
            #expect(results.count >= 1)
            #expect(results.first?.shapeId == 42)
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
        // The camera shows the boxes' centres at pixels (384, 300) and (416, 300).
        let left = selector.pick(at: SIMD2(384, 300), camera: cam, viewSize: SIMD2(800, 600))
        let right = selector.pick(at: SIMD2(416, 300), camera: cam, viewSize: SIMD2(800, 600))
        withKnownIssue("Selector.pick returns no hits on the pinned kernel (#766 finding, see the note above the suite)") {
            #expect(left.first?.shapeId == 1)
            #expect(right.first?.shapeId == 2)
        }
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

        withKnownIssue("Selector.pick returns no hits on the pinned kernel (#766 finding, see the note above the suite)") {
            #expect(results.count >= 1)
            #expect(results.first?.shapeId == 7)
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

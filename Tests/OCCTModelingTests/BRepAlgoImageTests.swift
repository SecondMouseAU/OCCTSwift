import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgo Image Tests")
struct BRepAlgoImageTests {

    @Test func bindAndQuery() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 5)
        else { return }
        let image = ShapeImage()
        image.setRoot(box)
        image.bind(old: box, new: sphere)
        #expect(image.hasImage(box))
        #expect(image.isImage(sphere))
    }

    @Test func clear() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 5)
        else { return }
        let image = ShapeImage()
        image.setRoot(box)
        image.bind(old: box, new: sphere)
        image.clear()
        #expect(!image.hasImage(box))
    }
}

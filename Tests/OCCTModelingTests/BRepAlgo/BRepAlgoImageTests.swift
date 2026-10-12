import Testing

@testable import OCCTSwift

@Suite("BRepAlgo Image Tests")
struct BRepAlgoImageTests {

    // #3332: the old test was `guard ... else { return }` and asserted the two states after the
    // bind only. `hasImage` and `isImage` answered true in a stub that ignored `bind`, and the
    // states BEFORE the bind (nothing known) were never read, so a map that reported everything
    // as imaged passed. Both directions are checked here: before the bind neither query holds,
    // after it `hasImage` holds for the OLD shape only and `isImage` for the NEW shape only, and
    // an unrelated shape answers false to both throughout.
    @Test func bindAndQuery() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 5))
        let other = try #require(Shape.cylinder(radius: 2, height: 3))
        let image = ShapeImage()

        #expect(!image.hasImage(box))
        #expect(!image.isImage(sphere))

        image.setRoot(box)
        // A root alone is not an image of anything.
        #expect(!image.hasImage(box))
        #expect(!image.isImage(box))

        image.bind(old: box, new: sphere)
        #expect(image.hasImage(box))
        #expect(!image.hasImage(sphere), "the new shape has no image of its own")
        #expect(image.isImage(sphere))
        #expect(!image.isImage(box), "the old shape is not an image")
        #expect(!image.hasImage(other))
        #expect(!image.isImage(other))
    }

    @Test func clear() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 5))
        let image = ShapeImage()
        image.setRoot(box)
        image.bind(old: box, new: sphere)
        #expect(image.hasImage(box))
        #expect(image.isImage(sphere))
        image.clear()
        #expect(!image.hasImage(box))
        #expect(!image.isImage(sphere))
    }
}

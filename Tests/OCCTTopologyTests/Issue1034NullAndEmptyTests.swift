import Foundation
import Testing

@testable import OCCTSwift

/// #1034: `isEmptyShape` was `TopoDS_Shape::IsNull()` under a name that collided with `emptied`.
///
/// `emptied` produces a shape with no content that the predicate reports as NOT empty, so the two
/// adjacent members used "empty" for contradictory things. Renamed to `isNull`, which is what it
/// measures. `v4.0.0-beta.1` shipped it with the old name kept as a deprecated alias, and the
/// alias has since been removed. The test that was named for it went too: its body never called
/// `isEmptyShape`, so it pinned nothing about the alias and would have passed with the alias
/// returning the wrong answer.
///
/// `nullified` was deprecated in the same change, on the premise that `emptied` could take its
/// place. It cannot: `emptied` keeps the type, so it clears every null-shape guard that
/// `nullified`'s result trips, and no call site in this package could take the advice. It is the
/// only public way to hold a null shape and it is no longer deprecated, which is why both tests
/// below call it without a warning.
@Suite("Issue1034 null and empty are different questions")
struct Issue1034NullAndEmptyTests {

    /// The trap, pinned from both sides.
    @Test("emptied has no content and is not null; nullified is null")
    func emptiedIsNotNull() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isNull == false)
        #expect(box.faces().count == 6)

        let emptied = try #require(box.emptied)
        #expect(emptied.faces().count == 0)
        #expect(emptied.isNull == false)
        #expect(emptied.shapeType == box.shapeType)
    }

    /// `isNull` is the only one of the two that a nullified shape answers true to.
    @Test("a nullified shape is null and has lost its type")
    func nullifiedIsNull() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(nulled.isNull == true)
        #expect(nulled.shapeType != box.shapeType)
    }
}

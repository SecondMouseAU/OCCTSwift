import Foundation
import Testing

@testable import OCCTSwift

/// #1034: `isEmptyShape` was `TopoDS_Shape::IsNull()` under a name that collided with `emptied`.
///
/// `emptied` produces a shape with no content that the predicate reports as NOT empty, so the two
/// adjacent members used "empty" for contradictory things. Renamed to `isNull`, which is what it
/// measures. `nullified` is deprecated in the same change: it has no caller in any ecosystem repo.
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

    /// The deprecated alias still answers, so the rename is source-compatible until the next major.
    @Test("the deprecated isEmptyShape alias agrees with isNull")
    func deprecatedAliasAgrees() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(box.isNull == false)
        #expect(nulled.isNull == true)
    }
}

import Foundation
import Testing

@testable import OCCTSwift

/// #1636: `Shape.fixedFreeBounds` returned a compound of free-bound wires and never read
/// `ShapeFix_FreeBounds::GetShape()`, so a caller asking for the repaired shape got something with
/// **no faces in it at all**.
///
/// That is the assertion these tests make. "The call returned non-nil" was true before the fix and
/// is true after it; the face count of the returned shape is what tells the two apart, and it went
/// from 0 to the input's own face count.
///
/// Measured on five fixtures (`Scripts/repro/1636/probe.mm`), `GetShape()` is `IsSame` the input
/// in every one, because the connection step never fired: none of them produced an open free-bound
/// wire for it to connect. That is not a reason to keep returning the wires. The wires are still
/// reachable, on the result, and the shape member now means what the method's name says.
@Suite("Issue #1636: fixedFreeBounds returns the shape, not a bag of wires")
struct Issue1636FixedFreeBoundsShapeTests {

    /// A compound of two coplanar faces meeting along a shared edge.
    private func twoAdjacentFaces() throws -> Shape {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let first = try #require(Shape.face(from: rect))
        let secondFace = try #require(Shape.face(from: rect))
        let second = try #require(secondFace.translated(by: SIMD3(10, 0, 0)))
        return try #require(Shape.compound([first, second]))
    }

    @Test("the returned shape carries the input's faces, it is not a wire compound")
    func resultIsTheModifiedSourceShape() throws {
        let input = try twoAdjacentFaces()
        #expect(input.subShapes(ofType: .face).count == 2)

        let repair = try #require(input.fixedFreeBounds(sewingTolerance: 1e-6, closingTolerance: 1e-4))

        #expect(
            repair.shape.subShapes(ofType: .face).count == 2,
            "ShapeFix_FreeBounds::GetShape() is the modified source shape; the old result had 0 faces")
        #expect(repair.shape.subShapes(ofType: .edge).count == input.subShapes(ofType: .edge).count)
    }

    @Test("an open shell keeps its five faces through the repair")
    func openShellKeepsItsFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let openShell = try #require(Shape.compound(Array(faces.dropLast())))

        let repair = try #require(openShell.fixedFreeBounds())
        #expect(repair.shape.subShapes(ofType: .face).count == 5)
        #expect(repair.closedWireCount >= 1, "an open box shell has one free-bound loop")
    }

    @Test("the free-bound wires are still reachable, on the result")
    func wiresAreStillAvailable() throws {
        let input = try twoAdjacentFaces()
        let repair = try #require(input.fixedFreeBounds(sewingTolerance: 1e-6, closingTolerance: 1e-4))

        #expect(repair.closedWireCount == 1, "two faces sharing an edge give one outer loop")
        #expect(repair.openWireCount == 0)
        let closed = try #require(repair.closedWires)
        #expect(closed.subShapeCount(ofType: .wire) == repair.closedWireCount)
        #expect(
            closed.subShapes(ofType: .face).isEmpty,
            "the wire compound is wires; that is exactly why it was the wrong thing to return as `shape`")
    }

    @Test("two faces with a gap under the sewing tolerance stay two free-bound loops")
    func gapWiderThanTheSewingToleranceIsNotSewn() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let first = try #require(Shape.face(from: rect))
        let secondFace = try #require(Shape.face(from: rect))
        let second = try #require(secondFace.translated(by: SIMD3(10.00005, 0, 0)))
        let input = try #require(Shape.compound([first, second]))

        let repair = try #require(input.fixedFreeBounds(sewingTolerance: 1e-6, closingTolerance: 1e-3))
        #expect(repair.shape.subShapes(ofType: .face).count == 2)
        #expect(
            repair.closedWireCount == 2,
            "5e-5 is above the 1e-6 sewing tolerance, so the two faces are not joined")
    }
}

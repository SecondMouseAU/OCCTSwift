import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #2765: `Shape.convertedToBezier` used to report "this shape had nothing left to convert" as a
/// failure.
///
/// `OCCTShapeConvertToBezier` treated `ShapeUpgrade_ShapeConvertToBezier::Perform()`'s return
/// value as a success flag. It is not one: `ShapeUpgrade_ShapeDivide::Perform()`, which the
/// converter forwards unchanged, ends `myResult = myContext->Apply(myShape, TopAbs_SHAPE);
/// return !myResult.IsSame(myShape);`, so `false` means "nothing changed" and `Result()` is then
/// the input shape. Its only genuine-failure `false` is the `myShape.IsNull()` guard at the top,
/// which the bridge function already covers by rejecting a null shape.
///
/// Measured in `Scripts/repro/2765-convert-to-bezier-perform/`: a single-edge shape whose curve
/// is already a Bezier is the reachable case, since converting a line produces exactly that.
@Suite("Issue 2765: convertedToBezier on a shape with nothing left to convert")
struct Issue2765ConvertToBezierTests {

    /// Wraps one straight edge of a box as a standalone `Shape`.
    private func straightEdgeShape() -> Shape? {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else { return nil }
        guard let line = box.edges().first(where: { $0.curveType == .line }) else { return nil }
        return Shape.fromEdge(line)
    }

    @Test("A line edge converts to a Bezier edge, and converting it again is not a failure")
    func secondConversionOfAnEdgeShapeSucceeds() throws {
        let edgeShape = try #require(straightEdgeShape())
        #expect(edgeShape.subShapeCount(ofType: ShapeType.edge) == 1)

        // First pass has something to do: a line is not a Bezier curve.
        let first = try #require(edgeShape.convertedToBezier)
        #expect(first.subShapeCount(ofType: ShapeType.edge) == 1)
        let firstEdge = try #require(first.edges().first)
        #expect(firstEdge.curveType == .bezierCurve)

        // Second pass has nothing to do. Before the fix, Perform() returned false here and the
        // bridge turned that into nil.
        let second = try #require(first.convertedToBezier)
        #expect(second.subShapeCount(ofType: ShapeType.edge) == 1)
        let secondEdge = try #require(second.edges().first)
        #expect(secondEdge.curveType == .bezierCurve)
    }

    @Test("Repeated conversion stays non-nil rather than failing on one particular pass")
    func repeatedConversionStaysNonNil() throws {
        var shape = try #require(straightEdgeShape())
        for pass in 1...4 {
            let converted = shape.convertedToBezier
            #expect(converted != nil, "pass \(pass) returned nil")
            guard let converted else { return }
            #expect(converted.subShapeCount(ofType: ShapeType.edge) == 1)
            shape = converted
        }
    }

    /// A solid still converts, so the fix did not turn the success path into a no-op.
    @Test("A box still converts, with every face and edge preserved")
    func boxStillConverts() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let bezier = try #require(box.convertedToBezier)
        #expect(bezier.subShapeCount(ofType: ShapeType.face) == 6)
        #expect(bezier.subShapeCount(ofType: ShapeType.edge) == 12)
        #expect(bezier.edges().allSatisfy { $0.curveType == .bezierCurve })
    }
}

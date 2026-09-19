import Foundation
import Testing

@testable import OCCTSwift

/// #1639: `OCCTBRepLibUpdateEdgeTolerance` hardcoded `MaxToleranceToCheck` as `tolerance * 100`,
/// a factor that appeared in no header, doc or changelog, and it returned
/// `BRepLib::UpdateEdgeTol`'s `Bool`, which is `true` on every path that is not a refusal.
///
/// The issue's own measurement is eight runs that returned `true` and moved nothing. The
/// assertion that catches that is not "the call returned non-nil": it is the pair of tolerances
/// on either side of the call, which is what `EdgeToleranceUpdate` now carries.
///
/// The fixture is a box whose edge tolerances have been forced up to 0.05 by
/// `Shape.setTolerance(_:)`. Its pcurves still match its 3D curve exactly, so the measured
/// requirement is the kernel's own 1e-7 floor and the call has real work to do: it brings 0.05
/// back down. The hardcoded ceiling refused exactly this case, because 0.05 is far above
/// `1e-7 * 100`.
@Suite("Issue #1639: updateEdgeTolerance reports what it measured")
struct Issue1639UpdateEdgeToleranceTests {

    /// A box whose every edge carries a deliberately loose 0.05 tolerance, and its first edge.
    private func looseEdge() throws -> Shape {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        box.setTolerance(0.05)
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(edge.edgeTolerance == 0.05)
        return edge
    }

    @Test("an unreachable ceiling lets the measurement run, and it lowers the tolerance")
    func measurementLowersAForcedTolerance() throws {
        let edge = try looseEdge()
        let update = try #require(
            Shape.updateEdgeTolerance(edge: edge, tolerance: 1e-7, maxToleranceToCheck: .infinity))

        #expect(update.toleranceBefore == 0.05)
        #expect(update.changed, "0.05 is not the measured requirement of an exact box edge")
        #expect(update.toleranceAfter < update.toleranceBefore)
        #expect(update.toleranceAfter <= 1e-6)
        #expect(
            edge.edgeTolerance == update.toleranceAfter,
            "the edge is mutated in place, so the reported value is the edge's own")
    }

    @Test("the ceiling the bridge used to hardcode refuses that same edge outright")
    func hardcodedCeilingRefusesTheOnlyCaseThatDoesWork() throws {
        let edge = try looseEdge()
        // tolerance * 100 is what the bridge derived before #1639, and it is below the edge's own
        // 0.05, so BRepLib::UpdateEdgeTol returns false before measuring anything.
        let refused = Shape.updateEdgeTolerance(
            edge: edge, tolerance: 1e-7, maxToleranceToCheck: 1e-7 * 100)
        #expect(refused == nil, "a refusal is nil, not a value that reads as a measurement")
        #expect(edge.edgeTolerance == 0.05, "and the edge is untouched")
    }

    @Test("a run that moves nothing is reported as moving nothing, not as success")
    func exactEdgeDoesNotMove() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let before = edge.edgeTolerance

        for requested in [1e-9, 1e-5, 0.5, 2.0] {
            let update = try #require(
                Shape.updateEdgeTolerance(
                    edge: edge, tolerance: requested, maxToleranceToCheck: .infinity))
            #expect(
                !update.changed,
                "asked \(requested): a freshly built box edge has exact pcurves, nothing to move")
            #expect(update.toleranceBefore == before)
            #expect(update.toleranceAfter == before)
        }
        #expect(edge.edgeTolerance == before)
    }

    @Test("`tolerance` is MinToleranceRequest and is never written to the edge")
    func requestedToleranceIsNotWritten() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let update = try #require(
            Shape.updateEdgeTolerance(edge: edge, tolerance: 2.0, maxToleranceToCheck: .infinity))
        #expect(update.toleranceAfter != 2.0)
        #expect(edge.edgeTolerance != 2.0)
    }

    @Test("anything that is not an edge is refused")
    func nonEdgeInputIsRefused() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(Shape.updateEdgeTolerance(edge: box, tolerance: 1e-5) == nil)
        let face = try #require(box.subShapes(ofType: .face).first)
        #expect(Shape.updateEdgeTolerance(edge: face, tolerance: 1e-5) == nil)
    }
}

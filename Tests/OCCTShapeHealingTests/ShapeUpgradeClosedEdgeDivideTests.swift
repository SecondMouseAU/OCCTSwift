import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ClosedEdgeDivide

// #766: before #766 this looped over the edges, discarded every answer and ended in
// `#expect(Bool(true))`, returning early (silently green) on a failed fixture. It now pins
// ShapeUpgrade_ClosedEdgeDivide::Compute on the cylinder's lateral face (face 0) for each of its
// three edges, in TopExp::MapShapes order (Scripts/repro/766-healing-shapeupgrade/transcript.txt):
// the two closed circles can be divided (true), the straight seam cannot (false).

@Suite("ShapeUpgrade ClosedEdgeDivide")
struct ShapeUpgradeClosedEdgeDivideTests {

    @Test("Check closed edge on cylinder")
    func closedEdgeOnCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let edges = cyl.subShapes(ofType: .edge)
        let face = try #require(cyl.subShapes(ofType: .face).first)
        #expect(edges.count == 3)
        #expect(edges.map { $0.canDivideClosedEdge(onFace: face) } == [true, false, true])
    }
}

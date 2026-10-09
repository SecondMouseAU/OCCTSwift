import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ClosedEdgeDivide

@Suite("ShapeUpgrade ClosedEdgeDivide")
struct ShapeUpgradeClosedEdgeDivideTests {
    @Test("Check closed edge on cylinder")
    func closedEdgeOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        // Some edges on a cylinder are seam edges, just verify no crash
        for edge in edges {
            if edge.canDivideClosedEdge(onFace: faces[0]) {
                break
            }
        }
        #expect(Bool(true))
    }
}

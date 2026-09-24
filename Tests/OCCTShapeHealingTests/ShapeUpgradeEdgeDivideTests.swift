import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_EdgeDivide

// #766: before #766 both tests asserted only inside `if let result`, and returned early (silently
// green) on a failed fixture. The `if let` never ran: ShapeUpgrade_EdgeDivide::Compute, with the
// default split tools the bridge leaves in place, returns false on the box's first edge and on
// every edge of the cylinder, although it finds both a 3D curve and a pcurve on each
// (Scripts/repro/766-healing-shapeupgrade/transcript.txt), and `analyzeEdgeDivide(onFace:)` maps
// a false Compute to nil, discarding hasCurve2d/hasCurve3d. So the wrapper answers nil for these
// ordinary edges; that is pinned here as the kernel-parity answer. Finding: the curve flags the
// result type carries are never observable through this wrapper on these fixtures.

@Suite("ShapeUpgrade EdgeDivide")
struct ShapeUpgradeEdgeDivideTests {

    @Test("Analyze edge divide on face")
    func analyzeEdgeDivide() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let face = try #require(box.subShapes(ofType: .face).first)
        // Kernel: Compute false (HasCurve2d true, HasCurve3d true), so the wrapper returns nil.
        #expect(edge.analyzeEdgeDivide(onFace: face) == nil)
    }

    @Test("Analyze edge divide returns has curve info")
    func edgeDivideCurveInfo() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let edges = cyl.subShapes(ofType: .edge)
        let face = try #require(cyl.subShapes(ofType: .face).first)
        #expect(edges.count == 3)
        // Kernel: Compute false on all three edges against the lateral face.
        #expect(edges.filter { $0.analyzeEdgeDivide(onFace: face) != nil }.isEmpty)
    }
}

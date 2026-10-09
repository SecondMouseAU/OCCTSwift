import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 three of these discarded their answers and the first asserted only inside
// `if removed`, which a healthy edge never is. On the box's first edge and face the kernel reports
// that none of these ShapeFix_Edge fixes had anything to do.
@Suite("v0.122.0, ShapeFix_Edge Extended")
struct ShapeFixEdgeExtendedTests {
    private func edgeAndFace() throws -> (edge: Shape, face: Shape) {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(b.subShapes(ofType: .edge).first)
        let face = try #require(b.subShapes(ofType: .face).first)
        return (edge, face)
    }

    @Test("Add and remove 3D curve")
    func addRemoveCurve3d() throws {
        let (edge, _) = try edgeAndFace()
        #expect(Shape.fixEdgeRemoveCurve3d(edge) == false)
        #expect(Shape.fixEdgeAddCurve3d(edge) == false)
        #expect(EdgeAnalysis.hasCurve3d(edge))
    }

    @Test("Add PCurve to edge on face")
    func addPCurve() throws {
        let (edge, face) = try edgeAndFace()
        #expect(Shape.fixEdgeAddPCurve(edge, face: face, isSeam: false) == false)
    }

    @Test("Remove PCurve from edge on face")
    func removePCurve() throws {
        let (edge, face) = try edgeAndFace()
        #expect(Shape.fixEdgeRemovePCurve(edge, face: face) == false)
    }

    @Test("Fix reversed 2D curve")
    func fixReversed2d() throws {
        let (edge, face) = try edgeAndFace()
        #expect(Shape.fixEdgeReversed2d(edge, face: face) == false)
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_EdgeDivide

@Suite("ShapeUpgrade EdgeDivide")
struct ShapeUpgradeEdgeDivideTests {
    @Test("Analyze edge divide on face")
    func analyzeEdgeDivide() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let faces = box.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        if let result = edges[0].analyzeEdgeDivide(onFace: faces[0]) {
            #expect(result.hasCurve3d)
        }
    }

    @Test("Analyze edge divide returns has curve info")
    func edgeDivideCurveInfo() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        // Try multiple edges to find one on a face
        for edge in edges {
            if let result = edge.analyzeEdgeDivide(onFace: faces[0]) {
                #expect(result.hasCurve3d || result.hasCurve2d)
                return
            }
        }
    }
}

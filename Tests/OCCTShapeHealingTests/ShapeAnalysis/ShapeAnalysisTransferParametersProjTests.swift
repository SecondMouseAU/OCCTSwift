import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis TransferParametersProj")
struct ShapeAnalysisTransferParametersProjTests {
    @Test("Transfer parameter edge to face")
    func transferToFace() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        let param = edges[0].transferParameterToFace(1.0, face: faces[0])
        // Just verify it returns a finite number
        #expect(param.isFinite)
    }

    @Test("Transfer parameter face to edge")
    func transferFromFace() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        let param = edges[0].transferParameterFromFace(1.0, face: faces[0])
        #expect(param.isFinite)
    }
}

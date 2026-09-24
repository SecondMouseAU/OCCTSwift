import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapeanalysis/probe.mm (transcript.txt beside it).
// Before #766 both returned early, silently green, when the fixture failed, and asserted only
// `isFinite`. The kernel maps parameter 1.0 to 1.0 in both directions for the cylinder's first
// mapped edge on its first mapped face.
@Suite("ShapeAnalysis TransferParametersProj")
struct ShapeAnalysisTransferParametersProjTests {
    private func edgeAndFace() throws -> (edge: Shape, face: Shape) {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 20))
        let edge = try #require(cyl.subShapes(ofType: .edge).first)
        let face = try #require(cyl.subShapes(ofType: .face).first)
        return (edge, face)
    }

    @Test("Transfer parameter edge to face")
    func transferToFace() throws {
        let (edge, face) = try edgeAndFace()
        #expect(abs(edge.transferParameterToFace(1.0, face: face) - 1.0) < 1e-9)
    }

    @Test("Transfer parameter face to edge")
    func transferFromFace() throws {
        let (edge, face) = try edgeAndFace()
        #expect(abs(edge.transferParameterFromFace(1.0, face: face) - 1.0) < 1e-9)
    }
}

import Testing

@testable import OCCTSwift

@Suite("Approx CurveOnSurface")
struct ApproxCurveOnSurfaceTests {
    @Test("Approximate curve on surface from edge PCurve")
    func approxCurveOnSurface() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else {
            #expect(Bool(false), "Failed to create cylinder")
            return
        }
        // #766: this used to end in `#expect(Bool(true))` on every path, so it could not fail.
        // faces()[0] is the lateral cylindrical face and edges() is [top circle, seam, bottom
        // circle]; every one has a pcurve on the lateral face. The approximated 3D curve must
        // reproduce the edge it came from: Approx_CurveOnSurface gives 62.831907482185159 for the
        // 2 pi r = 62.83185307 circle (MaxError3d 4.6e-5 against the 1e-4 tolerance) and exactly
        // 20 for the seam. Kernel values from Scripts/repro/766-approx-curve-on-surface/.
        let faces = cyl.faces()
        let edges = cyl.edges()
        #expect(faces.count == 3)
        #expect(edges.count == 3)
        guard faces.count == 3, edges.count == 3 else { return }
        let expected = [62.831907482185159, 20.0, 62.831907482185159]
        for (i, edge) in edges.enumerated() {
            let result = edge.approxCurveOnSurface(face: faces[0])
            #expect(result != nil, "edge \(i)")
            if let length = result?.edges().first?.length {
                #expect(abs(length - expected[i]) < 1e-6, "edge \(i)")
                #expect(abs(length - edge.length) < 1e-4, "edge \(i)")
            }
        }
    }
}

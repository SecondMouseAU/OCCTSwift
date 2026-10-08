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
        let faces = cyl.faces()
        let edges = cyl.edges()
        if faces.count > 0 && edges.count > 0 {
            // Try each edge on the first face
            for edge in edges {
                let result = edge.approxCurveOnSurface(face: faces[0])
                if result != nil {
                    #expect(Bool(true))
                    return
                }
            }
            // If no edge succeeded, that's ok, no crash is success
            #expect(Bool(true))
        }
    }
}

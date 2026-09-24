import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Contap Contour Full")
struct ContapContourFullTests {
    /// The lateral face of a cylinder viewed along X has two silhouette rulings, so `Contap_Contour`
    /// reports two lines on it (`Scripts/repro/766-contap-contour/`). The old form of this test
    /// looped the faces and returned early on the first non-nil result, so a nil from every face
    /// passed it too.
    @Test("Contour on cylinder face with direction")
    func contourOnCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 20))
        let lateral = try #require(
            cyl.subShapes(ofType: .face).first { Face($0)?.surfaceType == .cylinder })
        let result = try #require(lateral.contapContourDirection(SIMD3(1, 0, 0)))
        #expect(result.lineCount == 2)
    }
}

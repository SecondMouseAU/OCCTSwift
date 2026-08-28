import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Contap Contour Full")
struct ContapContourFullTests {
    @Test("Contour on cylinder face with direction")
    func contourOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Try each face with direction perpendicular to cylinder axis
        for face in faces {
            if let result = face.contapContourDirection(SIMD3(1, 0, 0)) {
                #expect(result.lineCount > 0)
                // Some contour lines may be analytic (line/circle) with 0 walking points
                // Just verify we got contour lines
                return
            }
        }
    }
}

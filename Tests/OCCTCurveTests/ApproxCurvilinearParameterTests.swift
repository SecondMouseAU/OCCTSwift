import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx CurvilinearParameter")
struct ApproxCurvilinearParameterTests {
    @Test("Arc-length reparameterize circle edge")
    func curvilinearCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Try to find a circular edge
        for edge in edges {
            if let result = edge.curvilinearParameter() {
                #expect(result.isValid)
                return
            }
        }
    }
}

import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Closed Edge Splitting

@Suite("Closed Edge Splitting")
struct ClosedEdgeSplittingTests {
    @Test("Cylinder closed edges are split")
    func cylinderClosedEdges() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edgesBefore = cyl.edges().count
        let result = cyl.dividedClosedEdges()
        #expect(result != nil)
        if let result {
            let edgesAfter = result.edges().count
            // Should have more edges after splitting closed circular edges
            #expect(edgesAfter > edgesBefore)
        }
    }

    @Test("Box with no closed edges returns nil or same count")
    func boxNoClosedEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedClosedEdges()
        // Box has no closed edges. Perform() may return false, yielding nil
        if let result {
            #expect(result.edges().count == box.edges().count)
        }
        // nil is also acceptable (no work to do)
    }
}

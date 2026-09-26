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

    @Test("Box with no closed edges comes back unchanged")
    func boxNoClosedEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // A box has no closed edge, so Perform() returns false. Since #2769 that is read as
        // "nothing was done" rather than as a failure, and Result() (the input shape) comes back.
        let result = try #require(box.dividedClosedEdges())
        #expect(result.edges().count == box.edges().count)
        #expect(result.isSame(as: box))
    }
}

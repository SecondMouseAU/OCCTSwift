import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Drop Small Edges")
struct DropSmallEdgesTests {
    @Test("Drop small edges on clean box")
    func cleanBoxNoChange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.droppingSmallEdges(tolerance: 1e-6)
        #expect(result != nil)
        if let r = result {
            // Clean box should keep same topology
            #expect(r.edges().count == box.edges().count)
        }
    }

    @Test("Drop small edges with larger tolerance")
    func largerTolerance() {
        // Create a box with tiny features via chamfer
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.droppingSmallEdges(tolerance: 0.001)
        #expect(result != nil)
    }

    @Test("Drop small edges API callable")
    func apiCallable() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.droppingSmallEdges()
        #expect(result != nil)
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Remove Locations")
struct RemoveLocationsTests {
    @Test("Remove locations from translated shape")
    func removeFromTranslated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let moved = box.translated(by: SIMD3(100, 200, 300))!
        let flat = moved.removingLocations()
        #expect(flat != nil)
        #expect(flat!.isValid)
        // Volume should be preserved
        #expect(abs(flat!.volume! - box.volume!) < 0.01)
    }

    @Test("Remove locations from rotated shape")
    func removeFromRotated() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let rotated = cyl.rotated(axis: SIMD3(1, 0, 0), angle: .pi / 4)!
        let flat = rotated.removingLocations()
        #expect(flat != nil)
        #expect(flat!.isValid)
    }
}

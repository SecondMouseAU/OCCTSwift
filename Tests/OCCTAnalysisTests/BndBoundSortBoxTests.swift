import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bnd BoundSortBox Tests")
struct BndBoundSortBoxTests {

    @Test func compareOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0],
            [50.0, 50.0, 50.0, 60.0, 60.0, 60.0],
            [5.0, 5.0, 5.0, 15.0, 15.0, 15.0],
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 8, ymin: 8, zmin: 8, xmax: 12, ymax: 12, zmax: 12)
        #expect(hits.count >= 2)  // overlaps boxes 0 and 2
    }

    @Test func compareNonOverlapping() {
        let boxes = [
            [0.0, 0.0, 0.0, 10.0, 10.0, 10.0]
        ]
        let sorter = BoundSortBox(boxes: boxes)
        let hits = sorter.compare(xmin: 90, ymin: 90, zmin: 90, xmax: 95, ymax: 95, zmax: 95)
        #expect(hits.count == 0)
    }
}

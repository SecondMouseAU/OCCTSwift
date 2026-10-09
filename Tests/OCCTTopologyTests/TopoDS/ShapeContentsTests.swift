import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Contents")
struct ShapeContentsTests {
    @Test("Box contents")
    func boxContents() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let c = box.contents
        #expect(c.solids == 1)
        #expect(c.shells == 1)
        #expect(c.faces == 6)
        // #541: ShapeAnalysis_ShapeContents counts *occurrences*, not distinct sub-shapes, so
        // these are not edgeCount/vertexCount and are not index bounds. A box's every edge is
        // visited once per adjacent face. Pinned exactly in Issue541FaceIndexContractTests.
        #expect(c.edges == 24)
        #expect(c.vertices == 48)
    }

    @Test("Cylinder contents")
    func cylinderContents() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let c = cyl.contents
        #expect(c.solids == 1)
        #expect(c.faces == 3)  // top, bottom, lateral
    }
}

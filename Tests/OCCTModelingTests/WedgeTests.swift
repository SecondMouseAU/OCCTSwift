import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.29.0 New Features

@Suite("Wedge Primitive")
struct WedgeTests {
    @Test("Create basic wedge")
    func basicWedge() {
        let wedge = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4)
        #expect(wedge != nil)
        #expect(wedge!.isValid)
    }

    @Test("Wedge with zero ltx is a pyramid")
    func pyramidWedge() {
        let pyramid = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 0)
        #expect(pyramid != nil)
        #expect(pyramid!.isValid)
    }

    @Test("Wedge with ltx=dx is a box")
    func boxWedge() {
        let box = Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 10)
        #expect(box != nil)
        #expect(box!.isValid)
    }

    @Test("Advanced wedge with custom top bounds")
    func advancedWedge() {
        let wedge = Shape.wedge(dx: 10, dy: 5, dz: 8, xmin: 2, zmin: 1, xmax: 8, zmax: 6)
        #expect(wedge != nil)
        #expect(wedge!.isValid)
    }

    @Test("Invalid parameters return nil")
    func invalidWedge() {
        #expect(Shape.wedge(dx: 0, dy: 5, dz: 8, ltx: 4) == nil)
        #expect(Shape.wedge(dx: 10, dy: -1, dz: 8, ltx: 4) == nil)
    }
}

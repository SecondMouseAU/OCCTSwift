import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Drawing Tests")
struct DrawingTests {

    @Test("Create 2D projection of box")
    func project2DBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1))
        #expect(drawing != nil)
    }

    @Test("Get visible edges from projection")
    func visibleEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        let visible = drawing.visibleEdges
        #expect(visible != nil)
    }

    @Test("Get hidden edges from isometric view")
    func hiddenEdgesIsometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create isometric view")
            return
        }
        let hidden = drawing.hiddenEdges
        // Isometric view of box should have hidden edges
        #expect(hidden != nil)
    }

    @Test("Standard views")
    func standardViews() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        let top = Drawing.topView(of: box)
        #expect(top != nil)

        let front = Drawing.frontView(of: box)
        #expect(front != nil)

        let side = Drawing.sideView(of: box)
        #expect(side != nil)
    }
}

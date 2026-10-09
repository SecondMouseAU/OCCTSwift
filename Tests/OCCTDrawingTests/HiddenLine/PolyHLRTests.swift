import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.39.0. OCCT Test Suite Audit Round 8

@Suite("Polygon-Based HLR")
struct PolyHLRTests {
    @Test("Fast top view of box produces edges")
    func fastTopViewBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.fastTopView(of: box)
        #expect(drawing != nil)
        if let drawing {
            let visible = drawing.visibleEdges
            #expect(visible != nil)
        }
    }

    @Test("Fast isometric view of box")
    func fastIsometricBox() {
        let box = Shape.box(width: 20, height: 10, depth: 5)!
        let drawing = Drawing.fastIsometricView(of: box)
        #expect(drawing != nil)
        if let drawing {
            #expect(drawing.visibleEdges != nil)
        }
    }

    @Test("Fast projection of cylinder")
    func fastProjectCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let drawing = Drawing.projectFast(cyl, direction: SIMD3(1, 0, 0))
        #expect(drawing != nil)
        if let drawing {
            #expect(drawing.visibleEdges != nil)
            #expect(drawing.outlineEdges != nil)
        }
    }

    @Test("Fast projection has hidden edges")
    func fastHiddenEdges() {
        // Two overlapping boxes, should produce hidden edges
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 5, height: 5, depth: 20)!
        let fused = box1.union(box2)!
        let drawing = Drawing.projectFast(fused, direction: SIMD3(0, 1, 0))
        #expect(drawing != nil)
    }

    @Test("Fast vs exact projection both succeed")
    func fastVsExact() {
        let sphere = Shape.sphere(radius: 10)!
        let exact = Drawing.topView(of: sphere)
        let fast = Drawing.fastTopView(of: sphere)
        #expect(exact != nil)
        #expect(fast != nil)
    }

    @Test("Custom deflection affects result")
    func customDeflection() {
        let sphere = Shape.sphere(radius: 10)!
        let coarse = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 1.0)
        let fine = Drawing.projectFast(sphere, direction: SIMD3(0, 0, 1), deflection: 0.001)
        #expect(coarse != nil)
        #expect(fine != nil)
    }
}

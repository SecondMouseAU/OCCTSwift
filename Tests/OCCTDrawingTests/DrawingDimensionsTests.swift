import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.137 Ch4: Drawing 2D dimension API (#64)

@Suite("v0.137 Drawing dimensions")
struct DrawingDimensionsTests {
    @Test("Add linear dimension stores measurable value")
    func linear() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let d = drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(100, 0), offset: 15)
        #expect(drawing.dimensions.count == 1)
        #expect(abs(d.value - 100) < 1e-9)
        if case .linear(let lin) = d {
            #expect(abs(lin.offset - 15) < 1e-9)
        } else {
            Issue.record("not a linear case")
        }
    }

    @Test("Radial / diameter relate correctly")
    func radialDiameter() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let r = drawing.addRadialDimension(centre: SIMD2(50, 50), radius: 10)
        let d = drawing.addDiameterDimension(centre: SIMD2(50, 50), radius: 10)
        #expect(abs(r.value - 10) < 1e-9)
        #expect(abs(d.value - 20) < 1e-9)
        #expect(drawing.dimensions.count == 2)
    }

    @Test("Angular dimension computes angle between rays")
    func angular() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let d = drawing.addAngularDimension(
            vertex: SIMD2(0, 0),
            ray1: SIMD2(10, 0),
            ray2: SIMD2(0, 10))
        #expect(abs(d.value - .pi / 2) < 1e-9)
    }

    @Test("Annotations separate from dimensions")
    func annotations() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.addCentreLine(from: SIMD2(-10, 0), to: SIMD2(10, 0))
        drawing.addCentermark(centre: SIMD2(0, 0))
        drawing.addTextLabel("DETAIL A", at: SIMD2(5, 5))
        #expect(drawing.annotations.count == 3)
        #expect(drawing.dimensions.isEmpty)
    }

    @Test("clearAnnotations empties both collections")
    func clear() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(5, 0))
        drawing.addCentreLine(from: SIMD2(0, 0), to: SIMD2(5, 0))
        drawing.clearAnnotations()
        #expect(drawing.dimensions.isEmpty)
        #expect(drawing.annotations.isEmpty)
    }
}

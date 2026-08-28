import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.144 #75: Drawing.transformed + bounds

@Suite("v0.144 Drawing transform + bounds")
struct DrawingCompositionTests {
    @Test("Drawing.bounds returns finite box for a projected box")
    func drawingBounds() {
        guard let box = Shape.box(width: 100, height: 50, depth: 25),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let bounds = front.bounds()
        #expect(bounds != nil)
        if let b = bounds {
            #expect(b.min.x.isFinite && b.max.x.isFinite)
            #expect(b.max.x > b.min.x)
        }
    }

    @Test("transformed(translate:scale:) returns non-nil wrapper")
    func transformedSmoke() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let transformed = top.transformed(translate: SIMD2(50, 30), scale: 0.5)
        #expect(transformed.translate == SIMD2(50, 30))
        #expect(transformed.scale == 0.5)
    }

    @Test("DXFWriter.collectFromDrawing accepts TransformedDrawing")
    func dxfFromTransformed() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let t = top.transformed(translate: SIMD2(100, 100), scale: 2.0)
        let writer = DXFWriter()
        writer.collectFromDrawing(t)
        // At least some lines or polylines should have been emitted.
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
    }
}


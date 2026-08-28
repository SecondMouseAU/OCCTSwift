import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.148 #83, #84: Drawing append dispatcher

@Suite("v0.148 Drawing.append(_:) unified dispatcher")
struct DrawingAppendTests {
    @Test("append single annotation")
    func singleAnnotation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.append(.centreline(.init(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        #expect(drawing.annotations.count == 1)
    }

    @Test("append factory output installs every annotation case")
    func factoryOutput() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let anns = DrawingAnnotation.surfaceFinish(
            at: SIMD2(10, 10), leaderTo: SIMD2(20, 5),
            ra: 1.6, symbol: .machiningRequired)
        let expectedCount = anns.count
        drawing.append(contentsOf: anns)
        #expect(drawing.annotations.count == expectedCount)
    }

    @Test("append GD&T feature control frame output")
    func gdtFactoryOutput() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let anns = DrawingAnnotation.featureControlFrame(
            at: .zero, symbol: .position, tolerance: "0.1",
            datums: ["A", "B", "C"])
        drawing.append(contentsOf: anns)
        #expect(drawing.annotations.count == anns.count)
    }

    @Test("append pre-built hatch survives round-trip (no consumer switch)")
    func hatchRoundtrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let hatch = DrawingAnnotation.hatch(
            .init(
                boundary: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
                angle: .pi / 4, spacing: 2.0))
        drawing.append(hatch)
        if case .hatch = drawing.annotations.first {
        } else {
            Issue.record("expected hatch to be stored")
        }
    }

    @Test("append pre-built cutting-plane line survives round-trip")
    func cuttingPlaneRoundtrip() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let cpl = DrawingAnnotation.cuttingPlaneLine(
            .init(
                label: "A",
                traceStart: SIMD2(0, 0), traceEnd: SIMD2(100, 0),
                arrowDirection: SIMD2(0, 1)))
        drawing.append(cpl)
        if case .cuttingPlaneLine = drawing.annotations.first {
        } else {
            Issue.record("expected cuttingPlaneLine to be stored")
        }
    }

    @Test("append a pre-built dimension")
    func appendDimension() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.append(.linear(.init(from: SIMD2(0, 0), to: SIMD2(50, 0))))
        #expect(drawing.dimensions.count == 1)
    }

    @Test("append dimensions batch")
    func appendDimensionsBatch() {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let dims: [DrawingDimension] = [
            .linear(.init(from: .zero, to: SIMD2(10, 0))),
            .radial(.init(centre: .zero, radius: 5)),
            .diameter(.init(centre: .zero, radius: 5)),
        ]
        drawing.append(contentsOf: dims)
        #expect(drawing.dimensions.count == 3)
    }
}

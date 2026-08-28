import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #1183: the four scale*p+translate sites share one implementation

/// A `DrawingPrimitiveSink` that just records what it's handed, so a test can assert exact
/// transformed edge coordinates without parsing a writer's own serialization format.
///
/// `DrawingPrimitiveSink`/`collectDrawing` are `internal`, reachable here only via
/// `@testable import`.
fileprivate final class RecordingSink: DrawingPrimitiveSink {
    var deflection: Double = 0.1
    var cachedPrimitiveOps: DrawingPrimitiveOps?
    var entityBuffer = DrawingEntityBuffer()
    var linePoints: [SIMD2<Double>] = []

    func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String) {
        linePoints.append(a)
        linePoints.append(b)
    }
    func addPolyline(_ points: [SIMD2<Double>], closed: Bool, layer: String) {
        linePoints.append(contentsOf: points)
    }
    func addCircle(centre: SIMD2<Double>, radius: Double, layer: String) {}
    func addArc(
        centre: SIMD2<Double>, radius: Double,
        startAngleDeg: Double, endAngleDeg: Double, layer: String
    ) {}
    func addText(
        _ text: String, at position: SIMD2<Double>,
        height: Double, rotationDeg: Double, layer: String
    ) {}
}

/// #1183: the four `scale * p + translate` sites now share one implementation.
///
/// `TransformedDrawing.apply(_:)` was documented as "the" canonical formula with zero callers,
/// while `DrawingDimension.transformed`, `DrawingAnnotation.transformed` and
/// `collectProjectedEdges` (`DrawingDispatch.swift`) each hand-rolled the identical formula in a
/// local `func t`. All four now delegate to `TransformedDrawing.apply(_:translate:scale:)`.
/// These tests assert an exact transformed coordinate at each of the four sites -- the
/// pre-existing coverage the issue found (`DrawingCompositionTests` in `OCCTMathTests`,
/// `OrdinateDimensionTests`/`BalloonTests` above) checked only `.ordinate`/`.balloon` and never
/// `TransformedDrawing.apply(_:)` or the edge path directly -- so a divergence introduced at any
/// one site would previously have gone undetected.
@Suite("#1183 Drawing transform sites share one formula")
struct DrawingTransformUnificationTests {
    @Test("TransformedDrawing.apply(_:) computes scale*p+translate")
    func applyDirect() {
        let t = TransformedDrawing(
            source: Drawing.frontView(of: Shape.box(width: 1, height: 1, depth: 1)!)!,
            translate: SIMD2(100, 200), scale: 2.0)
        #expect(t.apply(SIMD2(3, 4)) == SIMD2(106, 208))
    }

    @Test("DrawingDimension.transformed applies scale*p+translate for .linear")
    func linearDimensionTransform() {
        let d = DrawingDimension.linear(.init(from: SIMD2(1, 2), to: SIMD2(3, 4), offset: 5))
        let t = d.transformed(translate: SIMD2(10, 20), scale: 3)
        if case .linear(let l) = t {
            #expect(l.from == SIMD2(13, 26))
            #expect(l.to == SIMD2(19, 32))
            #expect(l.offset == 15)
        } else {
            Issue.record("expected .linear case")
        }
    }

    @Test("DrawingDimension.transformed applies scale*p+translate for .radial")
    func radialDimensionTransform() {
        let d = DrawingDimension.radial(.init(centre: SIMD2(5, 5), radius: 2))
        let t = d.transformed(translate: SIMD2(1, 1), scale: 4)
        if case .radial(let r) = t {
            #expect(r.centre == SIMD2(21, 21))
            #expect(r.radius == 8)
        } else {
            Issue.record("expected .radial case")
        }
    }

    @Test("DrawingAnnotation.transformed applies scale*p+translate for .centreline")
    func centrelineAnnotationTransform() {
        let ann = DrawingAnnotation.centreline(.init(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let t = ann.transformed(translate: SIMD2(5, 5), scale: 2)
        if case .centreline(let c) = t {
            #expect(c.from == SIMD2(5, 5))
            #expect(c.to == SIMD2(25, 5))
        } else {
            Issue.record("expected .centreline case")
        }
    }

    @Test("collectDrawing's edge path (collectProjectedEdges) applies scale*p+translate")
    func edgeCollectionTransform() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box),
            let bounds = top.bounds(includeAnnotations: false)
        else {
            Issue.record("setup nil")
            return
        }
        let translate = SIMD2(100.0, 200.0)
        let scale = 2.0
        let sink = RecordingSink()
        collectDrawing(top, translate: translate, scale: scale, into: sink)
        #expect(!sink.linePoints.isEmpty)

        // Every transformed edge point should compute the same `scale * p + translate` this
        // test derives independently from the drawing's own (untransformed) bounds, so the
        // recorded extremes should land exactly on the transformed bounds -- not at the
        // untransformed bounds (translate/scale silently dropped) or anywhere else (a
        // differently-derived formula).
        let expectedMin = scale * bounds.min + translate
        let expectedMax = scale * bounds.max + translate
        let gotMinX = sink.linePoints.map(\.x).min()!
        let gotMaxX = sink.linePoints.map(\.x).max()!
        let gotMinY = sink.linePoints.map(\.y).min()!
        let gotMaxY = sink.linePoints.map(\.y).max()!
        #expect(abs(gotMinX - expectedMin.x) < 1e-6)
        #expect(abs(gotMaxX - expectedMax.x) < 1e-6)
        #expect(abs(gotMinY - expectedMin.y) < 1e-6)
        #expect(abs(gotMaxY - expectedMax.y) < 1e-6)
    }
}

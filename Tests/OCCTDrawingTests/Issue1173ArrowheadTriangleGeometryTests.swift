import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1173 (Pass 4b duplication audit, #386): `emitCuttingPlaneLine`'s nested `arrow(at:)`
// (`DrawingDispatch.swift`) and `DrawingAnnotation.datumFeature`'s triangle-pointer block
// (`DrawingSymbols.swift`) independently re-derived the same "unit direction, its perpendicular,
// two base points offset by a half-width from a point set back along that direction" vector
// geometry, with unrelated naming and independently-chosen `backset`/`halfWidth` numbers -- a
// future change to either shape's proportions had to be found and re-applied twice, and the two
// were already inconsistent with each other (a 0.4x shouldered arrowhead vs. a 1.0x full wedge).
// No existing test asserted numeric tip/base/apex coordinates for either site: `cuttingPlaneRoundtrip`
// (`OCCTDrawingTests.swift`) only checks the annotation case round-trips, the golden795 tests
// (`OCCTIOTests.swift`) are byte-exact characterization of the current output rather than an
// assertion the constants are correct, and `datumFeature()` (`OCCTSurfaceTests.swift`) only counts
// annotation shapes.
//
// Fixed by extracting `arrowheadBasePoints(apex:direction:backset:halfWidth:)` (`DrawingStyle.swift`),
// a plain vector computation returning the two base points; both sites now call it with their own
// `backset`/`halfWidth` (unreconciled -- these are legitimately different symbols, an ISO 129
// arrowhead vs. an ISO 5459 datum triangle) instead of independently re-deriving the perpendicular
// offset by hand.
//
// (#1299: the split of `OCCTDrawingTests.swift` by `@Suite` moved `cuttingPlaneRoundtrip` onto
// `DrawingAppendTests.swift`, referenced above by its pre-split filename; the same file/suite,
// just relocated.)
//
// Every expected value below is derived independently with plain vector algebra (verified in
// Python before writing this file), never by calling `arrowheadBasePoints` itself except in the
// one test that directly probes it against that ground truth.
@Suite("#1173: arrowhead/triangle-pointer shared geometry")
struct Issue1173ArrowheadTriangleGeometryTests {

    // MARK: - Direct probe of the shared helper

    @Test("arrowheadBasePoints matches a hand-derived diagonal-direction ground truth")
    func arrowheadBasePointsMatchesHandDerivedGeometry() {
        // apex (10, 0), direction a 3-4-5 unit vector (3/5, 4/5), backset 5, halfWidth 2.5.
        // baseMid = apex - direction*backset = (10 - 3, 0 - 4) = (7, -4)
        // perp = (-4/5, 3/5); left = baseMid + perp*2.5 = (5, -2.5); right = baseMid - perp*2.5 = (9, -5.5)
        let (left, right) = arrowheadBasePoints(
            apex: SIMD2(10, 0), direction: SIMD2(3.0 / 5.0, 4.0 / 5.0),
            backset: 5, halfWidth: 2.5)
        #expect(abs(left.x - 5.0) < 1e-9)
        #expect(abs(left.y - (-2.5)) < 1e-9)
        #expect(abs(right.x - 9.0) < 1e-9)
        #expect(abs(right.y - (-5.5)) < 1e-9)
    }

    // MARK: - emitCuttingPlaneLine's arrow(at:), end to end

    /// `arrow(at:)` is `private`, reachable only through `emitCuttingPlaneLine`, itself `private`
    /// and reachable only by emitting a `.cuttingPlaneLine` annotation through a writer -- so this
    /// asserts the exact arrowhead-leg coordinates a real `DXFWriter` emits, rather than calling
    /// either function directly.
    ///
    /// `arrowDirection: SIMD2(0, 1)` is axis-aligned deliberately: `CuttingPlaneLine.init`
    /// normalizes it via `simd_normalize`, and only an already-unit axis-aligned vector survives
    /// that unchanged in binary floating point, which the DXF text comparison below (exact
    /// `%.6f`-formatted coordinates) needs.
    ///
    /// Hand-derived (arrowLen 8, arrowWidth 3, per-arrow backset 8*0.4=3.2, halfWidth 1.5):
    /// - `arrow(at: (0,0))`:   tip (0, 8);   base1 (-1.5, 4.8); base2 (1.5, 4.8)
    /// - `arrow(at: (100,0))`: tip (100, 8); base1 (98.5, 4.8); base2 (101.5, 4.8)
    @Test("emitCuttingPlaneLine's arrowheads match the shared-geometry hand-derived coordinates")
    func cuttingPlaneLineArrowheadsMatchHandDerivedGeometry() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let drawing = try #require(Drawing.frontView(of: box))
        drawing.append(
            .cuttingPlaneLine(
                .init(
                    label: "T",
                    traceStart: SIMD2(0, 0),
                    traceEnd: SIMD2(100, 0),
                    arrowDirection: SIMD2(0, 1))))

        let writer = DXFWriter()
        writer.collectFromDrawing(drawing)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("1173_arrowhead_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)

        func expectLine(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ label: String) {
            #expect(content.contains(dxfLineBlock(a, b, layer: "TEXT")), "\(label)")
        }
        // start-side arrow: shaft, then both legs from the tip
        expectLine(SIMD2(0, 0), SIMD2(0, 8), "start shaft")
        expectLine(SIMD2(0, 8), SIMD2(-1.5, 4.8), "start tip->base1")
        expectLine(SIMD2(0, 8), SIMD2(1.5, 4.8), "start tip->base2")
        // end-side arrow
        expectLine(SIMD2(100, 0), SIMD2(100, 8), "end shaft")
        expectLine(SIMD2(100, 8), SIMD2(98.5, 4.8), "end tip->base1")
        expectLine(SIMD2(100, 8), SIMD2(101.5, 4.8), "end tip->base2")
    }

    // MARK: - datumFeature's triangle pointer, end to end

    /// `position: (0,0)`, `target: (6,8)` -- a 3-4-5 triangle scaled to length 10, so the
    /// perpendicular math is genuinely exercised rather than trivialized by an axis-aligned
    /// direction (unlike the cutting-plane-line test above, this compares `Double` values with a
    /// tolerance rather than exact DXF text, so a non-axis-aligned direction is safe here).
    ///
    /// Hand-derived (triangleSize 6, backset = full triangleSize, halfWidth = triangleSize/2 = 3):
    /// apex (6, 8); baseMid = apex - u*6 = (2.4, 3.2); baseL (0, 5); baseR (4.8, 1.4)
    @Test("datumFeature's triangle matches the shared-geometry hand-derived coordinates")
    func datumFeatureTriangleMatchesHandDerivedGeometry() {
        let annotations = DrawingAnnotation.datumFeature(
            label: "A", at: SIMD2(0, 0), pointingTo: SIMD2(6, 8))

        let triangleLines: [DrawingAnnotation.Centreline] = annotations.compactMap {
            if case .centreline(let c) = $0 { return c }
            return nil
        }
        func find(from a: SIMD2<Double>, to b: SIMD2<Double>) -> Bool {
            triangleLines.contains {
                abs($0.from.x - a.x) < 1e-9 && abs($0.from.y - a.y) < 1e-9
                    && abs($0.to.x - b.x) < 1e-9 && abs($0.to.y - b.y) < 1e-9
            }
        }
        let apex = SIMD2(6.0, 8.0)
        let baseL = SIMD2(0.0, 5.0)
        let baseR = SIMD2(4.8, 1.4)
        #expect(find(from: apex, to: baseL), "apex->baseL")
        #expect(find(from: apex, to: baseR), "apex->baseR")
        #expect(find(from: baseL, to: baseR), "baseL->baseR")
    }
}

/// Builds the exact substring `DXFExporter.entities()` emits for one `LINE` entity, so a test can
/// assert precise coordinates by containment rather than parsing the whole DXF text. Mirrors
/// `DXFExporter.swift`'s own `pair(_:)` helper and `entities()`'s per-`LINE` layout exactly.
/// Builds the exact substring `DXFExporter.entities()` emits for one `LINE` entity, so a test can
/// assert precise coordinates by containment rather than parsing the whole DXF text. Mirrors
/// `DXFExporter.swift`'s own `pair(_:)` helper and `entities()`'s per-`LINE` layout exactly.
/// Now uses the shared `DXFTestFormat.lineEntity` from DrawingTestFixtures.swift.
private func dxfLineBlock(_ a: SIMD2<Double>, _ b: SIMD2<Double>, layer: String) -> String {
    DXFTestFormat.lineEntity(from: a, to: b, layer: layer)
}

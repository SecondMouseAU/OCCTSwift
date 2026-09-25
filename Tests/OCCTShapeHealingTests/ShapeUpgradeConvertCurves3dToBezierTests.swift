import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertCurve3dToBezier

// #2732: OCCTShapeUpgradeConvertCurves3dToBezier used to set the per-kind modes
// (Set3dLineConversion / Circle / Conic) but never the master Set3dConversion(true), which
// defaults to off, so ShapeUpgrade_ShapeConvertToBezier::Perform() did nothing and Result() was
// always null. Fixed by adding the master switch call.
//
// Validity: with the master switch on, both fixtures below convert successfully but report
// invalid under BRepCheck_Analyzer (`Shape.isValid == false`). A ground-truth C++ probe
// (Scripts/repro/2732-bezier-master-flag/) measured why: every edge whose 3D curve is replaced
// comes back with SameRange == false while SameParameter stays (incorrectly) true, which
// BRepCheck_Analyzer's own documented rule treats as invalid "without any additional check" --
// ShapeUpgrade_ShapeConvertToBezier converts curve geometry but never re-derives that bookkeeping
// or the affected edges' pcurves, the same separation of "ShapeUpgrade" (convert) from "ShapeFix"
// (repair) OCCT's own developer guide describes, and its own usage example for this exact class
// stops at `.Result()` with no follow-up repair step. Where the resulting deviation could be
// measured directly (BRepLib_CheckCurveOnSurface), it was not tolerance-sized: 1.07 units against
// a radius-5 circle, real geometric drift between the untouched pcurve and the new curve, not a
// rounding residual. This is the raw OCCT converter's documented behaviour, not a defect this
// wrapper introduces or should silently repair; a caller wanting a BRepCheck-valid result runs a
// healing pass afterward (e.g. `Shape.healed()`), same as after other geometry-replacing
// operations.
private func bezierEdgeCount(_ shape: Shape) -> Int {
    shape.edges().filter { $0.curveType == .bezierCurve }.count
}

@Suite("ShapeUpgrade ConvertCurves3dToBezier")
struct ShapeUpgradeConvertCurves3dToBezierTests {

    @Test("Convert box curves to bezier")
    func convertBoxCurves() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.convertCurves3dToBezier())
        #expect(result.edges().count == 12)
        #expect(bezierEdgeCount(result) == 12)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
        // Invalid under BRepCheck: every edge's SameRange flag goes stale when its 3D curve is
        // replaced. Measured, not a wrapper defect: see the suite-level comment above.
        #expect(!result.isValid)
    }

    @Test("Convert cylinder curves to bezier")
    func convertCylinderCurves() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let result = try #require(
            cyl.convertCurves3dToBezier(lineMode: true, circleMode: true, conicMode: true))
        #expect(result.edges().count == 17)
        #expect(bezierEdgeCount(result) == 17)
        #expect(abs((result.volume ?? 0) - 785.398163) < 1e-5)
        // Invalid under BRepCheck, same SameRange staleness as the box case above.
        #expect(!result.isValid)
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        // Circle-only conversion is a measured no-op: Perform() reports nothing done and the
        // result keeps the cylinder's original 3 edges, none Bezier (measured, not explained;
        // line and conic modes are both false here and circle alone does not trigger a
        // conversion, though `Set3dCircleConversion` is its own documented flag).
        let result = try #require(
            cyl.convertCurves3dToBezier(lineMode: false, circleMode: true, conicMode: false))
        #expect(result.edges().count == 3)
        #expect(bezierEdgeCount(result) == 0)
        // Nothing changed, so the shape is still the valid cylinder it started as.
        #expect(result.isValid)
    }
}

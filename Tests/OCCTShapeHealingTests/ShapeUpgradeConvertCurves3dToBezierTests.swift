import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertCurve3dToBezier

@Suite("ShapeUpgrade ConvertCurves3dToBezier")
struct ShapeUpgradeConvertCurves3dToBezierTests {
    @Test("Convert box curves to bezier")
    func convertBoxCurves() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.convertCurves3dToBezier() {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert cylinder curves to bezier")
    func convertCylinderCurves() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertCurves3dToBezier(
            lineMode: true, circleMode: true, conicMode: true)
        {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    // #2748: circleMode alone does not convert circles. ShapeUpgrade_ConvertCurve3dToBezier::
    // Compute() (Scripts/repro/2748-bezier-circle-mode/probe.mm reads it from a same-tag V8_0_1
    // occt-src checkout) skips a curve when
    // `(IsKind(Geom_Conic) && !myConicMode) || (IsKind(Geom_Circle) && !myCircleMode)`, and
    // Geom_Circle is a subtype of Geom_Conic, so for a circle the first clause is already true
    // whenever conicMode is false. Circle conversion needs BOTH modes true. This is
    // ShapeUpgrade's own behavior, not a bridge defect: see okf/references/known-occt-bugs.md.
    @Test("Convert with selective modes: circleMode alone leaves circles unconverted (#2748)")
    func convertSelectiveModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let circleEdgesBefore = cyl.edges().filter { $0.curveType == .circle }.count
        #expect(circleEdgesBefore == 2, "premise: a cylinder has two circular rim edges")

        guard
            let result = cyl.convertCurves3dToBezier(
                lineMode: false, circleMode: true, conicMode: false)
        else {
            Issue.record("expected a non-nil result: OCCT reports this input as unconverted, not failed")
            return
        }
        #expect(result.shapeType == .solid || result.shapeType == .compound)
        // The measurement that proves nothing converted: same edge count, same circle count, and
        // no edge became a Bezier curve.
        #expect(result.edges().count == cyl.edges().count)
        #expect(result.edges().filter { $0.curveType == .circle }.count == circleEdgesBefore)
        #expect(result.edges().allSatisfy { $0.curveType != .bezierCurve })
    }

    // #2748: the counterpart proof. conicMode alone is also insufficient (circleMode: false
    // excludes circles from the conic pass), but circleMode AND conicMode together do convert
    // circles: a full circle cannot be one Bezier segment, so the circular edges each split into
    // several Bezier arcs and the edge count rises.
    @Test("Circle conversion requires circleMode AND conicMode together (#2748)")
    func circleConversionRequiresBothModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edgeCountBefore = cyl.edges().count

        if let conicOnly = cyl.convertCurves3dToBezier(
            lineMode: false, circleMode: false, conicMode: true)
        {
            #expect(conicOnly.edges().allSatisfy { $0.curveType != .bezierCurve })
        }

        guard
            let both = cyl.convertCurves3dToBezier(
                lineMode: false, circleMode: true, conicMode: true)
        else {
            Issue.record("expected conversion to succeed with both circleMode and conicMode true")
            return
        }
        #expect(both.edges().count > edgeCountBefore)
        #expect(both.edges().contains { $0.curveType == .bezierCurve })
    }
}

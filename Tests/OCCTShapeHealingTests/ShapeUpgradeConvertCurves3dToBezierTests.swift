import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertCurve3dToBezier

// #766: before #766 each test asserted only `shapeType == .solid || .compound` inside `if let`,
// so a nil result passed. It is always nil: OCCTShapeUpgradeConvertCurves3dToBezier sets the
// per-kind modes (Set3dLineConversion / Circle / Conic) but never the master
// Set3dConversion(true), which defaults to off, so ShapeUpgrade_ShapeConvertToBezier::Perform()
// does nothing and Result() is null (Scripts/repro/766-healing-shapeupgrade, transcript.txt).
// The sibling OCCTShapeConvertToBezier does set it. Each test records that as a known issue and,
// inside it, asserts what the kernel returns with the master mode on, so the day the bridge is
// fixed these tests say so.

private func bezierEdgeCount(_ shape: Shape) -> Int {
    shape.edges().filter { $0.curveType == .bezierCurve }.count
}

@Suite("ShapeUpgrade ConvertCurves3dToBezier")
struct ShapeUpgradeConvertCurves3dToBezierTests {

    @Test("Convert box curves to bezier")
    func convertBoxCurves() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        withKnownIssue("convertCurves3dToBezier never sets Set3dConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on: all 12 edges Bezier, volume 1000.
            let result = try #require(box.convertCurves3dToBezier())
            #expect(result.edges().count == 12)
            #expect(bezierEdgeCount(result) == 12)
            #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
        }
    }

    @Test("Convert cylinder curves to bezier")
    func convertCylinderCurves() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        withKnownIssue("convertCurves3dToBezier never sets Set3dConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on: the 3 edges become 17, all Bezier; volume 785.398163.
            let result = try #require(
                cyl.convertCurves3dToBezier(lineMode: true, circleMode: true, conicMode: true))
            #expect(result.edges().count == 17)
            #expect(bezierEdgeCount(result) == 17)
            #expect(abs((result.volume ?? 0) - 785.398163) < 1e-5)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        withKnownIssue("convertCurves3dToBezier never sets Set3dConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on, circles only: Perform() reports nothing done and the
            // result keeps the cylinder's 3 edges, none Bezier (measured, not explained).
            let result = try #require(
                cyl.convertCurves3dToBezier(lineMode: false, circleMode: true, conicMode: false))
            #expect(result.edges().count == 3)
            #expect(bezierEdgeCount(result) == 0)
        }
    }
}

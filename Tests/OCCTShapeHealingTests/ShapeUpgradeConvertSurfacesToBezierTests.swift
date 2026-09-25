import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

// #2732: OCCTShapeUpgradeConvertSurfaceToBezier used to set the per-kind modes (plane /
// revolution / extrusion / BSpline) but never the master SetSurfaceConversion(true), which
// defaults to off, so ShapeUpgrade_ShapeConvertToBezier::Perform() did nothing and Result() was
// always null. Fixed by adding the master switch call.
//
// Validity: the box fixture below converts successfully but reports invalid under
// BRepCheck_Analyzer (`Shape.isValid == false`); the cylinder fixture stays valid. A ground-truth
// C++ probe (Scripts/repro/2732-bezier-master-flag/) measured why: converting a box's six
// mutually-adjacent planar faces to Bezier leaves every edge's SameRange flag stale (false, while
// SameParameter stays incorrectly true), and where the resulting curve-on-surface deviation could
// be measured directly it was not tolerance-sized: 92 units against a 10-unit box, real drift
// between an edge's untouched pcurve and its face's new Bezier parametrization. The cylinder's two
// end caps convert without the same drift (SameRange stays true), most likely because each cap is
// bounded by a single edge shared with an UNCONVERTED face (the cylindrical wall, which is not a
// "surface of revolution" in OCCT's stricter internal sense, so `revolutionMode` never touches
// it), unlike the box where every edge sits between two independently-reparametrized faces. Either
// way, this is the raw OCCT converter's documented behaviour ("ShapeUpgrade" converts geometry;
// "ShapeFix" repairs consistency, per OCCT's own developer guide, whose usage example for this
// exact class stops at `.Result()`), not a defect this wrapper introduces or should silently
// repair.
private func bezierFaceCount(_ shape: Shape) -> Int {
    shape.faces().filter { $0.surfaceType == .bezierSurface }.count
}

@Suite("ShapeUpgrade ConvertSurfacesToBezier")
struct ShapeUpgradeConvertSurfacesToBezierTests {

    @Test("Convert cylinder surfaces to bezier")
    func convertCylinderSurfaces() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let result = try #require(cyl.convertSurfacesToBezier())
        // The two planar caps become Bezier; the cylindrical wall (not a surface of revolution
        // in OCCT's sense) does not.
        #expect(result.faces().count == 3)
        #expect(bezierFaceCount(result) == 2)
        #expect(abs((result.volume ?? 0) - 785.398163) < 1e-5)
        #expect(result.isValid)
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        // Revolution-only: nothing on a cylinder qualifies (the wall is a plain cylindrical
        // surface, not a Geom_SurfaceOfRevolution), so no face converts.
        let result = try #require(
            cyl.convertSurfacesToBezier(
                planeMode: false, revolutionMode: true,
                extrusionMode: false, bsplineMode: false))
        #expect(result.faces().count == 3)
        #expect(bezierFaceCount(result) == 0)
        #expect(result.isValid)
    }

    @Test("Convert box surfaces to bezier")
    func convertBoxSurfaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(
            box.convertSurfacesToBezier(
                planeMode: true, revolutionMode: false,
                extrusionMode: false, bsplineMode: false))
        #expect(result.faces().count == 6)
        #expect(bezierFaceCount(result) == 6)
        #expect(result.edges().count == 12)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
        // Invalid under BRepCheck: every edge's SameRange flag goes stale once both faces it
        // borders are independently reparametrized. Measured, not a wrapper defect: see the
        // suite-level comment above.
        #expect(!result.isValid)
    }
}

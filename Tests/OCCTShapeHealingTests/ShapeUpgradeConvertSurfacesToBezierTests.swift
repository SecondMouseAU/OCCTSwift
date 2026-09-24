import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

// #766: before #766 each test asserted only `shapeType == .solid || .compound` inside `if let`,
// so a nil result passed. It is always nil: OCCTShapeUpgradeConvertSurfaceToBezier sets the
// per-kind modes (plane / revolution / extrusion / BSpline) but never the master
// SetSurfaceConversion(true), which defaults to off, so ShapeUpgrade_ShapeConvertToBezier::Perform()
// does nothing and Result() is null (Scripts/repro/766-healing-shapeupgrade, transcript.txt).
// Each test records that as a known issue and, inside it, asserts what the kernel returns with
// the master mode on. Note the kernel's box result is itself invalid under BRepCheck (probe), so
// validity is not asserted.

private func bezierFaceCount(_ shape: Shape) -> Int {
    shape.faces().filter { $0.surfaceType == .bezierSurface }.count
}

@Suite("ShapeUpgrade ConvertSurfacesToBezier")
struct ShapeUpgradeConvertSurfacesToBezierTests {

    @Test("Convert cylinder surfaces to bezier")
    func convertCylinderSurfaces() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        withKnownIssue("convertSurfacesToBezier never sets SetSurfaceConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on: the two planar caps become Bezier, the cylindrical
            // wall (not a surface of revolution) does not; volume 785.398163.
            let result = try #require(cyl.convertSurfacesToBezier())
            #expect(result.faces().count == 3)
            #expect(bezierFaceCount(result) == 2)
            #expect(abs((result.volume ?? 0) - 785.398163) < 1e-5)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        withKnownIssue("convertSurfacesToBezier never sets SetSurfaceConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on, revolution only: nothing to convert on a cylinder,
            // 3 faces, none Bezier.
            let result = try #require(
                cyl.convertSurfacesToBezier(
                    planeMode: false, revolutionMode: true,
                    extrusionMode: false, bsplineMode: false))
            #expect(result.faces().count == 3)
            #expect(bezierFaceCount(result) == 0)
        }
    }

    @Test("Convert box surfaces to bezier")
    func convertBoxSurfaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        withKnownIssue("convertSurfacesToBezier never sets SetSurfaceConversion, so it is always nil (#766 finding)") {
            // Kernel with the master mode on, planes only: all 6 faces Bezier, volume 1000.
            let result = try #require(
                box.convertSurfacesToBezier(
                    planeMode: true, revolutionMode: false,
                    extrusionMode: false, bsplineMode: false))
            #expect(result.faces().count == 6)
            #expect(bezierFaceCount(result) == 6)
            #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
        }
    }
}

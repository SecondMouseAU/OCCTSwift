import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom BSplineRestriction Tests")
struct ShapeCustomBSplineRestrictionTests {
    @Test("BSpline restriction on box")
    func bsplineRestrictionBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let result = box.bsplineRestriction() {
            #expect(result.isValid)
            #expect(result.faces().count > 0)
        }
    }

    @Test("BSpline restriction with custom parameters")
    func bsplineRestrictionCustom() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let result = box.bsplineRestriction(
            tol3d: 0.001, tol2d: 0.001,
            maxDegree: 4, maxSegments: 50,
            continuity3d: .c2, continuity2d: .c2
        ) {
            #expect(result.isValid)
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom_BSplineRestriction Advanced")
struct BSplineRestrictionAdvancedTests {
    @Test("restrict box BSpline")
    func restrictBox() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let result = Shape.bsplineRestrictionAdvanced(
                box,
                tol3d: 0.1, tol2d: 0.1,
                maxDegree: 5, maxSegments: 20)
            // May return nil if no BSpline geometry to restrict; just verify no crash
            if let r = result {
                #expect(r.size!.x > 0)
            }
        }
    }
}

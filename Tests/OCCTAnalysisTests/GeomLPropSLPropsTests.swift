import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLProp SLProps")
struct GeomLPropSLPropsTests {
    @Test("Surface properties on sphere face")
    func surfacePropsOnSphere() {
        guard let sph = Shape.sphere(radius: 10) else { return }
        let faces = sph.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Use faceLProp methods instead
        guard let maxCurv = faces[0].faceLPropMaxCurvature(u: 0, v: 0.5) else {
            Issue.record("max curvature undefined on a sphere away from its poles")
            return
        }
        #expect(abs(abs(maxCurv) - 0.1) < 0.02)
    }

    @Test("Normal on plane face")
    func normalOnPlaneFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // A plane's maximum curvature is 0 and defined, the collision #583 is about, so the
        // unwrap carries as much of the assertion as the magnitude does.
        guard let maxCurv = faces[0].faceLPropMaxCurvature(u: 0, v: 0) else {
            Issue.record("max curvature undefined on a planar face")
            return
        }
        #expect(abs(maxCurv) < 0.001)
    }
}

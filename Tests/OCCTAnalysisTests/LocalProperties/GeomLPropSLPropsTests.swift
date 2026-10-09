import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLProp SLProps")
struct GeomLPropSLPropsTests {
    /// `BRepLProp_SLProps` reports the sphere's maximum curvature as -1/10: signed, with the
    /// face's outward normal (#1437). `abs(abs(k) - 0.1)` could not tell -0.1 from +0.1.
    @Test("Surface properties on sphere face")
    func surfacePropsOnSphere() throws {
        let sph = try #require(Shape.sphere(radius: 10))
        let faces = sph.subShapes(ofType: .face)
        let face = try #require(faces.first)
        guard let maxCurv = face.faceLPropMaxCurvature(u: 0, v: 0.5) else {
            Issue.record("max curvature undefined on a sphere away from its poles")
            return
        }
        #expect(abs(maxCurv - (-0.1)) < 1e-12)
    }

    @Test("Normal on plane face")
    func normalOnPlaneFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        let face = try #require(faces.first)
        // A plane's maximum curvature is 0 and defined, the collision #583 is about, so the
        // unwrap carries as much of the assertion as the magnitude does.
        guard let maxCurv = face.faceLPropMaxCurvature(u: 0, v: 0) else {
            Issue.record("max curvature undefined on a planar face")
            return
        }
        #expect(abs(maxCurv) < 0.001)
    }
}

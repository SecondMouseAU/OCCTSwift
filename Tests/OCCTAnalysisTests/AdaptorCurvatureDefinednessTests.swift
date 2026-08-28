import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #529 made `Shape.faceLProp*` agree with `Face.*` about *whether* a quantity exists at a point.
/// Six of them still could not say so: they returned the value bare and used `0` (or `(0, 0, 0)`
/// for the point, or `false` for the umbilic predicate) to mean "undefined here", "the handle was
/// null" and "this `Shape` is not a face" all at once.
///
/// That encoding has no spare value to spend, which is a measurement and not a style objection.
/// Read through the same `BRepLProp_SLProps` the bridge builds
/// (`Scripts/repro/583-lprop-zero-sentinel/`), a cylinder's Gaussian curvature and its *maximum*
/// curvature are exactly `0` at every point of the surface with `IsCurvatureDefined()` true, and a
/// plane's four curvature scalars are all exactly `0` everywhere. So the sentinel collided with the
/// answer across whole faces of the two commonest solids in this suite, not at some pathological
/// parameter.
///
/// Same class as #486's zero-filled `SurfaceGrid` rows and the `curvatureDefined` flag #494 restored
/// to `SurfaceLocalProperties`.
@Suite("Zero curvature is a value, not a sentinel (#583)")
struct AdaptorCurvatureDefinednessTests {

    /// The cone from the parity suite above: apex radius 0, so `v` sweeps smoothly out of the
    /// curvature's domain of definition.
    private static func apexConeFace() -> Shape? {
        guard
            let cone = Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1),
                radius: 0, semiAngle: .pi / 6)
        else { return nil }
        return Shape.face(from: cone, uRange: 0...(2 * .pi), vRange: (-1.0)...10.0)
    }

    /// The headline. A cylinder is developable, so its Gaussian curvature is zero everywhere and its
    /// maximum principal curvature (the one along the axis) is zero everywhere too. Both are
    /// perfectly well defined, and both used to come back as the "undefined" sentinel.
    @Test("A cylinder's zero curvatures are reported as zero, not as absent")
    func cylinderZeroCurvaturesAreDefined() {
        guard let cylinder = Shape.cylinder(radius: 3, height: 12) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        var lateralFaces = 0
        for faceShape in cylinder.subShapes(ofType: .face) {
            // The two planar caps have zero curvature in every direction; the lateral face is the
            // one with a non-zero minimum, and it is the one worth pinning.
            guard let kMin = faceShape.faceLPropMinCurvature(u: 1.1, v: 6), kMin != 0 else {
                continue
            }
            lateralFaces += 1
            #expect(abs(kMin + 1.0 / 3) < 1e-9)
            #expect(faceShape.faceLPropGaussianCurvature(u: 1.1, v: 6) == 0)
            #expect(faceShape.faceLPropMaxCurvature(u: 1.1, v: 6) == 0)
            #expect(faceShape.faceLPropMeanCurvature(u: 1.1, v: 6) != nil)
            // Defined, and the answer is "no": the two principal curvatures genuinely differ here.
            #expect(faceShape.faceLPropIsUmbilic(u: 1.1, v: 6) == false)
        }
        #expect(lateralFaces == 1, "expected exactly one curved face on a cylinder")
    }

    /// A plane is the total collision: all four scalars are zero, the point at `(0, 0)` of a plane
    /// through the origin is `(0, 0, 0)`, and every one of them is defined.
    @Test("A planar face reports four zeros and a point, all of them defined")
    func planarFaceZerosAreDefined() {
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let face = Shape.face(from: plane, uRange: (-10.0)...10.0, vRange: (-10.0)...10.0)
        else {
            Issue.record("could not build the planar face")
            return
        }
        #expect(face.faceLPropMaxCurvature(u: 0, v: 0) == 0)
        #expect(face.faceLPropMinCurvature(u: 0, v: 0) == 0)
        #expect(face.faceLPropMeanCurvature(u: 0, v: 0) == 0)
        #expect(face.faceLPropGaussianCurvature(u: 0, v: 0) == 0)
        // A plane is umbilic everywhere: both curvatures are exactly zero, so OCCT's one-ULP test
        // passes trivially (#494).
        #expect(face.faceLPropIsUmbilic(u: 0, v: 0) == true)
        // And the point that is the origin is still a point.
        if let p = face.faceLPropValue(u: 0, v: 0) {
            #expect(p == SIMD3(0, 0, 0))
        } else {
            Issue.record("faceLPropValue nil at the origin of a plane through the origin")
        }
    }

    /// The other side of the same coin: where the curvature really is undefined, all five say so.
    @Test("A cone apex and a sphere pole report nil, not zero")
    func degeneratePointsReportNil() {
        guard let cone = Self.apexConeFace() else {
            Issue.record("could not build the apex cone face")
            return
        }
        guard let sphere = Shape.sphere(radius: 5) else {
            Issue.record("Shape.sphere returned nil")
            return
        }
        // The apex sits at v = 0; a sphere's poles at v = +/- pi/2.
        var cases: [(Comment, Shape, Double, Double)] = [("cone apex", cone, 0.0, 0.0)]
        for faceShape in sphere.subShapes(ofType: .face) {
            cases.append(("sphere pole", faceShape, 0.0, .pi / 2))
            cases.append(("sphere pole", faceShape, 0.0, -.pi / 2))
        }
        for (label, shape, u, v) in cases {
            #expect(shape.faceLPropMaxCurvature(u: u, v: v) == nil, label)
            #expect(shape.faceLPropMinCurvature(u: u, v: v) == nil, label)
            #expect(shape.faceLPropMeanCurvature(u: u, v: v) == nil, label)
            #expect(shape.faceLPropGaussianCurvature(u: u, v: v) == nil, label)
            // No principal curvatures to compare, so no answer, distinct from the cylinder's
            // "defined, and not umbilic" above.
            #expect(shape.faceLPropIsUmbilic(u: u, v: v) == nil, label)
            // The point does not depend on the curvature gate, so it survives the degeneracy.
            #expect(shape.faceLPropValue(u: u, v: v) != nil, label)
        }
    }

    /// The third thing `0` used to mean. `TopoDS::Face` throws on a `Shape` that is not one, the
    /// bridge catches it, and pre-#583 the caller got the origin and four zeros back.
    @Test("A Shape that is not a face reports nil from all six getters")
    func nonFaceShapeReportsNil() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let edges = box.subShapes(ofType: .edge)
        #expect(!edges.isEmpty)
        for shape in [box] + Array(edges.prefix(1)) {
            #expect(shape.faceLPropValue(u: 0.5, v: 0.5) == nil)
            #expect(shape.faceLPropMaxCurvature(u: 0.5, v: 0.5) == nil)
            #expect(shape.faceLPropMinCurvature(u: 0.5, v: 0.5) == nil)
            #expect(shape.faceLPropMeanCurvature(u: 0.5, v: 0.5) == nil)
            #expect(shape.faceLPropGaussianCurvature(u: 0.5, v: 0.5) == nil)
            #expect(shape.faceLPropIsUmbilic(u: 0.5, v: 0.5) == nil)
        }
    }
}

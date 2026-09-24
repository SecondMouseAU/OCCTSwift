import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every test evaluates the single face of a radius-5 sphere at (u, v) = (0.5, 0.5), where the
// point is 5 * (cos v cos u, cos v sin u, sin v). Values are probed on the pinned kernel:
// Scripts/repro/766-breplprop-face/transcript.txt.
//
// Before #766's execution pass the sphere and its face sat inside `if let` and `if faces.count
// > 0`, so a nil sphere or an empty face list passed every test with nothing asserted, and
// `faceNormal`/`faceTangentU` also wrapped the getter in `if let`, so a getter answering nil
// passed. Those are now guards that record an issue, and the loose `abs(...) < 1.0` and
// `< 0.05` bounds are replaced by the measured values.
@Suite("BRepLProp Face v0.111")
struct BRepLPropFaceTests {
    /// The one face of `Shape.sphere(radius: 5)`, or nil after recording why.
    private func sphereFace() -> Shape? {
        guard let sphere = Shape.sphere(radius: 5) else {
            Issue.record("Shape.sphere(radius: 5) returned nil")
            return nil
        }
        let faces = sphere.subShapes(ofType: .face)
        guard faces.count == 1 else {
            Issue.record("a sphere has one face, got \(faces.count)")
            return nil
        }
        return faces[0]
    }

    private let u = 0.5
    private let v = 0.5

    @Test func faceValue() {
        guard let face = sphereFace() else { return }
        guard let p = face.faceLPropValue(u: u, v: v) else {
            Issue.record("faceLPropValue nil on an ordinary point of a sphere face")
            return
        }
        let expected = 5 * SIMD3(cos(v) * cos(u), cos(v) * sin(u), sin(v))
        #expect(simd_length(p - expected) < 1e-12, "got \(p)")
    }

    @Test func faceNormal() {
        guard let face = sphereFace() else { return }
        guard let n = face.faceLPropNormal(u: u, v: v) else {
            Issue.record("faceLPropNormal nil on an ordinary point of a sphere face")
            return
        }
        // The face is FORWARD, so the normal is the outward radial direction.
        let expected = SIMD3(cos(v) * cos(u), cos(v) * sin(u), sin(v))
        #expect(simd_length(n - expected) < 1e-12, "got \(n)")
    }

    @Test func faceCurvature() {
        // Radius 5: both principal curvatures are 1/5 in magnitude, and negative, because
        // BRepLProp_SLProps signs curvature against the outward normal.
        guard let face = sphereFace() else { return }
        guard let maxK = face.faceLPropMaxCurvature(u: u, v: v),
            let minK = face.faceLPropMinCurvature(u: u, v: v)
        else {
            Issue.record("principal curvatures undefined away from the sphere's poles")
            return
        }
        #expect(abs(maxK - (-0.2)) < 1e-12, "got \(maxK)")
        #expect(abs(minK - (-0.2)) < 1e-12, "got \(minK)")
    }

    @Test func faceMeanAndGaussianCurvature() {
        // Sphere: mean = -1/R (signed as above), Gaussian = 1/R^2.
        guard let face = sphereFace() else { return }
        guard let mean = face.faceLPropMeanCurvature(u: u, v: v),
            let gauss = face.faceLPropGaussianCurvature(u: u, v: v)
        else {
            Issue.record("mean/Gaussian curvature undefined away from the sphere's poles")
            return
        }
        #expect(abs(mean - (-0.2)) < 1e-12, "got \(mean)")
        #expect(abs(gauss - 0.04) < 1e-12, "got \(gauss)")
    }

    @Test func faceIsUmbilic() {
        // A sphere is umbilic everywhere: the two principal curvatures are equal.
        guard let face = sphereFace() else { return }
        guard let maxK = face.faceLPropMaxCurvature(u: u, v: v),
            let minK = face.faceLPropMinCurvature(u: u, v: v)
        else {
            Issue.record("principal curvatures undefined away from the sphere's poles")
            return
        }
        #expect(abs(maxK - minK) < 1e-12)
        // ...and the umbilic getter has an answer to give, whatever it is (#583). OCCT's test is
        // one ULP wide, so which answer depends on the parameter (see #494): at this point the
        // pinned kernel says false, because max and min differ in the last bit.
        #expect(face.faceLPropIsUmbilic(u: u, v: v) != nil)
    }

    @Test func faceTangentU() {
        guard let face = sphereFace() else { return }
        guard let tanU = face.faceLPropTangentU(u: u, v: v) else {
            Issue.record("faceLPropTangentU nil on an ordinary point of a sphere face")
            return
        }
        // dP/du normalised: (-sin u, cos u, 0).
        let expected = SIMD3(-sin(u), cos(u), 0)
        #expect(simd_length(tanU - expected) < 1e-12, "got \(tanU)")
    }
}

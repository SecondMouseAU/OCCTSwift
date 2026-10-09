import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLProp Face v0.111")
struct BRepLPropFaceTests {
    @Test func faceValue() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let p = faces[0].faceLPropValue(u: 0.5, v: 0.5) {
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    // Point on sphere should be at distance ~5
                    #expect(abs(dist - 5.0) < 1.0)
                } else {
                    Issue.record("faceLPropValue nil on an ordinary point of a sphere face")
                }
            }
        }
    }

    @Test func faceNormal() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let n = faces[0].faceLPropNormal(u: 0.5, v: 0.5) {
                    let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                    #expect(abs(len - 1.0) < 1e-4)
                }
            }
        }
    }

    @Test func faceCurvature() {
        // Sphere of radius 5: principal curvatures should be 1/5 = 0.2
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                guard let maxK = faces[0].faceLPropMaxCurvature(u: 0.5, v: 0.5),
                    let minK = faces[0].faceLPropMinCurvature(u: 0.5, v: 0.5)
                else {
                    Issue.record("principal curvatures undefined away from the sphere's poles")
                    return
                }
                #expect(abs(abs(maxK) - 0.2) < 0.05)
                #expect(abs(abs(minK) - 0.2) < 0.05)
            }
        }
    }

    @Test func faceMeanAndGaussianCurvature() {
        // Sphere: mean = 1/R, gaussian = 1/R^2
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                guard let mean = faces[0].faceLPropMeanCurvature(u: 0.5, v: 0.5),
                    let gauss = faces[0].faceLPropGaussianCurvature(u: 0.5, v: 0.5)
                else {
                    Issue.record("mean/Gaussian curvature undefined away from the sphere's poles")
                    return
                }
                #expect(abs(abs(mean) - 0.2) < 0.05)
                #expect(abs(abs(gauss) - 0.04) < 0.02)
            }
        }
    }

    @Test func faceIsUmbilic() {
        // Sphere should be umbilic everywhere, curvatures are equal
        // Use curvature equality as a softer check since IsUmbilic has strict tolerance
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                guard let maxK = faces[0].faceLPropMaxCurvature(u: 0.5, v: 0.5),
                    let minK = faces[0].faceLPropMinCurvature(u: 0.5, v: 0.5)
                else {
                    Issue.record("principal curvatures undefined away from the sphere's poles")
                    return
                }
                // On a sphere, max and min curvatures should be approximately equal
                #expect(abs(maxK - minK) < 0.01)
                // ...and the umbilic getter has an answer to give, whatever it is (#583). OCCT's
                // test is one ULP wide, so which answer depends on the parameter (see #494).
                #expect(faces[0].faceLPropIsUmbilic(u: 0.5, v: 0.5) != nil)
            }
        }
    }

    @Test func faceTangentU() {
        if let sphere = Shape.sphere(radius: 5) {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                if let tanU = faces[0].faceLPropTangentU(u: 0.5, v: 0.5) {
                    let len = sqrt(tanU.x * tanU.x + tanU.y * tanU.y + tanU.z * tanU.z)
                    #expect(abs(len - 1.0) < 1e-4)
                }
            }
        }
    }
}

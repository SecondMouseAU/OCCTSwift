import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Sinert Tests")
struct BRepGPropSinertTests {
    // #766: this asserted `area > 0`, which any non-degenerate face passes whatever the
    // integration gets wrong. `Shape.box` is centred on the origin and `faces()[0]` is the x = -5
    // face (TopExp::MapShapes order): area 100, centroid (-5, 0, 0), probed in
    // Scripts/repro/766-brepgpropsinert.
    @Test("face surface inertia")
    func faceSurfaceInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.faces().first)
        let inertia = face.surfaceInertia
        #expect(abs(inertia.area - 100) < 1e-9)
        let centre = try #require(inertia.centerOfMass)
        #expect(simd_distance(centre, SIMD3(-5, 0, 0)) < 1e-9)
    }

    // #766: this asserted nothing, under the comment "Adaptive variant may return 0 in OCCT 8.0,
    // just verify no crash". The 0 is not OCCT 8.0 behaviour. `OCCTBRepGPropSinertAdaptive`
    // calls `BRepGProp_Sinert::Perform(face, epsilon)`, and that overload integrates over an
    // empty, default-constructed `BRepGProp_Domain`, so every face measures 0. Passing
    // `BRepGProp_Domain(face)` gives 1256.6370614359171 for this sphere, 4 pi r^2, probed in
    // Scripts/repro/766-brepgpropsinert. The correct area is stated as a known issue, #2204, so
    // the fix turns this test red until the wrapper below is removed.
    @Test("adaptive surface inertia on sphere")
    func adaptiveSurfaceInertia() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        let face = try #require(sphere.faces().first)
        let inertia = face.surfaceInertia(epsilon: 1e-6)
        withKnownIssue("#2204: the adaptive overload integrates over an empty domain") {
            #expect(abs(inertia.area - 4 * Double.pi * 100) < 1e-6)
        }
    }
}

import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Sinert Tests")
struct BRepGPropSinertTests {
    @Test("face surface inertia")
    func faceSurfaceInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.surfaceInertia
            #expect(abs(inertia.area - 100.0) < 1e-9, "area was \(inertia.area)")
        }
    }

    /// #2204: the adaptive overload integrates the face, and used to integrate nothing.
    ///
    /// `BRepGProp_Sinert::Perform(face, eps)` builds an empty `BRepGProp_Domain` of its own
    /// (`BRepGProp_Sinert.cxx:96-100`), so the Gauss integration had no boundary to walk and every
    /// face came back with area 0 and, through `massCentroid`, a nil centre of mass. The test that
    /// stood here asserted nothing at all, under a comment calling the zero expected OCCT
    /// behaviour.
    ///
    /// 4 * pi * 10^2 = 1256.6370614359173.
    @Test("adaptive surface inertia on sphere (#2204)")
    func adaptiveSurfaceInertia() throws {
        let sphere = try #require(Shape.sphere(radius: 10))
        let face = try #require(sphere.faces().first)
        let inertia = face.surfaceInertia(epsilon: 1e-6)
        #expect(
            abs(inertia.area - 4 * Double.pi * 100) < 1e-6,
            "adaptive area was \(inertia.area)")
        #expect(inertia.epsilon < 1e-9, "reported error was \(inertia.epsilon)")
        let centre = try #require(inertia.centerOfMass)
        #expect(simd_length(centre) < 1e-9, "centre of mass was \(centre)")
    }

    /// A planar face too, since the comment this replaces claimed the adaptive overload was
    /// meaningful only on curved faces and that a planar face returning 0 was expected (#2204).
    @Test("adaptive surface inertia on a planar face (#2204)")
    func adaptiveSurfaceInertiaOnPlanarFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.faces().first)
        let inertia = face.surfaceInertia(epsilon: 1e-6)
        #expect(abs(inertia.area - 100.0) < 1e-9, "adaptive area was \(inertia.area)")
    }

    /// Both overloads have to agree with each other and with `Face.area(tolerance:)` on a face the
    /// wires trim, which is the case that needs the `BRepGProp_Domain` for a reason other than
    /// the adaptive overload's empty one (#2204).
    ///
    /// The plate's large faces are 20 x 20 patches with a radius-3 hole, so the trimmed area is
    /// 400 - 9 * pi = 371.7256661176920 while the untrimmed patch is 400. `Face.area(tolerance:)`
    /// goes through `BRepGProp::SurfaceProperties`, which loads the domain, and is the second
    /// construction here.
    @Test("Both overloads measure a trimmed face, not its untrimmed patch (#2204)")
    func trimmedFaceIsMeasuredWithItsHole() throws {
        let plate = try #require(Shape.box(width: 20, height: 20, depth: 2))
        let drill = try #require(
            Shape.cylinder(radius: 3, height: 10)?.translated(by: SIMD3(0, 0, -5)))
        let holed = try #require(plate.subtracting(drill))

        let expected = 400.0 - 9.0 * Double.pi
        var holedFaces = 0
        for face in holed.faces() {
            let reference = face.area()
            guard reference > 300 else { continue }  // the two large faces, not the four sides
            holedFaces += 1
            #expect(
                abs(reference - expected) < 1e-6,
                "Face.area() gave \(reference), so the fixture is not the holed plate")
            #expect(
                abs(face.surfaceInertia.area - reference) < 1e-6,
                "non-adaptive gave \(face.surfaceInertia.area) against \(reference)")
            #expect(
                abs(face.surfaceInertia(epsilon: 1e-6).area - reference) < 1e-6,
                "adaptive gave \(face.surfaceInertia(epsilon: 1e-6).area) against \(reference)")
        }
        #expect(holedFaces == 2, "found \(holedFaces) large faces, expected 2")
    }
}

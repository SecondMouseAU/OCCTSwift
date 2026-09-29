import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Vinert Tests")
struct BRepGPropVinertTests {
    /// A 20 x 20 x 2 plate with a radius-3 through hole at the centre.
    ///
    /// The two large caps are trimmed faces: a 20 x 20 patch with a radius-3 hole, area
    /// 400 - 9 * pi. The hole's wall is a seventh face, `REVERSED` in the solid, whose contribution
    /// is negative. `Shape.volume` and `Face.area()` both go through `BRepGProp`'s own loops, which
    /// load the domain, so they are the second construction the per-face integral is checked
    /// against rather than a number copied from this comment.
    private func holedPlate() throws -> Shape {
        let plate = try #require(Shape.box(width: 20, height: 20, depth: 2))
        let drill = try #require(
            Shape.cylinder(radius: 3, height: 10)?.translated(by: SIMD3(0, 0, -5)))
        return try #require(plate.subtracting(drill))
    }

    @Test("face volume inertia")
    func faceVolumeInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.faces().first)
        // Shape.box is centred on the origin, so every face is 5 from it and each of the six
        // contributes (5 / 3) * 100 of the 1000.
        #expect(
            abs(face.volumeInertia.volume - 1000.0 / 6.0) < 1e-9,
            "contribution was \(face.volumeInertia.volume)")
    }

    /// #2806: the per-face contributions have to sum to the volume, for a **trimmed** face too.
    ///
    /// `OCCTBRepGPropVinert` passed no `BRepGProp_Domain`, so `BRepGProp_Gauss` took its no-domain
    /// overload and integrated each face over the surface's natural UV bounds. The two large caps
    /// each reported the unholed 20 x 20 patch, 133.33333333333334 instead of 123.90855537256394,
    /// and the sum came to 762.3008881569225 against `Shape.volume` 743.4513322353836: an overshoot
    /// of 6 * pi, the hole counted once at z = +1 and once at z = -1. The box case above cannot see
    /// this, since a box has no trimmed face.
    @Test("trimmed faces sum to the volume (#2806)")
    func trimmedFaceContributionsSumToVolume() throws {
        let holed = try holedPlate()
        let volume = try #require(holed.volume)
        #expect(
            abs(volume - (800.0 - 18.0 * Double.pi)) < 1e-6,
            "shape volume was \(volume), so the fixture is not the holed plate")

        let faces = holed.faces()
        #expect(faces.count == 7, "found \(faces.count) faces, expected 7")

        let sum = faces.reduce(0.0) { $0 + $1.volumeInertia.volume }
        #expect(abs(sum - volume) < 1e-9, "per-face sum was \(sum) against Shape.volume \(volume)")

        // Per face, and against Face.area() rather than against a constant: a cap 1 away from the
        // origin contributes area / 3, and the untrimmed patch would give 133.33333333333334.
        var caps = 0
        for face in faces where face.area() > 300 {
            caps += 1
            let expected = face.area() / 3.0
            #expect(
                abs(face.volumeInertia.volume - expected) < 1e-9,
                "cap contributed \(face.volumeInertia.volume), expected \(expected)")
        }
        #expect(caps == 2, "found \(caps) large faces, expected 2")

        // The hole's wall is REVERSED in the solid, so its normal points at the axis and its own
        // contribution is negative. The axis passes through the origin, so every point of the wall
        // is the hole's radius from it and the contribution is -(radius / 3) * area.
        let holeRadius = 3.0
        let wall = try #require(faces.first { $0.volumeInertia.volume < 0 })
        #expect(
            abs(wall.volumeInertia.volume + holeRadius / 3.0 * wall.area()) < 1e-9,
            "wall contributed \(wall.volumeInertia.volume) against area \(wall.area())")
    }

    /// #2806, the second construction: a curved trimmed face, where the natural UV bounds of the
    /// **planar cap** were the square that bounds the circle.
    ///
    /// A cylinder's top cap is a disc trimmed out of a plane whose UV bounds are the 10 x 10 square
    /// around it, so the unfixed sum came to 856.932108931632 against 785.3981633974482, over by the
    /// square-minus-disc corner at height 10. The lateral face is periodic and fully covered by its
    /// own bounds, which is why one fixture does not cover the other.
    @Test("a cylinder's faces sum to its volume (#2806)")
    func cylinderFaceContributionsSumToVolume() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let volume = try #require(cyl.volume)
        let sum = cyl.faces().reduce(0.0) { $0 + $1.volumeInertia.volume }
        #expect(abs(sum - volume) < 1e-9, "per-face sum was \(sum) against Shape.volume \(volume)")
    }

    /// A zero contribution stays a real answer: a face whose own plane contains the reference point
    /// contributes nothing, and #2806 must not have turned that into a measurement of the trim.
    @Test("a face through the origin still contributes 0 (#2806)")
    func coplanarFaceContributesZero() throws {
        let shifted = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(0, 0, 5)))
        let coplanar = try #require(shifted.faces().first { $0.volumeInertia.volume == 0 })
        #expect(coplanar.volumeInertia.centerOfMass == nil)
        let sum = shifted.faces().reduce(0.0) { $0 + $1.volumeInertia.volume }
        #expect(abs(sum - 1000.0) < 1e-9, "per-face sum was \(sum)")
    }

    /// #2827: the by-plane overload's mass is always exactly 0, in the kernel, and this test exists
    /// to fail when that stops being true.
    ///
    /// `BRepGProp_Gauss::convert` computes the mass and then overwrites it with `0.0` unless its
    /// `theIsByPoint` flag is set (`BRepGProp_Gauss.cxx:494-528`), which no by-plane path sets. So
    /// the bridge's `BRepGProp_Domain` (added by #2806 for the same reason as the by-point
    /// overload's) changes no value today, and the only thing a test can assert is the zero. If a
    /// repin makes this fail, the kernel has been fixed: replace the assertions with real values,
    /// close #2827 and drop the warning from `Face.volumeInertia(planeNormal:planeDistance:)` and
    /// from `docs/reference/Shape-HLR-Geom.md`.
    @Test("the by-plane overload reports 0 on this kernel (#2827)")
    func byPlaneOverloadIsZeroOnThisKernel() throws {
        let holed = try holedPlate()
        let oblique = simd_normalize(SIMD3(1.0, 2.0, 3.0))
        for face in holed.faces() {
            // A plane through the origin, one nowhere near the shape, and one at an angle to it.
            #expect(face.volumeInertia(planeNormal: SIMD3(0, 0, 1)).volume == 0.0)
            #expect(
                face.volumeInertia(planeNormal: SIMD3(0, 0, 1), planeDistance: -100).volume == 0.0)
            #expect(face.volumeInertia(planeNormal: oblique, planeDistance: 7).volume == 0.0)
            #expect(face.volumeInertia(planeNormal: SIMD3(0, 0, 1)).centerOfMass == nil)
        }
        // The by-point overload on the same faces is a measurement, so the zero above is the
        // kernel's by-plane path and not a broken fixture.
        let sum = holed.faces().reduce(0.0) { $0 + $1.volumeInertia.volume }
        #expect(abs(sum - (try #require(holed.volume))) < 1e-9)
    }

    /// #2806: `BRepGProp_VinertGK` had the same missing domain, and a null domain pointer means
    /// something different inside it: `PrivatePerform` treats it as "there is only one curve to
    /// treat, the U isoline at UMax" (`BRepGProp_VinertGK.cxx:271-276`). The unfixed sum was
    /// 762.3008881569224, the same overshoot by the same hole.
    @Test("vinertGK sums to the volume on a trimmed face (#2806)")
    func vinertGKContributionsSumToVolume() throws {
        let holed = try holedPlate()
        let volume = try #require(holed.volume)
        var sum = 0.0
        for face in holed.faces() {
            let asShape = try #require(Shape.fromFace(face))
            let r = asShape.vinertGK(tolerance: 1e-6)
            #expect(r.errorReached >= 0, "vinertGK failed with errorReached \(r.errorReached)")
            sum += r.mass
        }
        #expect(abs(sum - volume) < 1e-9, "vinertGK sum was \(sum) against Shape.volume \(volume)")
    }
}

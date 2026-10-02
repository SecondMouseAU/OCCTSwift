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

    /// #2827: the by-plane overload's per-face sum is the solid's volume, for **any** reference
    /// plane, and this is the identity rather than the number that is asserted.
    ///
    /// Until `0043` the by-plane mass was always exactly `0.0`: `BRepGProp_Gauss::convert` computed
    /// it and then overwrote it, because it kept the value only when its `theIsByPoint` flag was set
    /// and no by-plane path sets it (`BRepGProp_Gauss.cxx:494-528`). The patch is pinned from
    /// `v4.0.0-kernel.3`, so these three assertions all read `0.0` against an older asset.
    ///
    /// **Why a sum and not a literal.** The integrand is `(n . nFace) * d1 * dS` with `d1` affine in
    /// the point and gradient `n` (`BRepGProp_Gauss.cxx:340-348`), so `F = d1 * n` has `div F = 1`
    /// and the per-face total over a closed shell is the enclosed volume whatever plane was passed.
    /// `Shape.volume` is `BRepGProp::VolumeProperties`, a different loop that never reaches this
    /// function, so this is a comparison against an independent construction. One face's value, by
    /// contrast, is a column volume that moves with the plane: the plate's cap answers
    /// 371.7256661176918 through the origin and 101 times that at `planeDistance: -100`, its
    /// centroid being 1 from the origin, which is why pinning either would say nothing about
    /// whether the kernel is right.
    ///
    /// The tolerance is looser than the by-point test's 1e-9 for a measured reason: at
    /// `planeDistance: -100` each cap's term is around 3.7e4 and they cancel down to 7.4e2, so five
    /// significant digits are lost to the cancellation before any of them is wrong.
    @Test("the by-plane per-face sum is the volume, for any plane (#2827)")
    func byPlaneFaceSumIsTheVolumeForAnyPlane() throws {
        let oblique = simd_normalize(SIMD3(1.0, 2.0, 3.0))
        for shape in [try holedPlate(), try #require(Shape.cylinder(radius: 5, height: 10))] {
            let volume = try #require(shape.volume)
            // A plane through the origin, one nowhere near the shape, and one at an angle to it.
            for (normal, distance) in [
                (SIMD3(0.0, 0.0, 1.0), 0.0), (SIMD3(0.0, 0.0, 1.0), -100.0), (oblique, 7.0),
            ] {
                let sum = shape.faces().reduce(0.0) {
                    $0 + $1.volumeInertia(planeNormal: normal, planeDistance: distance).volume
                }
                #expect(
                    abs(sum - volume) < 1e-6,
                    "sum was \(sum) against Shape.volume \(volume), plane \(normal) at \(distance)")
                #expect(sum != 0.0, "every face answered 0: this kernel lacks patch 0043 (#2827)")
            }
        }
    }

    /// #2827, the second identity: the mass-weighted sum of the per-face by-plane centres is the
    /// solid's own first moment, again for any plane.
    ///
    /// `F_x = (x * d1 - nx * d1 * d1 / 2) * n` has `div F_x = x`, and that bracket is exactly the
    /// `Ix` integrand at `BRepGProp_Gauss.cxx:350`, so each face's centre is its column's centroid
    /// and the weighted total is `volume * centreOfMass`. This is what makes `centerOfMass` a
    /// measurement rather than merely non-nil: before `0043` the same `else` that zeroed the mass set
    /// the kernel's gravity centre to `(0, 0, 0)`, which `FaceVolumeInertia` reports as `nil`.
    ///
    /// The fixture is translated off the origin on purpose. `Shape.box` is centred, so on the
    /// untranslated plate the first moment is `(0, 0, 0)` and an implementation that returned
    /// nothing at all would pass.
    @Test("the by-plane first moments sum to the solid's (#2827)")
    func byPlaneFirstMomentIsTheSolidsFirstMoment() throws {
        let shifted = try #require(try holedPlate().translated(by: SIMD3(7, -3, 2)))
        let volume = try #require(shifted.volume)
        let centre = try #require(shifted.centerOfMass)
        let expected = centre * volume
        #expect(
            abs(expected.x) > 1.0 && abs(expected.y) > 1.0 && abs(expected.z) > 1.0,
            "first moment \(expected) has a zero component, so the fixture is not off-origin")

        let oblique = simd_normalize(SIMD3(1.0, 2.0, 3.0))
        for (normal, distance) in [
            (SIMD3(0.0, 0.0, 1.0), 0.0), (SIMD3(0.0, 0.0, 1.0), -100.0), (oblique, 7.0),
        ] {
            var moment = SIMD3(0.0, 0.0, 0.0)
            var measured = 0
            for face in shifted.faces() {
                let r = face.volumeInertia(planeNormal: normal, planeDistance: distance)
                // nil is the right answer for a zero column, and 0 * anything adds nothing.
                if let c = r.centerOfMass {
                    moment += c * r.volume
                    measured += 1
                } else {
                    #expect(r.volume == 0.0, "a nil centre with volume \(r.volume)")
                }
            }
            #expect(measured > 0, "no face had a centre: this kernel lacks patch 0043 (#2827)")
            #expect(
                abs(moment.x - expected.x) < 1e-5 && abs(moment.y - expected.y) < 1e-5
                    && abs(moment.z - expected.z) < 1e-5,
                "first moment was \(moment) against \(expected), plane \(normal) at \(distance)")
        }
    }

    /// #2827, per face rather than summed: on a **planar** face the integral has a closed form, and
    /// every quantity in it is measured somewhere else.
    ///
    /// `volume` is `(n . nFace) * area * (n . areaCentroid - planeDistance)`, so it is affine in
    /// `planeDistance` with slope **minus** the face's signed projected area. The slope is measured
    /// from two offsets, `area` comes from `Face.area()` and `areaCentroid` from `surfaceInertia`,
    /// which is `BRepGProp_Sinert` and a different computation, so nothing here is a value this test
    /// invented.
    ///
    /// The minus is #2873, and it is why this is written as a formula rather than as pinned numbers.
    /// The kernel weights each element by `n . P` minus the plane's fourth `gp_Pln` coefficient,
    /// which belongs to the `n . X + d = 0` form and so arrives inverted, and
    /// `OCCTBRepGPropVinertPlane` used to hand it the plane mirrored through the origin to undo
    /// that. Carried patch `0048` fixes the conversion at all five sites and the repin that pinned
    /// it deleted the mirror (#3015), so the bridge now passes the plane the caller named. This
    /// test stood here with a `+` against the old mirrored convention; written as it is, it fails
    /// against that convention and it fails again on a kernel with the fix and the mirror still in
    /// place, which is exactly what it caught on PR #3014 before the repin.
    @Test(
        "a planar face's by-plane volume is its projected area times its centroid distance (#2827)")
    func byPlaneVolumeOnAPlanarFaceHasTheClosedForm() throws {
        let holed = try holedPlate()
        let normal = SIMD3(0.0, 0.0, 1.0)
        var caps = 0
        var flats = 0
        for face in holed.faces() {
            let at0 = face.volumeInertia(planeNormal: normal, planeDistance: 0).volume
            let at1 = face.volumeInertia(planeNormal: normal, planeDistance: 1).volume
            // The slope is minus the signed projected area, so the area itself is at0 - at1.
            let projectedArea = at0 - at1
            guard let centroid = face.surfaceInertia.centerOfMass else { continue }

            // On this fixture that is +-area for the two caps and 0 for the four sides and the
            // hole's wall, all of which are parallel to z.
            let area = face.area()
            if abs(projectedArea) > 1e-9 {
                caps += 1
                #expect(
                    abs(abs(projectedArea) - area) < 1e-9,
                    "slope \(projectedArea) against area \(area): not a projected area")
            } else {
                flats += 1
            }

            // And the value itself, at three offsets, from the projected area and the face's own
            // centroid. Passing the offset with the wrong sign moves every cap term by twice the
            // offset's contribution, so these three cases are what separate the two conventions.
            for distance in [0.0, 1.0, -100.0] {
                let measured = face.volumeInertia(
                    planeNormal: normal, planeDistance: distance
                ).volume
                let predicted = projectedArea * (simd_dot(normal, centroid) - distance)
                #expect(
                    abs(measured - predicted) < 1e-9 * max(1.0, abs(predicted)),
                    "face measured \(measured), closed form \(predicted), at offset \(distance)")
            }
        }
        #expect(caps == 2, "found \(caps) faces square to z, expected the plate's 2 caps")
        #expect(flats == 5, "found \(flats) faces parallel to z, expected 5")
    }

    /// #2873: the two assertions that separate the plane the caller named from its mirror through
    /// the origin, neither of which needs the closed form above.
    ///
    /// Both of OCCT's by-plane implementations weight each element by `n . P` minus the plane's
    /// fourth `gp_Pln` coefficient (`BRepGProp_Gauss.cxx:343` for `BRepGProp_Vinert`,
    /// `BRepGProp_UFunction.cxx:99` for `BRepGProp_VinertGK`), and the conversion that fills that
    /// coefficient takes it from `gp_Pln::Coefficients`, which answers the `n . X + d = 0` form. So
    /// the offset arrives inverted. `OCCTBRepGPropVinertPlane` builds the `gp_Pln` itself, from
    /// `planeNormal` and `planeDistance`, so it builds the mirrored one and `planeDistance` behaves
    /// as a geometric offset. Measured first, in `Scripts/repro/2873/`.
    ///
    /// **A test that passes under both conventions is worthless here**, which is why the fixture is
    /// translated: with the plate as built, the caps sit at z = +-1 and every assertion below has a
    /// mirror-symmetric twin. Shifted to z = 4 and 6, the plane at `+h` and the plane at `-h` are
    /// 8 or 12 apart.
    @Test("the by-plane column runs to the plane the caller named, not its mirror (#2873)")
    func byPlaneColumnRunsToTheNamedPlane() throws {
        let holed = try #require(try holedPlate().translated(by: SIMD3(0, 0, 5)))
        let normal = SIMD3(0.0, 0.0, 1.0)
        var caps = 0
        for face in holed.faces() where face.area() > 300 {
            caps += 1
            let centroid = try #require(face.surfaceInertia.centerOfMass)
            let height = simd_dot(normal, centroid)
            let area = face.area()
            #expect(abs(height) > 1.0, "cap at \(centroid) is too near the origin to discriminate")

            // 1. The plane a cap lies in leaves no column between them. Under the mirrored
            //    convention that happens at -height, and at +height the answer is the full
            //    2 * height * area instead.
            let atOwnPlane = face.volumeInertia(planeNormal: normal, planeDistance: height).volume
            #expect(
                abs(atOwnPlane) < 1e-9 * area,
                "column to the cap's own plane at \(height) was \(atOwnPlane)")
            let atMirror = face.volumeInertia(planeNormal: normal, planeDistance: -height).volume
            let expectedMirror = 2 * abs(height) * area
            #expect(
                abs(abs(atMirror) - expectedMirror) < 1e-6 * expectedMirror,
                "column to the mirrored plane was \(atMirror), expected +-\(expectedMirror)")

            // 2. The column's centroid is the midpoint between the cap and the plane, which fixes
            //    the sign a second way and uses neither the area nor the face's orientation.
            for distance in [0.0, 1.0, -3.0] {
                let r = face.volumeInertia(planeNormal: normal, planeDistance: distance)
                #expect(r.volume != 0.0, "no column at offset \(distance), so no centre to check")
                let centre = try #require(r.centerOfMass)
                let midpoint = (height + distance) / 2
                let seen = "centre \(centre) against midpoint \(midpoint)"
                #expect(
                    abs(centre.z - midpoint) < 1e-9,
                    "\(seen), cap at \(height), plane at \(distance)")
            }
        }
        #expect(caps == 2, "found \(caps) faces over 300 in area, expected the plate's 2 caps")
    }

    /// `BRepGProp_VinertGK` sums to the volume once its domain is supplied (#2806).
    ///
    /// It had the same missing domain, and a null domain pointer means
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

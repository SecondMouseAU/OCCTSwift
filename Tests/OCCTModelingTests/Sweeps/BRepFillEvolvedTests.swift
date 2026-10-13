import Foundation
import Testing

@testable import OCCTSwift

#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

@Suite("BRepFill_Evolved")
struct BRepFillEvolvedTests {
    // The old fixture (an L-shaped open profile, x 0 to 5 and z 0 to 5, on a 100 x 100 spine
    // face) returns nil for every evolved entry point (#3368): the profile is projected onto the
    // YOZ plane of the frame, and an L drawn in the XZ plane projects onto the Z axis, where it
    // has no lateral extent (the placement rule is in `EvolvedAdvancedTests`), and the test
    // ran `#expect(true)` over it. A vertical 5 mm segment on the spine is four 100 x 5 walls:
    // area 2000, and with `makeSolid` the 100 x 100 x 5 slab, volume 50000 (the same figures
    // as the 20 x 20 x 3 case in the probe, 240 and 1200, measured on kernel.6).
    @Test("evolved shape from face spine + wire profile")
    func evolvedShape() throws {
        let rect = try #require(Wire.rectangle(width: 100, height: 100))
        let spineFace = try #require(Shape.face(from: rect))
        let profileWire = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 5)], closed: false))
        let profile = try #require(Shape.fromWire(profileWire))

        let walls = try #require(Shape.evolved(spineFace: spineFace, profileWire: profile))
        #expect(walls.isValid)
        #expect(walls.faces().count == 4)
        #expect(abs((walls.surfaceArea ?? -1) - 2000.0) < 1e-6)
        let wallBounds = try #require(walls.boundingBox)
        #expect(abs(wallBounds.min.z) < 1e-5 && abs(wallBounds.max.z - 5.0) < 1e-5)
        #expect(abs(wallBounds.max.x - 50.0) < 1e-5)

        let slab = try #require(
            Shape.evolved(spineFace: spineFace, profileWire: profile, makeSolid: true))
        #expect(slab.isValid)
        #expect(slab.shapeType == .solid)
        #expect(abs((slab.volume ?? -1) - 50000.0) < 1e-6)
    }

    // The frame the caller passes is used as given, and a NaN, zero or infinite one builds a NaN
    // `gp_Ax3` that sends `BRepFill_Evolved::PrepareProfile` into `Geom_TrimmedCurve::SetTrim`
    // forever (#3368). The refusals are checked first; the control builds.
    @Test("A non-finite or zero axis is refused rather than never returning", hangLimit)
    func nonFiniteAxisIsRefused() throws {
        let rect = try #require(Wire.rectangle(width: 20, height: 20))
        let spineFace = try #require(Shape.face(from: rect))
        let profileWire = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 0, 3)], closed: false))
        let profile = try #require(Shape.fromWire(profileWire))

        let control = try #require(Shape.evolved(spineFace: spineFace, profileWire: profile))
        #expect(abs((control.surfaceArea ?? -1) - 240.0) < 1e-6)

        let nan = Double.nan
        #expect(
            Shape.evolved(
                spineFace: spineFace, profileWire: profile, axisNormal: SIMD3(nan, 0, 1)) == nil)
        #expect(
            Shape.evolved(
                spineFace: spineFace, profileWire: profile, axisXDir: SIMD3(1, nan, 0)) == nil)
        #expect(
            Shape.evolved(
                spineFace: spineFace, profileWire: profile, axisOrigin: SIMD3(nan, 0, 0)) == nil)
        #expect(
            Shape.evolved(
                spineFace: spineFace, profileWire: profile, axisNormal: SIMD3(0, 0, 0)) == nil)
        #expect(
            Shape.evolved(
                spineFace: spineFace, profileWire: profile,
                axisNormal: SIMD3(.infinity, 0, 1)) == nil)
    }

    // A profile at or past the spine's inradius offsets it to nothing: OCCT is done with an empty
    // compound that has no face, or fails outright. Refused either way, never an empty shape
    // (#3368). 9 from the 10 inradius is the control: a 2 x 2 square, four 2 x 3 walls.
    @Test("A profile offsetting the spine to nothing is refused")
    func collapsedOffsetIsRefused() throws {
        let rect = try #require(Wire.rectangle(width: 20, height: 20))
        let spineFace = try #require(Shape.face(from: rect))

        func profile(_ lateral: Double) throws -> Wire {
            try #require(
                Wire.polygon3D([SIMD3(0, lateral, 0), SIMD3(0, lateral, 3)], closed: false))
        }

        let near = try #require(Shape.evolved(spine: rect, profile: try profile(9)))
        #expect(near.faces().count == 4)
        #expect(abs((near.surfaceArea ?? -1) - 24.0) < 1e-6)

        for lateral in [10.0, 12.0] {
            let wire = try profile(lateral)
            #expect(Shape.evolved(spine: rect, profile: wire) == nil, "wire spine, \(lateral)")
            let shape = try #require(Shape.fromWire(wire))
            #expect(
                Shape.evolved(spineFace: spineFace, profileWire: shape) == nil,
                "face spine, \(lateral)")
        }
    }
}

import Testing

@testable import OCCTSwift

@Suite("Sweep Tests")
struct SweepTests {

    @Test("Extrude profile")
    func extrudeProfile() throws {
        let profile = try #require(Wire.rectangle(width: 5, height: 3))
        let solid = try #require(
            Shape.extrude(
                profile: profile,
                direction: SIMD3(0, 0, 1),
                length: 10
            ))
        #expect(solid.isValid)
        // 5 x 3 x 10: volume 150, area 2 * (15 + 50 + 30) = 190, six faces, z from 0 to 10.
        #expect(solid.shapeType == .solid)
        #expect(abs((solid.volume ?? -1) - 150.0) < 1e-6)
        #expect(abs((solid.surfaceArea ?? -1) - 190.0) < 1e-6)
        #expect(solid.faces().count == 6)
        let bounds = try #require(solid.boundingBox)
        #expect(abs(bounds.min.z) < 1e-5 && abs(bounds.max.z - 10.0) < 1e-5)
    }

    // The old fixture put the circle at the origin in the XY plane, while the arc starts at
    // (50, 0, 0) heading +y in the same plane, so the profile contained the path tangent and
    // was not at the path: the sweep is a flat disc of area 1e-16 (measured) that `isValid`
    // accepted. The profile has to sit at the start of the path with its normal along the
    // tangent, here the circle of radius 1 centred (50, 0, 0) with normal +y. A pipe of
    // radius 1 along a quarter of an r = 50 arc has lateral area (Pappus) 2 pi * 1 * 50 pi / 2.
    @Test("Pipe sweep")
    func pipeSweep() throws {
        let profile = try #require(
            Wire.circle(origin: SIMD3(50, 0, 0), normal: SIMD3(0, 1, 0), radius: 1))
        let path = try #require(
            Wire.arc(
                center: .zero,
                radius: 50,
                startAngle: 0,
                endAngle: .pi / 2
            ))
        let pipe = try #require(Shape.sweep(profile: profile, along: path))
        #expect(pipe.isValid)
        let expectedArea = 2.0 * Double.pi * 1.0 * 50.0 * Double.pi / 2.0
        #expect(abs((pipe.surfaceArea ?? -1) - expectedArea) < 1e-3)
        // It follows the quarter arc: x and y reach 51 at the far ends of the swept tube and the
        // tube stays 1 mm either side of z = 0. The default box is the control-point hull (55.2
        // here), so the tight one is used.
        let bounds = try #require(pipe.boundingBoxOptimal())
        #expect(abs(bounds.max.x - 51.0) < 1e-3 && abs(bounds.max.y - 51.0) < 1e-3)
        #expect(abs(bounds.min.z + 1.0) < 1e-3 && abs(bounds.max.z - 1.0) < 1e-3)
        #expect(abs(bounds.min.x) < 1e-3 && abs(bounds.min.y) < 1e-3)
    }

    @Test("Revolution")
    func revolution() throws {
        // Create a simple profile to revolve
        let profile = try #require(
            Wire.polygon(
                [
                    SIMD2(5, 0),
                    SIMD2(7, 0),
                    SIMD2(7, 10),
                    SIMD2(5, 10),
                ], closed: true))

        let solid = try #require(
            Shape.revolve(
                profile: profile,
                axisOrigin: .zero,
                axisDirection: SIMD3(0, 1, 0),
                angle: .pi * 2
            ))
        #expect(solid.isValid)
        // A tube of outer radius 7, inner 5 and height 10 about the y axis: four faces (outer,
        // inner, two annular caps), volume pi * (49 - 25) * 10, surface 2 pi * (7 + 5) * 10 +
        // 2 pi * (49 - 25) = 904.7786...
        #expect(solid.faces().count == 4)
        #expect(abs((solid.volume ?? -1) - Double.pi * 24.0 * 10.0) < 1e-6)
        let area = 2.0 * Double.pi * 12.0 * 10.0 + 2.0 * Double.pi * 24.0
        #expect(abs((solid.surfaceArea ?? -1) - area) < 1e-6)
        let bounds = try #require(solid.boundingBox)
        #expect(abs(bounds.max.x - 7.0) < 1e-5 && abs(bounds.min.x + 7.0) < 1e-5)
        #expect(abs(bounds.min.y) < 1e-5 && abs(bounds.max.y - 10.0) < 1e-5)
    }

    // Issue #170: a pipe sweep must yield a positive-volume (outward-oriented)
    // solid regardless of the section wire's sense relative to the path tangent.
    @Test("Pipe sweep along helix is forward-oriented")
    func pipeSweepHelixPositiveVolume() {
        guard let section = Wire.circle(radius: 1.5) else {
            Issue.record("Failed to create section")
            return
        }
        guard let helix = Wire.helix(radius: 8, pitch: 6, turns: 3) else {
            Issue.record("Failed to create helix")
            return
        }
        guard let spring = Shape.sweep(profile: section, along: helix) else {
            Issue.record("Failed to sweep spring")
            return
        }
        #expect(spring.isValid)
        // The whole point of the fix: signed volume comes out positive.
        //
        // A pipe sweep is an OPEN shell (three faces, no solid), so `signedVolume` here is the
        // divergence integral rather than a volume, and `volume` is nil. The sign is still the
        // orientation signal this test cares about, since reversing a surface negates the flux.
        // The old `volume != nil` assertion passed only because the volume path used to answer for
        // an open surface too. See #609.
        #expect(spring.solidCount == 0, "a pipe sweep is a shell")
        #expect(spring.signedVolume > 0)
        #expect(spring.volume == nil, "an open shell has no volume to measure")
    }

    // Issue #170: orientedForward() flips a reversed solid; leaves a good one.
    @Test("orientedForward normalises a reversed solid")
    func orientedForwardNormalises() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.signedVolume > 0)

        guard let reversed = box.reversed else {
            Issue.record("Failed to reverse box")
            return
        }
        #expect(reversed.signedVolume < 0)

        guard let fixed = reversed.orientedForward() else {
            Issue.record("orientedForward returned nil")
            return
        }
        #expect(fixed.signedVolume > 0)
        // An already-forward solid is returned essentially unchanged.
        guard let stillGood = box.orientedForward() else {
            Issue.record("orientedForward(forward) returned nil")
            return
        }
        #expect(stillGood.signedVolume > 0)
    }
}

import Testing
import simd

@testable import OCCTSwift

@Suite("Sweep Tests")
struct SweepTests {

    @Test("Extrude profile")
    func extrudeProfile() {
        guard let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Failed to create rectangle profile")
            return
        }
        let solid = Shape.extrude(
            profile: profile,
            direction: SIMD3(0, 0, 1),
            length: 10
        )!
        #expect(solid.isValid)
    }

    @Test("Pipe sweep")
    func pipeSweep() {
        guard let profile = Wire.circle(radius: 1) else {
            Issue.record("Failed to create circle profile")
            return
        }
        guard
            let path = Wire.arc(
                center: .zero,
                radius: 50,
                startAngle: 0,
                endAngle: .pi / 2
            )
        else {
            Issue.record("Failed to create arc path")
            return
        }
        let pipe = Shape.sweep(profile: profile, along: path)!
        #expect(pipe.isValid)
    }

    @Test("Revolution")
    func revolution() {
        // Create a simple profile to revolve
        guard
            let profile = Wire.polygon(
                [
                    SIMD2(5, 0),
                    SIMD2(7, 0),
                    SIMD2(7, 10),
                    SIMD2(5, 10),
                ], closed: true)
        else {
            Issue.record("Failed to create polygon profile")
            return
        }

        let solid = Shape.revolve(
            profile: profile,
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 1, 0),
            angle: .pi * 2
        )!
        #expect(solid.isValid)
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
    func orientedForwardNormalises() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
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

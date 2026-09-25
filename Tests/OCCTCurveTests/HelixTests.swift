import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.28.0 New Features

// Pinned to HelixBRep_BuilderHelix on the same parameters, read back through
// BRepAdaptor_CompCurve (Scripts/repro/766-curve-helix/transcript.txt). The earlier versions
// checked only `!= nil`, and helixSweep force-unwrapped inside #expect, so a helix of the wrong
// radius, pitch or turn count passed (#766). The rise is checked as |dz| because the kernel's
// counterclockwise helix descends along its axis (see the finding in the PR).
@Suite("Helix Curves")
struct HelixTests {
    private static func check(_ helix: Wire?, radius: Double, rise: Double, length: Double) {
        guard let helix, let a = helix.point(at: 0), let b = helix.point(at: 1) else {
            Issue.record("helix not built")
            return
        }
        #expect(abs(simd_length(SIMD2(a.x, a.y)) - radius) < 1e-9)
        #expect(abs(abs(b.z - a.z) - rise) < 1e-9)
        #expect(abs((helix.length ?? 0) - length) < 1e-6)
    }

    @Test("Create basic helix")
    func basicHelix() {
        Self.check(Wire.helix(radius: 5, pitch: 2, turns: 3), radius: 5, rise: 6,
                   length: 94.438520381886207)
    }

    @Test("Helix with custom origin and axis")
    func helixCustomAxis() {
        guard
            let helix = Wire.helix(
                origin: SIMD3(10, 20, 30),
                axis: SIMD3(0, 0, 1),
                radius: 10,
                pitch: 5,
                turns: 2
            ),
            let a = helix.point(at: 0), let b = helix.point(at: 1)
        else {
            Issue.record("helix not built")
            return
        }
        #expect(simd_distance(a, SIMD3(0, 20, 30)) < 1e-9)
        #expect(abs(abs(b.z - a.z) - 10) < 1e-9)
        #expect(abs((helix.length ?? 0) - 126.06094379666393) < 1e-6)
    }

    @Test("Helix clockwise vs counter-clockwise")
    func helixDirection() {
        guard let ccw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: false),
            let cw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: true),
            let a = ccw.point(at: 0), let b = cw.point(at: 0),
            let ae = ccw.point(at: 1), let be = cw.point(at: 1)
        else {
            Issue.record("helices not built")
            return
        }
        // The two senses start on opposite sides and climb in opposite axis directions.
        #expect(simd_distance(a, SIMD3(-5, 0, 0)) < 1e-9)
        #expect(simd_distance(b, SIMD3(5, 0, 0)) < 1e-9)
        #expect(abs(ae.z - (-2)) < 1e-9)
        #expect(abs(be.z - 2) < 1e-9)
    }

    @Test("Invalid helix parameters return nil")
    func invalidHelix() {
        #expect(Wire.helix(radius: 0, pitch: 2, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 0, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 2, turns: 0) == nil)
        #expect(Wire.helix(radius: -1, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix can be used as sweep path")
    func helixSweep() {
        guard let helix = Wire.helix(radius: 10, pitch: 5, turns: 3),
            let profile = Wire.circle(radius: 0.5)
        else {
            Issue.record("helix or profile not built")
            return
        }
        #expect(abs((helix.length ?? 0) - 189.09141569499593) < 1e-6)
        guard let spring = Shape.sweep(profile: profile, along: helix) else {
            Issue.record("sweep failed")
            return
        }
        #expect(spring.isValid)
    }

    @Test("Create tapered helix")
    func taperedHelix() {
        guard
            let helix = Wire.helixTapered(
                startRadius: 10,
                endRadius: 3,
                pitch: 4,
                turns: 4
            ),
            let a = helix.point(at: 0), let b = helix.point(at: 1)
        else {
            Issue.record("tapered helix not built")
            return
        }
        #expect(abs(simd_length(SIMD2(a.x, a.y)) - 10) < 1e-9)
        #expect(abs(simd_length(SIMD2(b.x, b.y)) - 3) < 1e-9)
        #expect(abs(abs(b.z - a.z) - 16) < 1e-9)
    }

    @Test("Invalid tapered helix returns nil")
    func invalidTaperedHelix() {
        #expect(Wire.helixTapered(startRadius: 0, endRadius: 5, pitch: 2, turns: 1) == nil)
        #expect(Wire.helixTapered(startRadius: 5, endRadius: 0, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix with fractional turns")
    func fractionalTurns() {
        Self.check(Wire.helix(radius: 5, pitch: 10, turns: 0.5), radius: 5, rise: 5,
                   length: 16.484533267150862)
    }

    @Test("Helix with many turns")
    func manyTurns() {
        Self.check(Wire.helix(radius: 5, pitch: 1, turns: 20), radius: 5, rise: 20,
                   length: 628.63641255844379)
    }
}

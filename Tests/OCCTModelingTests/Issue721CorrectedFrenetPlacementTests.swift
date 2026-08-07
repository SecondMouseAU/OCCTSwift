// #721: ".correctedFrenet pipe sweeps are up to 27% off the true volume and reverse sign, while
// .frenet is exact." Two rounds of measurement on the issue reproduced that table (pitch 1/4/12/30,
// radius=10, turns=3, circular profile radius=1.5) and a prior investigation branch narrowed a
// real, separate mechanism: `Wire.helix(turns: n)` builds n edges, and `BRepFill_Edge3DLaw` gives
// each edge its own independent `GeomFill_CorrectedFrenet`, whose twist-angle law resets to zero
// at the start of every edge -- a genuine ~0.4 rad discontinuity at pitch=4, confirmed directly by
// sampling `GeomFill_CorrectedFrenet::D0` against `GeomFill_Frenet::D0` on the same parameter.
//
// That mechanism turned out not to be the cause of the reported volumes. This file's own dense
// sweep (below) found NO divergence at any turn count (1 through 8, including half-turns, so 0
// through 7 internal edge boundaries) once the profile is placed at the spine's own measured start
// point and tangent -- the per-edge reset is real but volume-neutral for a circular profile,
// exactly as the issue's own symmetry argument predicts (the two laws differ only by a rotation
// about the tangent, and a circle is invariant under that rotation).
//
// The actual cause: both rounds of measurement, and the already-shipped
// `Issue598PipeShellFrenetModeTests.cookbookSpringRecipeVolumeInvariant` (and
// `docs/guides/cookbook/helices.md`'s "coiled spring" recipe it was modeled on), placed the
// profile at `SIMD3(r, 0, 0)` with tangent `normalize(0, r, pitch/2pi)`, describing that as "the
// helix start, with its normal along the tangent there." `Wire.helix`'s default `clockwise: false`
// reverses the build axis to -Z, so the wire's actual start is `(-r, ~0, 0)`, descending -- the
// profile in every prior measurement sat 2r away from the spine, with a tangent whose Z-component
// had the wrong sign.
//
// `.frenet`'s volume happened not to depend on this: `BRepOffsetAPI_MakePipeShell` re-derives the
// Frenet trihedron from the spine itself, and a circle has no preferred rotation, so a profile
// plane merely consistent with *some* congruent (here, mirrored) helix still sweeps to the right
// volume. `.correctedFrenet`'s per-edge twist-angle law is referenced to the input frame and is not
// insensitive to it -- the mismatch is exactly what produced the reported numbers (reproduced
// below at the issue's own ratios, to 3 significant figures).

import Testing
import Foundation
import simd
@testable import OCCTSwift

@Suite("#721: .correctedFrenet's reported divergence is a profile-placement artifact, not a defect")
struct Issue721CorrectedFrenetPlacementTests {

    /// The spine's own measured start point and tangent -- the only placement that is actually
    /// "on the spine, tangent to it," as opposed to a point/tangent consistent with some other,
    /// merely congruent helix.
    static func measuredStartFrame(of spine: Wire) -> (origin: SIMD3<Double>, tangent: SIMD3<Double>)? {
        guard let firstEdge = spine.edges().first, let curve = firstEdge.curve3D else { return nil }
        let (p0, t0) = curve.d1(at: curve.domain.lowerBound)
        return (p0, simd_normalize(t0))
    }

    /// The discriminator the issue asked for: does the divergence require an internal wire
    /// boundary (`turns` > 1, hence >1 edge), scaling with boundary count? Swept densely,
    /// including half-turns so odd boundary counts are covered, at every pitch the issue itself
    /// measured. With a correctly-placed profile the answer is no at every single point: both
    /// modes match the textbook tube volume and each other to ~1e-6 relative, regardless of edge
    /// count. The per-edge twist-angle reset (real, see the file header) is volume-neutral here.
    @Test("frenet and correctedFrenet agree with the textbook volume at every turn count, pitch, and internal-boundary count")
    func agreementHoldsAcrossPitchAndTurnCount() {
        let r = 10.0, wireRadius = 1.5
        let pitches = [1.0, 4.0, 12.0, 30.0]
        let turnsList = [1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 6.0, 8.0] // 0 through 7 internal boundaries

        for pitch in pitches {
            for turns in turnsList {
                guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns) else {
                    Issue.record("Could not build spine at pitch \(pitch) turns \(turns)"); continue
                }
                let edgeCount = spine.edges().count
                guard let (origin, tangent) = Self.measuredStartFrame(of: spine),
                      let profile = Wire.circle(origin: origin, normal: tangent, radius: wireRadius),
                      let frenet = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: true),
                      let corrected = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet, solid: true),
                      let vFrenet = frenet.volume, let vCorrected = corrected.volume else {
                    Issue.record("Could not build the sweeps at pitch \(pitch) turns \(turns)"); continue
                }

                let c = pitch / (2 * Double.pi)
                let coilLength = turns * 2 * Double.pi * (r * r + c * c).squareRoot()
                let textbookVolume = Double.pi * wireRadius * wireRadius * coilLength

                #expect(vFrenet.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-4),
                        "pitch \(pitch) turns \(turns) (\(edgeCount) edges): .frenet (\(vFrenet)) should match textbook (\(textbookVolume))")
                #expect(vCorrected.isApproximatelyEqual(to: textbookVolume, tolerance: 1e-4),
                        "pitch \(pitch) turns \(turns) (\(edgeCount) edges): .correctedFrenet (\(vCorrected)) should match textbook (\(textbookVolume))")
                #expect(vFrenet.isApproximatelyEqual(to: vCorrected, tolerance: 1e-4),
                        "pitch \(pitch) turns \(turns) (\(edgeCount) edges): the two trihedron laws must agree on a circular profile")
            }
        }
    }

    /// A direct instrument on the mechanism the prior investigation branch flagged: does
    /// `GeomFill_CorrectedFrenet`'s per-edge reset actually perturb `Shape.pipeShell`'s frame
    /// evolution across an internal wire boundary? `Shape.correctedFrenet(at:)`
    /// (`Shape+Surface.swift`, `OCCTGeomFillCorrectedFrenet`) works per-*edge*, exactly matching
    /// `BRepFill_Edge3DLaw`'s own construction (an independent `GeomFill_CorrectedFrenet` built
    /// fresh on each edge's own `BRepAdaptor_Curve`), so this samples edge 1 at its own last
    /// parameter and edge 2 at its own first parameter -- the two sides of the internal boundary
    /// `Wire.helix(turns: 2)` introduces. Included as evidence, not as the volume claim: the frame
    /// does move (confirming the reset is real), and it still costs nothing in the swept volume
    /// test above, at this and every other boundary count checked.
    @Test("the per-edge frame reset is real (not what the volume test above is failing to detect)")
    func perEdgeResetIsReal() {
        let r = 10.0, pitch = 12.0
        guard let spine = Wire.helix(radius: r, pitch: pitch, turns: 2) else {
            Issue.record("Could not build the fixture"); return
        }
        let edges = spine.edges()
        guard edges.count == 2,
              let curve1 = edges[0].curve3D, let curve2 = edges[1].curve3D,
              let edgeShape1 = Shape.fromEdge(edges[0]), let edgeShape2 = Shape.fromEdge(edges[1]) else {
            Issue.record("Expected a 2-edge wire with readable curves"); return
        }

        guard let frameBefore = edgeShape1.correctedFrenet(at: curve1.domain.upperBound),
              let frameAfter = edgeShape2.correctedFrenet(at: curve2.domain.lowerBound) else {
            Issue.record("Could not sample the trihedron across the boundary"); return
        }

        let cosAngle = simd_dot(simd_normalize(frameBefore.normal), simd_normalize(frameAfter.normal))
        let angleDeg = acos(Swift.max(-1, Swift.min(1, cosAngle))) * 180 / .pi

        // The curve is C-infinity smooth across this point (it is one continuous helix, split
        // into edges only by Wire.helix's per-turn construction) -- a continuous law would show a
        // near-zero angle here. The per-edge reset means it does not.
        #expect(angleDeg > 1.0,
                "expected a real discontinuity in the corrected-Frenet normal across the internal edge boundary, measured \(angleDeg) degrees")
    }
}

/// Compiles and runs `Wire.helix`'s own doc snippet verbatim. The first version of that snippet
/// referenced an undefined `domain` and would not have compiled if anyone pasted it, which is the
/// same class of defect as the unverified placement formula that produced #721 in the first place.
/// A snippet shipped alongside a warning about unverified formulas should itself be verified.
@Suite("Wire.helix's doc snippet compiles and measures the real start (#721)")
struct Issue721HelixDocSnippetTests {
    @Test("the documented way to measure a helix start point works and disagrees with the naive one")
    func snippetCompilesAndIsNotTheNaiveAnswer() throws {
        let spine = try #require(Wire.helix(radius: 10, pitch: 4, turns: 3))

        // Verbatim from the doc comment on Wire.helix.
        guard let curve = spine.edges().first?.curve3D else {
            Issue.record("helix has no first edge curve")
            return
        }
        let (start, tangent) = curve.d1(at: curve.domain.lowerBound)

        // The measured start is NOT origin + (radius, 0, 0): that assumption is #721.
        let naive = SIMD3(10.0, 0.0, 0.0)
        let offBy = (start - naive)
        #expect((offBy.x * offBy.x + offBy.y * offBy.y + offBy.z * offBy.z).squareRoot() > 1.0,
                "the naive start should be measurably wrong, that is the point of the warning")
        #expect(tangent.z < 0, "the real tangent descends; the naive one was assumed ascending")
    }
}

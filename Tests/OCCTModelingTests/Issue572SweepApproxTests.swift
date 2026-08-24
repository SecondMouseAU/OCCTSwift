import Testing
import simd

@testable import OCCTSwift

/// Issue #572: `PipeShellBuilder.setForceApproxC1(true)` is the only OCCTSwift lever that reaches
/// `GeomFill_Sweep.cxx:296`, where the swept surface is re-approximated at C1 through
/// `GeomConvert_ApproxSurface`, the class patch `0019` (#522) fixed.
///
/// It fires only when the swept surface is not already C1 across the spine, which needs the
/// spine's tangent discontinuity to sit *inside* one edge: `BRepFill_Sweep` splits the sweep at
/// spine vertices, so a polyline spine never reaches it.
@Suite("Issue 572: the forced-C1 sweep approximation")
struct Issue572SweepApproxTests {

    /// A single-edge spine with a C0 corner in the middle: degree 2 with an interior knot of
    /// multiplicity 2.
    static func cornerSpine() -> Shape? {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(0, 0, 4), SIMD3(0, 0, 8), SIMD3(4, 0, 11), SIMD3(9, 0, 13),
        ]
        guard
            let curve = Curve3D.bspline(
                poles: poles,
                knots: [0.0, 0.5, 1.0],
                multiplicities: [3, 2, 3],
                degree: 2)
        else { return nil }
        guard let edge = Shape.edgeFromCurve(curve) else { return nil }
        return Shape.wireFromEdges([edge])
    }

    static func build(forceApproxC1: Bool) -> Shape? {
        guard let spine = cornerSpine(),
            let profileWire = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 1),
            let profile = Shape.fromWire(profileWire),
            let builder = PipeShellBuilder(spine: spine)
        else { return nil }
        builder.setFrenet(true)
        builder.setForceApproxC1(forceApproxC1)
        builder.add(profile: profile)
        guard builder.build() else { return nil }
        return builder.shape
    }

    /// Largest distance from a grid of points on `truth` to the nearest point on `candidate`.
    static func deviation(from truth: Face, to candidate: Face, samples: Int = 20) -> Double? {
        guard let b = truth.uvBounds else { return nil }
        var worst = 0.0
        for i in 0...samples {
            for j in 0...samples {
                let u = b.uMin + (b.uMax - b.uMin) * Double(i) / Double(samples)
                let v = b.vMin + (b.vMax - b.vMin) * Double(j) / Double(samples)
                guard let p = truth.point(atU: u, v: v),
                    let proj = candidate.project(point: p)
                else { continue }
                worst = max(worst, proj.distance)
            }
        }
        return worst
    }

    @Test("The forced-C1 surface covers the surface it is approximating")
    func forcedC1CoversTheUnforcedSweep() {
        guard let plain = Self.build(forceApproxC1: false),
            let forced = Self.build(forceApproxC1: true)
        else {
            Issue.record("build")
            return
        }
        guard let plainFace = plain.faces().first(where: { $0.surfaceType == .bsplineSurface }),
            let forcedFace = forced.faces().first(where: { $0.surfaceType == .bsplineSurface })
        else {
            Issue.record("no bspline face")
            return
        }

        // GeomFill_Sweep asks for 1e-4 and accepts on HasResult() without reading MaxError(), so
        // neither kernel delivers that tolerance here. What 0019 changes is how close it gets:
        // the pre-0019 fit stopped at degree 13x4 / 14x8 poles and left the un-forced surface
        // 0.876 away, because every truncation error its degree search scored was zero. With 0019
        // the search runs to the 14x14 cap, 41x67 poles, and the gap is 0.176, i.e. 5x closer.
        guard let dev = Self.deviation(from: plainFace, to: forcedFace) else {
            Issue.record("deviation")
            return
        }
        #expect(dev < 0.25, "forced-C1 surface is \(dev) from the surface it approximates")
    }

    /// Without the flag the sweep keeps its own surface and never reaches the approximator, so
    /// this result is identical on both kernels. It is the reference the test above measures
    /// against, so a change to it would silently move that test's baseline.
    @Test("The un-forced sweep is untouched by the approximation fix")
    func unforcedSweepIsUnchanged() {
        guard let plain = Self.build(forceApproxC1: false) else {
            Issue.record("build")
            return
        }
        guard let face = plain.faces().first(where: { $0.surfaceType == .bsplineSurface }) else {
            Issue.record("no bspline face")
            return
        }
        #expect(plain.faceCount == 1)
        if let area = plain.surfaceArea {
            #expect(abs(area - 114.603879832) < 1e-6)
        }
        #expect(face.surfaceType == .bsplineSurface)
    }
}

import Testing
import simd
import Foundation

@testable import OCCTSwift

/// Issue #257, `threadedShaft(starts: N)` for N > 1 now builds the smooth, boolean-free direct rod
/// (generalising the single-start cam-slice loft to N teeth tiling the turn, lead = N·pitch) instead
/// of falling to the faceted cut path (#254). The cut path produced disconnected notches; the direct
/// build is a continuous interleaved multi-helix: a low-face-count, BRepCheck-valid solid with the
/// crest exactly at the nominal major radius.
@Suite("Issue #257, smooth multi-start direct thread build")
struct Issue257MultiStartTests {

    private func rod(
        _ form: ThreadForm, nominal: Double, pitch: Double, rodH: Double,
        len: Double, starts: Int
    ) -> Shape? {
        Shape.cylinder(radius: nominal / 2, height: rodH)?.threadedShaft(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            spec: ThreadSpec(form: form, nominalDiameter: nominal, pitch: pitch),
            length: len, starts: starts, runout: .none, build: .direct)
    }

    /// Full-length 2- and 3-start rods: valid solids, smooth (low face count, not the ~hundreds-of-
    /// faces faceted fallback), crest in-envelope at the nominal major radius.
    @Test("Full-length multi-start is a smooth, in-envelope, valid solid")
    func fullLengthMultistart() {
        for n in [2, 3] {
            guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 26, len: 26, starts: n) else {
                Issue.record("starts=\(n) build returned nil")
                continue
            }
            #expect(s.isValidSolid, "starts=\(n) not a valid solid")
            let faces = s.subShapes(ofType: .face).count
            #expect(
                faces < 40,
                "starts=\(n) face count \(faces) suggests the faceted cut fallback, not the smooth build"
            )
            if let crest = meshMaxRadialExtent(s, deflection: 0.03) {
                #expect(crest <= 5.0 * 1.005, "starts=\(n) crest \(crest) bulges past nominal 5.0")
            } else {
                Issue.record("starts=\(n) mesh failed, cannot measure crest radius")
            }
        }
    }

    /// Partial-length multi-start (thread + plain shank) exercises the per-start shoulder closure.
    @Test("Partial-length multi-start closes via per-start shoulders")
    func partialLengthMultistart() {
        guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 30, len: 20, starts: 2) else {
            Issue.record("partial starts=2 build returned nil")
            return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count < 40)
        if let crest = meshMaxRadialExtent(s, deflection: 0.03) {
            #expect(crest <= 5.0 * 1.005)
        } else {
            Issue.record("partial starts=2 mesh failed, cannot measure crest radius")
        }
    }

    /// A trapezoidal 2-start lead screw (the classic multi-start use) also builds smooth.
    @Test("Trapezoidal 2-start lead screw builds smooth and valid")
    func trapezoidalLeadScrew() {
        guard let s = rod(.trapezoidal, nominal: 12, pitch: 3, rodH: 40, len: 40, starts: 2) else {
            Issue.record("Tr 2-start build returned nil")
            return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count < 40)
    }

    /// Mean Z of each crest cluster crossing the half-plane at polar angle `alpha`.
    ///
    /// Counts mesh vertices with r > 4.9 and z in (10, 10 + lead), splitting clusters where
    /// consecutive crest Zs are more than half a pitch apart.
    private func crestClusters(
        _ m: Mesh, alpha: Double, pitch: Double, lead: Double
    ) -> [Double] {
        var zs: [Double] = []
        for v in m.vertices {
            let ang = atan2(Double(v.y), Double(v.x))
            let r = Double(((v.x * v.x) + (v.y * v.y)).squareRoot())
            let z = Double(v.z)
            if abs(remainder(ang - alpha, 2 * .pi)) < 0.04, r > 4.9, z > 10, z < 10 + lead {
                zs.append(z)
            }
        }
        zs.sort()
        var means: [Double] = []
        var sum = 0.0
        var count = 0
        for (i, z) in zs.enumerated() {
            if i > 0, z - zs[i - 1] > pitch * 0.5 {
                means.append(sum / Double(count))
                sum = 0
                count = 0
            }
            sum += z
            count += 1
        }
        if count > 0 { means.append(sum / Double(count)) }
        return means
    }

    /// The thread genuinely has N starts.
    ///
    /// Counting crest clusters on one half-plane is not enough on its own: a single-start thread
    /// of the same pitch also crosses a half-plane N times per N pitches, so a build that ignored
    /// `starts` altogether passed the count (#1990: forcing `nStart = 1` in `threadedRodSolid`
    /// left the count-only version of this test green). What does tell the two apart is the lead.
    /// A crest reaches the half-plane a quarter turn on (polar angle pi/2) lead/4 further along
    /// the axis, so the offset between the two half-planes' crests, modulo the pitch, is
    /// lead/4 mod pitch: 0.375 mm for 1 start, 0.75 for 2, 1.125 for 3 at P = 1.5, each 0.375 from
    /// the next. Probed against the kernel in `Scripts/repro/766-thread-257-1578/`.
    @Test("Start count equals the requested number of starts")
    func startCount() {
        for n in [1, 2, 3] {
            let pitch = 1.5
            let lead = Double(n) * pitch
            guard let s = rod(.iso68, nominal: 10, pitch: pitch, rodH: 26, len: 26, starts: n),
                let m = s.mesh(linearDeflection: 0.02)
            else {
                Issue.record("starts=\(n)")
                continue
            }
            let atZero = crestClusters(m, alpha: 0, pitch: pitch, lead: lead)
            let atQuarter = crestClusters(m, alpha: .pi / 2, pitch: pitch, lead: lead)
            #expect(atZero.count == n, "starts=\(n): found \(atZero.count) crest clusters per lead")
            guard let z0 = atZero.first, let z90 = atQuarter.first else {
                Issue.record("starts=\(n): no crest on one of the two half-planes")
                continue
            }
            let offset = remainder(z90 - z0, pitch)
            let expected = remainder(lead / 4, pitch)
            #expect(
                abs(remainder(offset - expected, pitch)) < 0.1,
                "starts=\(n): quarter-turn crest offset \(offset) mod pitch, expected lead/4 = \(expected)"
            )
        }
    }

    /// Single-start behaviour is unchanged (regression guard for the generalisation).
    @Test("Single-start build is unchanged")
    func singleStartRegression() {
        guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 26, len: 26, starts: 1) else {
            Issue.record("single-start nil")
            return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count == 7)
        if let crest = meshMaxRadialExtent(s, deflection: 0.03) {
            #expect(crest <= 5.0 * 1.005)
        } else {
            Issue.record("single-start mesh failed, cannot measure crest radius")
        }
    }
}

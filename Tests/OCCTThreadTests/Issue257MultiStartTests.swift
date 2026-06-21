import Testing
import simd
@testable import OCCTSwift

/// Issue #257 — `threadedShaft(starts: N)` for N > 1 now builds the smooth, boolean-free direct rod
/// (generalising the single-start cam-slice loft to N teeth tiling the turn, lead = N·pitch) instead
/// of falling to the faceted cut path (#254). The cut path produced disconnected notches; the direct
/// build is a continuous interleaved multi-helix: a low-face-count, BRepCheck-valid solid with the
/// crest exactly at the nominal major radius.
@Suite("Issue #257 — smooth multi-start direct thread build")
struct Issue257MultiStartTests {

    private func rod(_ form: ThreadForm, nominal: Double, pitch: Double, rodH: Double,
                     len: Double, starts: Int) -> Shape? {
        Shape.cylinder(radius: nominal / 2, height: rodH)?.threadedShaft(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            spec: ThreadSpec(form: form, nominalDiameter: nominal, pitch: pitch),
            length: len, starts: starts, runout: .none, build: .direct)
    }

    private func meshCrestRadius(_ s: Shape) -> Double {
        guard let m = s.mesh(linearDeflection: 0.03) else { return -1 }
        return m.vertices.reduce(0.0) { max($0, Double((($1.x * $1.x) + ($1.y * $1.y)).squareRoot())) }
    }

    /// Full-length 2- and 3-start rods: valid solids, smooth (low face count, not the ~hundreds-of-
    /// faces faceted fallback), crest in-envelope at the nominal major radius.
    @Test("Full-length multi-start is a smooth, in-envelope, valid solid")
    func fullLengthMultistart() {
        for n in [2, 3] {
            guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 26, len: 26, starts: n) else {
                Issue.record("starts=\(n) build returned nil"); continue
            }
            #expect(s.isValidSolid, "starts=\(n) not a valid solid")
            let faces = s.subShapes(ofType: .face).count
            #expect(faces < 40, "starts=\(n) face count \(faces) suggests the faceted cut fallback, not the smooth build")
            #expect(meshCrestRadius(s) <= 5.0 * 1.005, "starts=\(n) crest \(meshCrestRadius(s)) bulges past nominal 5.0")
        }
    }

    /// Partial-length multi-start (thread + plain shank) exercises the per-start shoulder closure.
    @Test("Partial-length multi-start closes via per-start shoulders")
    func partialLengthMultistart() {
        guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 30, len: 20, starts: 2) else {
            Issue.record("partial starts=2 build returned nil"); return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count < 40)
        #expect(meshCrestRadius(s) <= 5.0 * 1.005)
    }

    /// A trapezoidal 2-start lead screw (the classic multi-start use) also builds smooth.
    @Test("Trapezoidal 2-start lead screw builds smooth and valid")
    func trapezoidalLeadScrew() {
        guard let s = rod(.trapezoidal, nominal: 12, pitch: 3, rodH: 40, len: 40, starts: 2) else {
            Issue.record("Tr 2-start build returned nil"); return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count < 40)
    }

    /// The thread genuinely has N starts: exactly N crest clusters cross a fixed half-plane per lead.
    @Test("Start count equals the requested number of starts")
    func startCount() {
        for n in [1, 2, 3] {
            let pitch = 1.5, lead = Double(n) * pitch
            guard let s = rod(.iso68, nominal: 10, pitch: pitch, rodH: 26, len: 26, starts: n),
                  let m = s.mesh(linearDeflection: 0.02) else { Issue.record("starts=\(n)"); continue }
            var zs: [Double] = []
            for v in m.vertices {
                let ang = atan2(Double(v.y), Double(v.x))
                let r = Double(((v.x * v.x) + (v.y * v.y)).squareRoot())
                let z = Double(v.z)
                if abs(ang) < 0.04, r > 4.9, z > 10, z < 10 + lead { zs.append(z) }
            }
            zs.sort()
            var clusters = zs.isEmpty ? 0 : 1
            if zs.count > 1 {
                for i in 1..<zs.count where zs[i] - zs[i - 1] > pitch * 0.5 { clusters += 1 }
            }
            #expect(clusters == n, "starts=\(n): found \(clusters) crest clusters per lead")
        }
    }

    /// Single-start behaviour is unchanged (regression guard for the generalisation).
    @Test("Single-start build is unchanged")
    func singleStartRegression() {
        guard let s = rod(.iso68, nominal: 10, pitch: 1.5, rodH: 26, len: 26, starts: 1) else {
            Issue.record("single-start nil"); return
        }
        #expect(s.isValidSolid)
        #expect(s.subShapes(ofType: .face).count == 7)
        #expect(meshCrestRadius(s) <= 5.0 * 1.005)
    }
}
